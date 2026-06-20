unit Conn4D.Core;

{
  Conn4D — Core / Abstractions / Fluent

  Duas abstrações que andam juntas (programar para interface, não para classe):

  - IConnConfig: a CONFIGURAÇÃO como interface (DIP). Builder fluente — getters de
    leitura (nomes dos campos) e setters de mesmo nome (overload 1-arg) que
    devolvem IConnConfig. Implementada por TConnConfig (Conn4D.Core.Config).

  - IConn4D: a fachada agnóstica de engine. Recebe a config de duas formas:
      * Configure(const ACfg: IConnConfig): IConn4D  — passa a config pronta.
      * Configure: IConnConfig                       — abre um builder VINCULADO
        a esta conexão; encadeie .Provider.Port... e finalize com EndConfig, que
        devolve o IConn4D para continuar (Open/BeginTransaction/...).

  EndConfig liga a config de volta à fachada; por isso IConnConfig e IConn4D
  vivem na MESMA unit (referência mútua via forward declaration). Numa config
  avulsa (TConnConfig.New, sem vínculo) EndConfig devolve nil.
}

interface

uses
  System.Generics.Collections,
  Conn4D.Shared.Types,
  Conn4D.Shared.Config,
  Conn4D.Core.Base,
  Conn4D.Core.Transaction;

type
  IConnConfig = interface;
  IConn4D = interface;

  /// <summary>Configuração como interface (builder fluente + getters).</summary>
  IConnConfig = interface
    ['{D1A4F0E1-0000-0000-0000-00000000000C}']
    { Getters (leitura) }
    function Provider: string; overload;
    function Host: string; overload;
    function Port: Integer; overload;
    function Database: string; overload;
    function UserName: string; overload;
    function Password: string; overload;
    function ConnectTimeout: Integer; overload;
    function VendorLibX86: string; overload;
    function VendorLibX64: string; overload;
    function Pool: TConnPoolConfig;
    function GC: TConnGCConfig;
    function Extra: TArray<TPair<string, string>>; overload;
    function GetExtra(const AKey: string; const ADefault: string = ''): string;

    { Setters fluentes (escrita) — devolvem IConnConfig }
    function Provider(const AValue: string): IConnConfig; overload;
    function Host(const AValue: string): IConnConfig; overload;
    function Port(const AValue: Integer): IConnConfig; overload;
    function Database(const AValue: string): IConnConfig; overload;
    function UserName(const AValue: string): IConnConfig; overload;
    function Password(const AValue: string): IConnConfig; overload;
    function ConnectTimeout(const AValue: Integer): IConnConfig; overload;
    /// <summary>Caminho (pasta ou .dll) da client lib nativa para Win32/x86.</summary>
    function VendorLibX86(const AValue: string): IConnConfig; overload;
    /// <summary>Caminho (pasta ou .dll) da client lib nativa para Win64/x64.</summary>
    function VendorLibX64(const AValue: string): IConnConfig; overload;
    function MinSize(const AValue: Integer): IConnConfig;
    function MaxSize(const AValue: Integer): IConnConfig;
    function AcquireTimeout(const AValue: Cardinal): IConnConfig;
    function MaxLeaseTime(const AValue: Cardinal): IConnConfig;
    function IdleTimeout(const AValue: Cardinal): IConnConfig;
    function GCEnabled(const AValue: Boolean): IConnConfig;
    function GCInterval(const AValue: Cardinal): IConnConfig;
    function Extra(const AKey, AValue: string): IConnConfig; overload;

    /// <summary>Cópia independente desta config.</summary>
    function Clone: IConnConfig;
    /// <summary>Vincula esta config a uma fachada (uso interno de Configure).</summary>
    function BindTo(const AOwner: IConn4D): IConnConfig;
    /// <summary>Encerra o builder e devolve a fachada vinculada (ou nil).</summary>
    function EndConfig: IConn4D;
  end;

  /// <summary>Fachada agnóstica de engine.</summary>
  IConn4D = interface(IConn4DBase)
    ['{D1A4F0E1-0000-0000-0000-00000000000B}']
    /// <summary>Aplica uma config pronta e devolve a si mesma.</summary>
    function Configure(const ACfg: IConnConfig): IConn4D; overload;
    /// <summary>
    /// Abre um builder de config VINCULADO a esta conexão. Encadeie os setters
    /// e finalize com EndConfig para voltar ao IConn4D.
    /// </summary>
    function Configure: IConnConfig; overload;
    /// <summary>Abre explicitamente (sai do lazy) e devolve a si mesma.</summary>
    function Open: IConn4D;
    /// <summary>Inicia transação sobre a conexão desta thread.</summary>
    function BeginTransaction: IConnTransaction;
    /// <summary>Instantâneo de monitoramento das conexões vivas do pool.</summary>
    function LiveConnections: TArray<TConnLeaseInfo>;
  end;

implementation

end.
