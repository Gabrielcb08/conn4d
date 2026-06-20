unit Conn4D.Adapter.Engines;

{
  Conn4D — Registry de fachadas de engine (Interface Adapters)

  Ponto de extensão do OCP: cada engine adapter se AUTO-REGISTRA aqui (na sua
  seção initialization), associando seu EngineID a uma fábrica de fachada
  IConn4DNative. O componente apenas RESOLVE pela chave — não conhece engine
  alguma, não faz `case` nem `uses` de adapter. Adicionar uma engine é adicionar
  uma unit que se registra; o componente fica intocado.

  A chave é o EngineID que a própria engine já declara ('firedac'/'zeos'/...),
  fonte única de verdade — nunca uma string digitada pelo consumidor (a API
  pública do componente é tipada via TConn4DEngine).

  Agnóstico: NÃO faz `uses` de engine concreto. Vive no anel de Interface
  Adapters; o Core não depende desta unit.
}

interface

uses
  Conn4D.Adapter.ConnRef;   // IConn4DNative

type
  /// <summary>Fábrica de uma fachada de conexão (lazy) de uma engine.</summary>
  TConn4DFacadeFactory = reference to function: IConn4DNative;

  /// <summary>Registro estático (processo) de fachadas por EngineID.</summary>
  TConn4DEngines = record
  public
    /// <summary>Registra (ou substitui) a fábrica de uma engine. Chave case-insensitive.</summary>
    class procedure Register(const AEngineID: string; const AFactory: TConn4DFacadeFactory); static;
    /// <summary>Cria a fachada da engine registrada; lança EConn4DConfigException se ausente.</summary>
    class function Resolve(const AEngineID: string): IConn4DNative; static;
    /// <summary>Indica se há fábrica registrada para o EngineID.</summary>
    class function IsRegistered(const AEngineID: string): Boolean; static;
    /// <summary>EngineIDs registrados (diagnóstico/mensagens).</summary>
    class function Names: TArray<string>; static;
  end;

implementation

uses
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections,
  Conn4D.Shared.Exceptions;

var
  GLock: TCriticalSection;
  GMap:  TDictionary<string, TConn4DFacadeFactory>;

function NormKey(const AEngineID: string): string; inline;
begin
  Result := AnsiLowerCase(Trim(AEngineID));
end;

{ TConn4DEngines }

class procedure TConn4DEngines.Register(const AEngineID: string;
  const AFactory: TConn4DFacadeFactory);
begin
  if not Assigned(AFactory) then
    raise EConn4DConfigException.CreateFmt(
      'Fábrica nula ao registrar a engine "%s".', [AEngineID]);
  GLock.Enter;
  try
    GMap.AddOrSetValue(NormKey(AEngineID), AFactory);
  finally
    GLock.Leave;
  end;
end;

class function TConn4DEngines.Resolve(const AEngineID: string): IConn4DNative;
var
  Factory: TConn4DFacadeFactory;
begin
  GLock.Enter;
  try
    if not GMap.TryGetValue(NormKey(AEngineID), Factory) then
      raise EConn4DConfigException.CreateFmt(
        'Engine "%s" não registrada. Registradas: [%s]. ' +
        'Habilite o define da engine em Conn4D.inc e linke seu adapter.',
        [AEngineID, string.Join(', ', Names)]);
  finally
    GLock.Leave;
  end;
  // Fábrica fora do lock: cria a fachada (lazy) sem segurar a seção crítica.
  Result := Factory();
end;

class function TConn4DEngines.IsRegistered(const AEngineID: string): Boolean;
begin
  GLock.Enter;
  try
    Result := GMap.ContainsKey(NormKey(AEngineID));
  finally
    GLock.Leave;
  end;
end;

class function TConn4DEngines.Names: TArray<string>;
begin
  GLock.Enter;
  try
    Result := GMap.Keys.ToArray;
  finally
    GLock.Leave;
  end;
end;

initialization
  GLock := TCriticalSection.Create;
  GMap  := TDictionary<string, TConn4DFacadeFactory>.Create;

finalization
  GMap.Free;
  GLock.Free;

end.
