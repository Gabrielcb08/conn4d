unit Conn4D.Component;

{$I Conn4D.inc}

{
  Conn4D — Componente público (paleta ORData) + factory

  TConn4D é o ponto de entrada público da biblioteca:

  1) FACTORY PROGRAMÁTICO (class methods estáticos):
       Conn := TConn4D.Acquire;                       // engine FireDAC por default
       Conn := TConn4D.Acquire(enZeos);               // outra engine (se habilitada)
     Devolve a interface AGNÓSTICA IConn4DNative (porta IConn4D + acesso nativo);
     a engine fica escondida. O acesso à conexão nativa não precisa de cast nem
     nomear a engine — os operadores implícitos de TConnRef resolvem pelo destino:
       FDQuery.Connection := Conn.Connection;

  2) COMPONENTE DE PALETA (arrastado num form/datamodule):
     configure as propriedades publicadas no Object Inspector e use o acessor
     lazy Conn (constrói a fachada a partir das propriedades, usando a Engine
     selecionada). FireDAC é a engine interna padrão.

  Camada de componente: fica ACIMA dos adapters e pode conhecê-los. Zeos/UniDAC
  ficam atrás de diretivas IFDEF (ver Conn4D.inc) — sem eles, só FireDAC é
  oferecida e nada quebra a compilação.
}

interface

uses
  System.Classes,
  Conn4D.Shared.Types,
  Conn4D.Core.Transaction,
  Conn4D.Core,
  Conn4D.Adapter.ConnRef;

type
  /// <summary>Engines suportadas. enFireDAC é o default.</summary>
  TConn4DEngine = (enFireDAC, enZeos, enUniDAC);

  TConn4D = class(TComponent)
  private
    FEngine: TConn4DEngine;
    FConn:   IConn4DNative;   // fachada lazy (modo componente; já expõe Connection)
    // Conexão
    FProvider:       string;
    FHost:           string;
    FPort:           Integer;
    FDatabase:       string;
    FUserName:       string;
    FPassword:       string;
    FConnectTimeout: Integer;
    // Pool
    FPoolMinSize:    Integer;
    FPoolMaxSize:    Integer;
    FAcquireTimeout: Cardinal;
    FMaxLeaseTime:   Cardinal;
    FIdleTimeout:    Cardinal;
    // GC
    FGCEnabled:  Boolean;
    FGCInterval: Cardinal;

    function BuildConfig: IConnConfig;
    function GetConn: IConn4DNative;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>Factory: cria uma fachada FireDAC (engine padrão).</summary>
    class function Acquire: IConn4DNative; overload; static;
    /// <summary>Factory: cria uma fachada da engine informada.</summary>
    class function Acquire(const AEngine: TConn4DEngine): IConn4DNative; overload; static;

    /// <summary>
    /// Acessor lazy do modo componente: fachada construída a partir das
    /// propriedades publicadas e da Engine selecionada (cria na 1ª chamada).
    /// Devolve IConn4DNative (agnóstica) — já permite Conn.Connection sem cast.
    /// </summary>
    function Conn: IConn4DNative;
    /// <summary>
    /// Conexão nativa emprestada por esta thread. Devolve o handle universal
    /// TConnRef, cujos operadores implícitos convertem para o tipo da engine
    /// conforme o destino, permitindo (na engine selecionada):
    ///   FDQuery.Connection := Conn4D.Connection;
    /// </summary>
    function Connection: TConnRef;
    /// <summary>Inicia transação sobre a conexão desta thread.</summary>
    function BeginTransaction: IConnTransaction;
    /// <summary>Devolve ao pool a conexão emprestada por esta thread.</summary>
    procedure ReleaseConnection;
    /// <summary>Encerra o manager e todas as conexões deste componente.</summary>
    procedure Shutdown;
    /// <summary>Instantâneo de monitoramento (id, estado, idade...).</summary>
    function LiveConnections: TArray<TConnLeaseInfo>;
  published
    property Engine: TConn4DEngine read FEngine write FEngine default enFireDAC;

    property Provider:       string   read FProvider       write FProvider;
    property Host:           string   read FHost           write FHost;
    property Port:           Integer  read FPort           write FPort default 0;
    property Database:       string   read FDatabase       write FDatabase;
    property UserName:       string   read FUserName       write FUserName;
    property Password:       string   read FPassword       write FPassword;
    property ConnectTimeout: Integer  read FConnectTimeout write FConnectTimeout default 5000;

    property PoolMinSize:    Integer  read FPoolMinSize    write FPoolMinSize default 1;
    property PoolMaxSize:    Integer  read FPoolMaxSize    write FPoolMaxSize default 10;
    property AcquireTimeout: Cardinal read FAcquireTimeout write FAcquireTimeout default 5000;
    property MaxLeaseTime:   Cardinal read FMaxLeaseTime   write FMaxLeaseTime default 60000;
    property IdleTimeout:    Cardinal read FIdleTimeout    write FIdleTimeout default 120000;

    property GCEnabled:  Boolean  read FGCEnabled  write FGCEnabled default True;
    property GCInterval: Cardinal read FGCInterval write FGCInterval default 30000;
  end;

implementation

uses
  Conn4D.Core.Config,       // TConnConfig.New (builder concreto)
  Conn4D.Adapter.Engines;   // registry de fachadas (resolve por EngineID)

const
  // Mapa enum -> EngineID canônico (açúcar do Object Inspector). O compilador
  // exige completude do array; NÃO é fábrica — a criação é resolvida no registry.
  ENGINE_NAMES: array[TConn4DEngine] of string = ('firedac', 'zeos', 'unidac');

function CreateFacade(const AEngineID: string): IConn4DNative;
begin
  // O componente não conhece engine alguma: resolve pela abstração (OCP/DIP).
  Result := TConn4DEngines.Resolve(AEngineID);
end;

{ TConn4D }

constructor TConn4D.Create(AOwner: TComponent);
var
  D: IConnConfig;
begin
  inherited Create(AOwner);
  FEngine := enFireDAC;
  D := TConnConfig.New;
  FConnectTimeout := D.ConnectTimeout;
  FPoolMinSize    := D.Pool.MinSize;
  FPoolMaxSize    := D.Pool.MaxSize;
  FAcquireTimeout := D.Pool.AcquireTimeout;
  FMaxLeaseTime   := D.Pool.MaxLeaseTime;
  FIdleTimeout    := D.Pool.IdleTimeout;
  FGCEnabled      := D.GC.Enabled;
  FGCInterval     := D.GC.Interval;
end;

destructor TConn4D.Destroy;
begin
  if FConn <> nil then
  begin
    FConn.Shutdown;
    FConn := nil;
  end;
  inherited;
end;

class function TConn4D.Acquire: IConn4DNative;
begin
  Result := CreateFacade(ENGINE_NAMES[enFireDAC]);
end;

class function TConn4D.Acquire(const AEngine: TConn4DEngine): IConn4DNative;
begin
  Result := CreateFacade(ENGINE_NAMES[AEngine]);
end;

function TConn4D.BuildConfig: IConnConfig;
begin
  Result := TConnConfig.New
    .Provider(FProvider)
    .Host(FHost)
    .Port(FPort)
    .Database(FDatabase)
    .UserName(FUserName)
    .Password(FPassword)
    .ConnectTimeout(FConnectTimeout)
    .MinSize(FPoolMinSize)
    .MaxSize(FPoolMaxSize)
    .AcquireTimeout(FAcquireTimeout)
    .MaxLeaseTime(FMaxLeaseTime)
    .IdleTimeout(FIdleTimeout)
    .GCEnabled(FGCEnabled)
    .GCInterval(FGCInterval);
end;

function TConn4D.GetConn: IConn4DNative;
begin
  if FConn = nil then
  begin
    // Mantém a referência rica (IConn4DNative): Configure devolve a porta IConn4D,
    // mas só muta a config desta fachada — descartamos o retorno e FConn segue
    // apontando para a mesma instância, agora com a config aplicada.
    FConn := CreateFacade(ENGINE_NAMES[FEngine]);
    FConn.Configure(BuildConfig);
  end;
  Result := FConn;
end;

function TConn4D.Conn: IConn4DNative;
begin
  Result := GetConn;
end;

function TConn4D.Connection: TConnRef;
begin
  Result := GetConn.Connection;
end;

function TConn4D.BeginTransaction: IConnTransaction;
begin
  Result := GetConn.BeginTransaction;
end;

procedure TConn4D.ReleaseConnection;
begin
  if FConn <> nil then
    FConn.Release;
end;

procedure TConn4D.Shutdown;
begin
  if FConn <> nil then
    FConn.Shutdown;
end;

function TConn4D.LiveConnections: TArray<TConnLeaseInfo>;
begin
  if FConn <> nil then
    Result := FConn.LiveConnections
  else
    Result := nil;
end;

end.
