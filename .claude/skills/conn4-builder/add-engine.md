# Conn4D — Como adicionar um novo engine

Leia este arquivo antes de adicionar Zeos, UniDAC ou qualquer driver novo. A meta: o engine novo entra sem tocar **nenhuma** unit de Core ou Shared. Se você sentir necessidade de mudar o Core para encaixar o engine, a abstração está errada — corrija o Core de forma genérica, nunca especialize por driver.

## Princípio

Cada engine vive isolado em duas units dentro de `src/Adapters/<Name>/`:

1. `Conn4D.Engine.<Name>.pas` — implementa `IConnEngine` (a Strategy do driver).
2. `Conn4D.Adapter.<Name>.pas` — ergonomia tipada: o record com `operator Implicit`, a interface fluente `I<Name>Conn4D`, e a factory `T<Name>Conn4D.Acquire`.

O Core continua enxergando o engine só por `IConnEngine`, que devolve `TObject`.

## Passo 1 — implementar `IConnEngine`

```pascal
unit Conn4D.Engine.Zeos;
interface
uses ZConnection, ZDbcIntfs, Conn4D.Core.Engine, Conn4D.Shared.Config,
     Conn4D.Shared.Types;

type
  TZeosEngine = class(TInterfacedObject, IConnEngine)
  public
    function  EngineID: string;
    function  CreateNative(const ACfg: TConnConfig): TObject;
    procedure OpenNative(const ANative: TObject);
    procedure CloseNative(const ANative: TObject);
    procedure DestroyNative(const ANative: TObject);
    function  Ping(const ANative: TObject): Boolean;
    procedure BeginTx(const ANative: TObject; const AIsolation: TConnIsolation);
    procedure CommitTx(const ANative: TObject);
    procedure RollbackTx(const ANative: TObject);
    function  InTx(const ANative: TObject): Boolean;
  end;

implementation

function TZeosEngine.EngineID: string;
begin
  Result := 'zeos';
end;

function TZeosEngine.CreateNative(const ACfg: TConnConfig): TObject;
var Conn: TZConnection;
begin
  Conn := TZConnection.Create(nil);
  Conn.HostName := ACfg.Host;
  Conn.Port     := ACfg.Port;
  Conn.Database := ACfg.Database;
  Conn.User     := ACfg.UserName;
  Conn.Password := ACfg.Password;
  Conn.Protocol := ZeosProtocolFor(ACfg.Provider);  // mapeia 'Firebird'->'firebird'
  Result := Conn;
end;

function TZeosEngine.Ping(const ANative: TObject): Boolean;
begin
  try
    Result := TZConnection(ANative).Connected
              and TZConnection(ANative).Ping;
  except
    Result := False;
  end;
end;

// ... demais métodos seguem o mesmo padrão: cast interno controlado
//     de TObject para TZConnection, encapsulando exceção do driver em
//     EConn4DEngineException quando fizer sentido.
end.
```

Regras:
- O cast `TObject` → tipo nativo acontece **só aqui**, dentro do engine. É controlado e isolado.
- Falhas do driver viram `EConn4DEngineException` (da hierarquia em Shared) quando precisarem subir.
- `EngineID` é único e estável — usado pelo registry e nos logs.

## Passo 2a — um operador implícito no seam (Conn4D.Adapter.ConnRef)

O record universal `TConnRef` e a interface agnóstica `IConn4DNative` já existem no
seam. Só adicione, sob o IFDEF da engine, **um** operador implícito para o tipo de
conexão do driver:

```pascal
// Conn4D.Adapter.ConnRef (interface uses + corpo), sob {$IFDEF CONN4D_ZEOS}
uses ..., ZConnection;

class operator TConnRef.Implicit(const ARef: TConnRef): TZConnection;   // no record
class operator TConnRef.Implicit(const ARef: TConnRef): TZConnection;   // impl
begin
  Result := ARef.FNative as TZConnection;   // cast verificado → EInvalidCast no mismatch
end;
```

## Passo 2b — interface-marcador + factory (Conn4D.Adapter.Zeos)

```pascal
unit Conn4D.Adapter.Zeos;
interface
uses Conn4D.Core, Conn4D.Adapter.ConnRef, Conn4D.Core.Transaction;

type
  // Marcador: estende a AGNÓSTICA IConn4DNative (que já traz Connection: TConnRef)
  // com um GUID próprio. NÃO redeclara Connection nem cria record por engine.
  IZConn4D = interface(IConn4DNative)
    ['{NOVO-GUID-AQUI}']
  end;

  TZConn4D = record
    class function Acquire: IZConn4D; static;
  end;

implementation
uses Conn4D.Adapter.Engines;
// O impl implementa IConn4DNative.Connection com Result := TConnRef.Wrap(EnsureNativeForThread);
// A factory injeta TZeosEngine no manager genérico do Core. O Core não sabe que é Zeos.

initialization
  // OCP: auto-registro. O componente resolve 'zeos' sem conhecer este adapter.
  TConn4DEngines.Register('zeos',
    function: IConn4DNative begin Result := TZConn4D.Acquire end);
end.
```

Atenção:
- Gere um **GUID novo** para `IZConn4D`. Nunca reaproveite o de `IFDConn4D`.
- O `operator Implicit` (no seam) retorna `TZConnection` — por isso o seam `uses ZConnection` sob IFDEF. É a única edição em código compartilhado; Core/Shared seguem intactos.
- O consumidor segura `IZConn4D` (ou a agnóstica `IConn4DNative`) e usa `.Connection` sem cast, igual ao FireDAC.
- **Auto-registro fecha o OCP:** o componente `TConn4D` NÃO é editado para a engine nova — ele resolve por `Conn4D.Adapter.Engines`. Garanta que o adapter seja linkado (umbrella `Conn4D` sob IFDEF, e no `contains` do pacote runtime) para a `initialization` rodar. Isto é o registro de **fachadas** (`IConn4DNative`) no seam `TConn4DEngines`.

## Passo 3 — provar com testes

O mesmo conjunto de testes de Core deve passar com `TZeosEngine` mockado, validando LSP. Adicione um teste de integração real (`Conn4D.Test.EngineSwap`) que abre, usa e fecha uma conexão Zeos real, espelhando o teste do FireDAC.

## Checklist final

- [ ] `Conn4D.Engine.<Name>.pas` implementa todos os métodos de `IConnEngine`.
- [ ] Cast para o tipo nativo só acontece dentro do engine.
- [ ] `Conn4D.Adapter.ConnRef` ganhou **um** `operator Implicit` (sob IFDEF) p/ o tipo nativo.
- [ ] `Conn4D.Adapter.<Name>.pas` tem `IXConn4D = interface(IConn4DNative)` com GUID novo.
- [ ] `initialization` chama `TConn4DEngines.Register('<engineid>', ...)` (auto-registro; OCP).
- [ ] Adapter linkado para a `initialization` rodar (umbrella `Conn4D` sob IFDEF + `contains` do pacote).
- [ ] Componente `TConn4D` **não** foi tocado para a engine nova.
- [ ] Nenhuma unit de Core ou Shared foi alterada (`check-architecture.ps1` passa).
- [ ] `EngineID` é único.
- [ ] Suite de Core passa com o engine mockado; teste de integração real adicionado.
