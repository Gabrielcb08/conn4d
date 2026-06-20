unit Conn4D.Core.ThreadContext;

{
  Conn4D — Core / Services / ThreadContext

  TConnThreadContextStore: isola, por ThreadID, as conexões emprestadas àquela
  thread (ver references/threading-rules.md). Serve para atribuição de
  vazamentos (qual TID segurou um zombie) e para a thread reencontrar sua
  conexão corrente.

  É o lock MAIS interno da ordem fixa de aquisição. As leituras são curtas, por
  isso a sincronização é uma TCriticalSection encapsulada — o estado é protegido
  pelo próprio store, jamais mutado de fora.
}

interface

uses
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections;

type
  TConnThreadContextStore = class
  private
    FLock: TCriticalSection;
    FMap:  TObjectDictionary<TThreadID, TList<TObject>>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Associa uma conexão nativa à thread informada.</summary>
    procedure Bind(const AThreadId: TThreadID; const ANative: TObject);
    /// <summary>Desassocia uma conexão específica da thread.</summary>
    procedure Unbind(const AThreadId: TThreadID; const ANative: TObject);
    /// <summary>Última conexão emprestada à thread, se houver.</summary>
    function TryGetCurrent(const AThreadId: TThreadID; out ANative: TObject): Boolean;
    /// <summary>Quantidade de conexões atualmente atribuídas à thread.</summary>
    function CountFor(const AThreadId: TThreadID): Integer;
    /// <summary>Remove qualquer associação à conexão nativa, em qualquer thread.</summary>
    procedure RemoveNative(const ANative: TObject);
    procedure Clear;
  end;

implementation

{ TConnThreadContextStore }

constructor TConnThreadContextStore.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FMap  := TObjectDictionary<TThreadID, TList<TObject>>.Create([doOwnsValues]);
end;

destructor TConnThreadContextStore.Destroy;
begin
  FMap.Free;
  FLock.Free;
  inherited;
end;

procedure TConnThreadContextStore.Bind(const AThreadId: TThreadID; const ANative: TObject);
var
  List: TList<TObject>;
begin
  FLock.Enter;
  try
    if not FMap.TryGetValue(AThreadId, List) then
    begin
      List := TList<TObject>.Create;
      FMap.Add(AThreadId, List);
    end;
    if List.IndexOf(ANative) < 0 then
      List.Add(ANative);
  finally
    FLock.Leave;
  end;
end;

procedure TConnThreadContextStore.Unbind(const AThreadId: TThreadID; const ANative: TObject);
var
  List: TList<TObject>;
begin
  FLock.Enter;
  try
    if FMap.TryGetValue(AThreadId, List) then
    begin
      List.Remove(ANative);
      if List.Count = 0 then
        FMap.Remove(AThreadId);  // doOwnsValues libera a lista
    end;
  finally
    FLock.Leave;
  end;
end;

function TConnThreadContextStore.TryGetCurrent(const AThreadId: TThreadID; out ANative: TObject): Boolean;
var
  List: TList<TObject>;
begin
  FLock.Enter;
  try
    Result := FMap.TryGetValue(AThreadId, List) and (List.Count > 0);
    if Result then
      ANative := List.Last
    else
      ANative := nil;
  finally
    FLock.Leave;
  end;
end;

function TConnThreadContextStore.CountFor(const AThreadId: TThreadID): Integer;
var
  List: TList<TObject>;
begin
  FLock.Enter;
  try
    if FMap.TryGetValue(AThreadId, List) then
      Result := List.Count
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TConnThreadContextStore.RemoveNative(const ANative: TObject);
var
  Key:    TThreadID;
  List:   TList<TObject>;
  Stale:  TList<TThreadID>;
begin
  Stale := TList<TThreadID>.Create;
  try
    FLock.Enter;
    try
      for Key in FMap.Keys do
      begin
        List := FMap[Key];
        List.Remove(ANative);
        if List.Count = 0 then
          Stale.Add(Key);
      end;
      for Key in Stale do
        FMap.Remove(Key);
    finally
      FLock.Leave;
    end;
  finally
    Stale.Free;
  end;
end;

procedure TConnThreadContextStore.Clear;
begin
  FLock.Enter;
  try
    FMap.Clear;
  finally
    FLock.Leave;
  end;
end;

end.
