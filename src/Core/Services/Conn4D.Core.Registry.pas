unit Conn4D.Core.Registry;

{
  Conn4D — Core / Services / Registry

  TConn4DRegistry: singleton global que centraliza o controle de todos os
  managers de conexão vivos (ver spec §4.1, §11, critério "shutdown global").
  Guarda apenas IConn4DBase — a parte agnóstica de engine — então jamais
  precisa saber qual driver está por baixo.

  Permite encerrar todos os managers numa única chamada (ShutdownAll) e é
  thread-safe. O singleton é criado sob demanda e liberado na finalização da
  unit.
}

interface

uses
  System.SyncObjs,
  System.Generics.Collections,
  Conn4D.Core.Base;

type
  TConn4DRegistry = class
  private
    class var FInstance: TConn4DRegistry;
    class var FInstanceLock: TCriticalSection;
    FLock:    TCriticalSection;
    FManagers: TList<IConn4DBase>;
    constructor CreatePrivate;
  public
    destructor Destroy; override;

    /// <summary>Instância global (criada sob demanda, thread-safe).</summary>
    class function Instance: TConn4DRegistry; static;

    procedure Register(const AConn: IConn4DBase);
    procedure Unregister(const AConn: IConn4DBase);
    function Count: Integer;
    /// <summary>Cópia da lista de managers, para iteração fora de lock.</summary>
    function Snapshot: TArray<IConn4DBase>;
    /// <summary>Encerra (Shutdown) todos os managers e esvazia o registro.</summary>
    procedure ShutdownAll;
  end;

implementation

{ TConn4DRegistry }

constructor TConn4DRegistry.CreatePrivate;
begin
  inherited Create;
  FLock     := TCriticalSection.Create;
  FManagers := TList<IConn4DBase>.Create;
end;

destructor TConn4DRegistry.Destroy;
begin
  FManagers.Free;
  FLock.Free;
  inherited;
end;

class function TConn4DRegistry.Instance: TConn4DRegistry;
begin
  if FInstance = nil then
  begin
    FInstanceLock.Enter;
    try
      if FInstance = nil then
        FInstance := TConn4DRegistry.CreatePrivate;
    finally
      FInstanceLock.Leave;
    end;
  end;
  Result := FInstance;
end;

procedure TConn4DRegistry.Register(const AConn: IConn4DBase);
begin
  if AConn = nil then
    Exit;
  FLock.Enter;
  try
    if not FManagers.Contains(AConn) then
      FManagers.Add(AConn);
  finally
    FLock.Leave;
  end;
end;

procedure TConn4DRegistry.Unregister(const AConn: IConn4DBase);
begin
  FLock.Enter;
  try
    FManagers.Remove(AConn);
  finally
    FLock.Leave;
  end;
end;

function TConn4DRegistry.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FManagers.Count;
  finally
    FLock.Leave;
  end;
end;

function TConn4DRegistry.Snapshot: TArray<IConn4DBase>;
begin
  FLock.Enter;
  try
    Result := FManagers.ToArray;
  finally
    FLock.Leave;
  end;
end;

procedure TConn4DRegistry.ShutdownAll;
var
  Snap: TArray<IConn4DBase>;
  Conn: IConn4DBase;
begin
  // Captura a lista sob lock e invoca Shutdown FORA do lock: Shutdown pode
  // chamar de volta Unregister, o que reentraria no FLock.
  FLock.Enter;
  try
    Snap := FManagers.ToArray;
    FManagers.Clear;
  finally
    FLock.Leave;
  end;

  for Conn in Snap do
    Conn.Shutdown;
end;

initialization
  TConn4DRegistry.FInstanceLock := TCriticalSection.Create;

finalization
  if TConn4DRegistry.FInstance <> nil then
  begin
    TConn4DRegistry.FInstance.ShutdownAll;
    TConn4DRegistry.FInstance.Free;
    TConn4DRegistry.FInstance := nil;
  end;
  TConn4DRegistry.FInstanceLock.Free;

end.
