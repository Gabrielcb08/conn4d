# Conn4D — Especificação Técnica

> Biblioteca Delphi para gerenciamento de conexões de banco de dados com pool, garbage collection de conexões, segurança em múltiplas threads e abstração de engine (FireDAC, Zeos, UniDAC) sob Clean Architecture e SOLID.

Versão da spec: 1.0
Stack alvo: Delphi (DUnitX para testes)
Status das decisões de API: **congeladas** (ver seção 12 para pontos abertos)

---

## 1. Objetivo e escopo

Conn4D é uma biblioteca de **infraestrutura**, não de domínio de negócio. Não há regras de negócio, portanto **não se aplica DDD** — aplica-se Clean Architecture pura (Ports & Adapters). O propósito é:

- Criar e configurar conexões de banco de forma fluente.
- Manter um pool por instância de gerenciador, reaproveitando conexões.
- Encerrar automaticamente conexões ociosas ou vazadas (garbage collection de conexões).
- Operar com segurança sob múltiplas threads, sem condição de corrida nem deadlock.
- Abstrair o engine de acesso (driver), de modo que trocar FireDAC por Zeos/UniDAC não afete nenhuma camada além do adapter específico.

### Fora de escopo
- ORM, query builder, mapeamento objeto-relacional.
- Migrations.
- Lógica de negócio de qualquer natureza.

---

## 2. Princípios arquiteturais (não negociáveis)

1. **Inversão de dependência total.** Todo contrato vive em `Core`. Camadas externas dependem de internas; nunca o contrário. O `Core` jamais dá `uses` em FireDAC, Zeos ou UniDAC concreto.
2. **Engine substituível.** Trocar de engine é trocar um registro no `TConn4DRegistry`/container DI. Zero impacto fora do adapter.
3. **Thread safety por design.** Estado mutável centralizado em um único componente (`TConnPoolStore`), com ordem de aquisição de locks fixa para eliminar deadlock estruturalmente.
4. **Testabilidade de primeira classe.** Toda dependência é injetada via interface. Nenhuma classe instancia engine concreto internamente.
5. **SOLID aplicado, não decorativo.** Cada princípio tem justificativa concreta na seção 11.

---

## 3. Camadas e estrutura de pastas

```
Conn4D/
├── src/
│   ├── Shared/                          # transversal, sem dependência de camada
│   │   ├── Conn4D.Shared.Types.pas      # TConnResult<T>, TConnState, TConnPoolStats
│   │   ├── Conn4D.Shared.Config.pas     # TConnPoolConfig, TConnGCConfig (holders)
│   │   ├── Conn4D.Shared.Exceptions.pas # EConn4DException + hierarquia
│   │   └── Conn4D.Shared.Logger.pas     # IConnLogger, TNullLogger
│   │
│   ├── Core/                            # contratos puros + algoritmos agnósticos
│   │   ├── Abstractions/
│   │   │   ├── Conn4D.Core.Base.pas         # IConn4DBase
│   │   │   ├── Conn4D.Core.Engine.pas       # IConnEngine (Strategy)
│   │   │   ├── Conn4D.Core.Pool.pas         # IConnPool
│   │   │   ├── Conn4D.Core.Transaction.pas  # IConnTransaction
│   │   │   ├── Conn4D.Core.HealthCheck.pas  # IConnHealthCheck
│   │   │   ├── Conn4D.Core.GC.pas           # IConnGC
│   │   │   └── Conn4D.Core.Observer.pas     # IConnObserver, TConnEvent
│   │   └── Services/
│   │       ├── Conn4D.Core.PoolManager.pas       # TConnPoolManager : IConnPool
│   │       ├── Conn4D.Core.GarbageCollector.pas  # TConnGarbageCollector : IConnGC
│   │       ├── Conn4D.Core.TransactionMgr.pas    # TConnTransactionManager
│   │       ├── Conn4D.Core.HealthMonitor.pas     # TConnHealthMonitor
│   │       ├── Conn4D.Core.ObserverBroadcaster.pas
│   │       ├── Conn4D.Core.Semaphore.pas         # TConnSemaphore
│   │       ├── Conn4D.Core.ThreadSafeQueue.pas   # TConnThreadSafeQueue<T>
│   │       ├── Conn4D.Core.PoolStore.pas         # TConnPoolStore (estado protegido)
│   │       └── Conn4D.Core.Registry.pas          # TConn4DRegistry (singleton global)
│   │
│   └── Adapters/                        # única camada que conhece engines concretos
│       ├── Conn4D.Adapter.ConnRef.pas          # seam: TConnRef + IConn4DNative (operadores por engine)
│       ├── FireDAC/
│       │   ├── Conn4D.Adapter.FireDAC.pas       # IFDConn4D (marcador), TFDConn4D, factory
│       │   └── Conn4D.Engine.FireDAC.pas        # TFireDACEngine : IConnEngine
│       ├── Zeos/                                # fase futura
│       │   ├── Conn4D.Adapter.Zeos.pas
│       │   └── Conn4D.Engine.Zeos.pas
│       └── UniDAC/                              # fase futura
│           ├── Conn4D.Adapter.UniDAC.pas
│           └── Conn4D.Engine.UniDAC.pas
│
└── tests/
    ├── Conn4D.Test.PoolManager.pas
    ├── Conn4D.Test.GarbageCollector.pas
    ├── Conn4D.Test.ThreadSafety.pas
    ├── Conn4D.Test.Registry.pas
    ├── Conn4D.Test.EngineSwap.pas
    ├── Conn4D.Test.Config.pas
    └── Mocks/
        ├── Conn4D.Mock.Engine.pas
        ├── Conn4D.Mock.Clock.pas
        └── Conn4D.Mock.Logger.pas
```

Regra de dependência entre camadas:

```
Adapters  ──► Core  ──► Shared
   │                       ▲
   └───────────────────────┘
Core nunca conhece Adapters. Shared não conhece ninguém.
```

---

## 4. Contratos do Core (abstrações)

### 4.1 `IConn4DBase` — parte engine-agnóstica

Tudo que o registry e o GC precisam manipular sem saber o engine. É a interface guardada na lista global.

```pascal
IConn4DBase = interface
  ['{D1A4F0E1-0000-0000-0000-000000000001}']
  function  Id: TGUID;
  function  EngineID: string;            // 'firedac' | 'zeos' | 'unidac'
  function  Stats: TConnPoolStats;
  function  State: TConnState;
  procedure Release;                     // devolve conexão(es) ao pool / encerra
  procedure Shutdown;                    // encerra definitivamente este manager
end;
```

### 4.2 `IConnEngine` — Strategy do driver

O coração da substituição de engine. Cada driver implementa este contrato. Retorna sempre `TObject` para não vazar tipo concreto ao Core.

```pascal
IConnEngine = interface
  ['{D1A4F0E1-0000-0000-0000-000000000002}']
  function  EngineID: string;
  function  CreateNative(const ACfg: IConnConfig): TObject;
  procedure OpenNative(const ANative: TObject);
  procedure CloseNative(const ANative: TObject);
  procedure DestroyNative(const ANative: TObject);
  function  Ping(const ANative: TObject): Boolean;
  procedure BeginTx(const ANative: TObject; const AIsolation: TConnIsolation);
  procedure CommitTx(const ANative: TObject);
  procedure RollbackTx(const ANative: TObject);
  function  InTx(const ANative: TObject): Boolean;
end;
```

### 4.3 `IConnPool` — contrato do gerenciador de pool

```pascal
IConnPool = interface
  ['{D1A4F0E1-0000-0000-0000-000000000003}']
  function  Acquire(const ATimeoutMs: Cardinal): TObject;  // conexão nativa do pool
  procedure ReturnToPool(const ANative: TObject);
  function  ActiveCount: Integer;
  function  IdleCount: Integer;
  procedure EvictIdle(const AIdleTimeoutMs: Cardinal);
  procedure EvictZombies(const AMaxLeaseMs: Cardinal);
  procedure DrainAll;
end;
```

### 4.4 `IConnTransaction`

```pascal
IConnTransaction = interface
  ['{D1A4F0E1-0000-0000-0000-000000000004}']
  function  Id: TGUID;
  procedure Commit;
  procedure Rollback;
  function  IsActive: Boolean;
  function  Isolation: TConnIsolation;
end;
```

### 4.5 `IConnHealthCheck`, `IConnGC`, `IConnObserver`

```pascal
IConnHealthCheck = interface
  ['{D1A4F0E1-0000-0000-0000-000000000005}']
  function IsHealthy(const ANative: TObject): Boolean;
end;

IConnGC = interface
  ['{D1A4F0E1-0000-0000-0000-000000000006}']
  procedure Start;
  procedure Stop;
  procedure RunOnce;                     // útil para testes determinísticos
  procedure Register(const APool: IConnPool);
  procedure Unregister(const APool: IConnPool);
end;

TConnEventType = (ceCreated, ceAcquired, ceReleased, ceEvictedIdle,
                  ceEvictedZombie, ceHealthFail, ceShutdown);

TConnEvent = record
  EventType: TConnEventType;
  ConnId:    TGUID;
  EngineID:  string;
  Timestamp: TDateTime;
  Detail:    string;
end;

IConnObserver = interface
  ['{D1A4F0E1-0000-0000-0000-000000000007}']
  procedure OnConnEvent(const AEvent: TConnEvent);
end;
```

---

## 5. Contratos da fronteira (ergonomia engine-específica)

O **seam** `Conn4D.Adapter.ConnRef` (anel de Interface Adapters) é o único lugar,
ao lado dos engine adapters, autorizado a referenciar tipos de framework. Nele vive
o record universal `TConnRef` (operadores implícitos por engine) e a interface
**agnóstica** `IConn4DNative`, que estende a porta pura `IConn4D` e acrescenta o
acessor `Connection`. Core/Shared NÃO dependem deste seam. Ver
`references/add-engine.md` para criar um novo adapter.

### 5.1 Seam — record universal + interface agnóstica de conexão

```pascal
unit Conn4D.Adapter.ConnRef;
interface
uses Conn4D.Core, FireDAC.Comp.Client {IFDEF CONN4D_ZEOS: ZConnection; UNIDAC: Uni};

type
  // Record leve: carrega REFERÊNCIA à conexão nativa, não é dono dela. Um
  // operador implícito POR ENGINE habilitada — o compilador escolhe pelo destino.
  TConnRef = record
  private
    FNative: TObject;
  public
    class function Wrap(const A: TObject): TConnRef; static; inline;
    class operator Implicit(const ARef: TConnRef): TFDCustomConnection; inline;
    {$IFDEF CONN4D_ZEOS}   class operator Implicit(const ARef: TConnRef): TZConnection;   inline; {$ENDIF}
    {$IFDEF CONN4D_UNIDAC} class operator Implicit(const ARef: TConnRef): TUniConnection; inline; {$ENDIF}
  end;

  // Interface AGNÓSTICA: estende a porta pura IConn4D e acrescenta só o acessor
  // Connection. É o que o consumidor segura — sem cast, sem nomear engine.
  IConn4DNative = interface(IConn4D)
    ['{7E2C9A41-3B6D-4F8E-9C12-5A0B1D2E3F40}']
    function Connection: TConnRef;
  end;
```

O adapter de cada engine define só a interface-marcador (GUID próprio) e a factory:

```pascal
// Conn4D.Adapter.FireDAC
IFDConn4D = interface(IConn4DNative) ['{D1A4F0E1-FD00-0000-0000-000000000001}'] end;
TFDConn4D = record class function Acquire: IFDConn4D; static; end;
```

A fachada agnóstica `IConn4D` (em `Conn4D.Core`) expõe — programando
para INTERFACE, não para classe:
- `Configure(const ACfg: IConnConfig): IConn4D` — aplica uma config pronta;
- `Configure: IConnConfig` — abre um builder VINCULADO; encadeie e finalize com
  `EndConfig` (volta ao `IConn4D`);
- `Open`, `BeginTransaction`, `LiveConnections` (+ `IConn4DBase`).

NÃO há mais `Provider/Host/Port/...` na fachada — esses setters vivem, fluentes,
em `IConnConfig` (ver §9).

### 5.2 Uso pretendido (consumidor)

```pascal
var Conn4D: IConn4DNative;                       // agnóstica; NÃO nomeia engine

// (a) passando uma config pronta (guarde a referência rica e configure):
Conn4D := TConn4D.Acquire;                        // sem engine => FireDAC por default
Conn4D.Configure(
  TConnConfig.New.Provider('Firebird').Port(3050).ConnectTimeout(3000));

// (b) builder vinculado, terminando em EndConfig:
Conn4D.Configure.Provider('Firebird').Port(3050).EndConfig.Open;

FDQuery.Connection := Conn4D.Connection;          // SEM cast → TFDCustomConnection
Tx := Conn4D.BeginTransaction;
// ...
Tx.Commit;
```

Pontos de design fixados:
- A configuração é uma **interface** (`IConnConfig`); a fachada nunca depende do
  tipo concreto. Setters fluentes vivem só na config — sem duplicação por engine.
- `Connection` retorna `TConnRef`, cujo `operator Implicit` o compilador resolve
  para o tipo de conexão da engine pelo destino. Sem cast, sem `Connection<T>`,
  sem nomear a engine no call site (trocar de engine não altera estas linhas).
- O consumidor **nunca** faz `Free` na conexão nativa — pool e GC cuidam disso.

---

## 6. Ciclo de vida da conexão (decisão: LAZY)

Decisão congelada: **lazy open**. `Acquire` cria o manager e registra no global; a conexão física só é aberta no primeiro uso real (chamada a `.Connection` ou `.BeginTransaction`) ou em `.Open` explícito, depois da configuração fluente. Justificativa: a config (`Provider`, `Port`) vem encadeada após o `Acquire`, então não há host/porta no momento do `Acquire`.

Estados (`TConnState`):

```
Created ──init()──► Available ──acquire()──► InUse ──release()──► Available
                       │                        │
                  idle timeout              lease timeout
                       ▼                        ▼
                     Idle                    Zombie
                       │                        │
                  GC.collect()            GC.forceKill()
                       └────────► Destroyed ◄────┘

Available ──ping()──► HealthCheck ──ok──► Available
                          └──fail──► Destroyed
```

Regras de transição:
- `Idle`: conexão `Available` cujo `(Now - LastReleasedAt) > idleTimeout`.
- `Zombie`: conexão `InUse` cujo `(Now - AcquiredAt) > maxLeaseTime` (vazamento — thread morreu ou esqueceu de liberar).
- O GC, ao encontrar zombie, faz `Rollback` se houver transação aberta, loga com TID e timestamp, e destrói.

---

## 7. Modelo de concorrência e anti-deadlock

### 7.1 Componentes
- `TConnPoolStore`: único ponto de mutação. `AvailableList` + `InUseMap` protegidos por `TCriticalSection`.
- `TConnSemaphore`: limita threads simultâneas a `poolSize`. Wrapper sobre `THandle` (Windows `CreateSemaphore`) / `sem_t` (Posix).
- `TConnThreadSafeQueue<T>`: fila FIFO de espera, sem busy-wait, sinalizada por evento.
- `TConnThreadContextStore`: isola contexto por TID (cada thread vê só a sua conexão emprestada).

### 7.2 Ordem de aquisição de locks (FIXA — quebrar é erro)
```
1. FSemaphore.Wait        (controla quantas threads entram)
2. FPoolLock.Enter        (TCriticalSection do PoolStore)
3. FContextLock.Enter     (TConnThreadContextStore)
```
Nunca adquirir na ordem inversa. Nunca aninhar dois locks fora desta ordem. Esta é a garantia estrutural contra deadlock — não há ciclo de espera possível.

### 7.3 Regras
1. Toda **escrita** no pool passa por `TCriticalSection`.
2. Leitura concorrente de contexto usa `TMonitor` ou `TSpinLock` (leituras curtas).
3. O GC roda em `TThread` **separada** e nunca segura o mesmo lock que uma thread de negócio está usando; ele captura snapshot sob lock curto e fecha sockets **fora** do lock.
4. `Acquire` tem `acquireTimeout`; ao estourar, lança `EConn4DTimeoutException` (falha controlada, não trava).
5. Sem lock aninhado fora da ordem da seção 7.2.

Detalhes e exemplos em `references/threading-rules.md` na skill.

---

## 8. Garbage Collector de conexões

`TConnGarbageCollector` é uma `TThread` que acorda a cada `gcInterval` (padrão 30s). Cada ciclo:

1. Para cada pool registrado, captura snapshot de `Idle` e `InUse` sob lock curto.
2. Marca `Idle` com `(Now - LastReleasedAt) > idleTimeout` para evicção.
3. Classifica `InUse` com `(Now - AcquiredAt) > maxLeaseTime` como `Zombie`; loga TID + AcquiredAt; força `Rollback`; destrói.
4. Adquire lock exclusivo **apenas para remover** da lista (minimiza contenção).
5. Chama `IConnEngine.DestroyNative` **fora** do lock.
6. Publica `ceEvictedIdle` / `ceEvictedZombie` via `TConnObserverBroadcaster`.

Para testes determinísticos, `RunOnce` executa um ciclo sincronamente e o relógio é injetado via `IConnClock` (mock simula passagem de tempo sem `Sleep`).

---

## 9. Configuração

A configuração é uma **interface** `IConnConfig` (em `Conn4D.Core`),
implementada pela classe `TConnConfig` (em `Conn4D.Core.Config`) — programa-se
contra a abstração, não contra a classe. É o **único lugar com setters de
config** — um **builder fluente** (semântica de referência: cada setter muta o
objeto e devolve `Self`). Comece em `TConnConfig.New`; getters de leitura têm os
mesmos nomes (engines/PoolManager usam assim).

```pascal
// Builder fluente (IConnConfig):
Cfg := TConnConfig.New                       // -> IConnConfig
  .Provider('Firebird').Host('127.0.0.1').Port(3050)
  .Database('D:\dados\MEUBANCO.FDB').UserName('SYSDBA').Password('masterkey')
  .MaxSize(10).AcquireTimeout(5000).IdleTimeout(120000)
  .GCEnabled(True).GCInterval(30000);

// Leitura (getters de mesmo nome):
s := Cfg.Provider;      n := Cfg.Pool.MaxSize;

IConnConfig = interface  // Conn4D.Core (impl: TConnConfig em Core.Config)
  // getters:  Provider/Host/Port/Database/UserName/Password/ConnectTimeout
  //           Pool: TConnPoolConfig;  GC: TConnGCConfig;  Extra/GetExtra
  // setters fluentes -> IConnConfig:
  //   Provider/Host/Port/Database/UserName/Password/ConnectTimeout
  //   MinSize/MaxSize/AcquireTimeout/MaxLeaseTime/IdleTimeout (pool, achatados)
  //   GCEnabled/GCInterval (gc, achatados);  Extra(key,value)
  // Clone: IConnConfig;  BindTo(owner): IConnConfig;  EndConfig: IConn4D
end;
// TConnConfig.New: IConnConfig — defaults da spec.

TConnPoolConfig = record
  MinSize:         Integer;    // default 1
  MaxSize:         Integer;    // default 10
  AcquireTimeout:  Cardinal;   // ms, default 5000
  MaxLeaseTime:    Cardinal;   // ms, default 60000 (limite p/ virar zombie)
  IdleTimeout:     Cardinal;   // ms, default 120000 (limite p/ virar idle)
end;

TConnGCConfig = record
  Enabled:   Boolean;          // default True
  Interval:  Cardinal;         // ms, default 30000
end;
```

---

## 10. Tratamento de erros

Hierarquia em `Conn4D.Shared.Exceptions`:

```
EConn4DException                  (base)
├── EConn4DConfigException        (config inválida/incompleta)
├── EConn4DTimeoutException       (acquire estourou timeout)
├── EConn4DEngineException        (falha do driver)
├── EConn4DPoolExhaustedException (pool no limite, fila cheia)
├── EConn4DTransactionException   (commit/rollback inválido)
└── EConn4DCastException          (tipo nativo incompatível no adapter)
```

Operações que podem falhar de forma esperada retornam `TConnResult<T>` (sucesso/erro encapsulado); falhas excepcionais lançam exceção da hierarquia acima. O Core nunca engole exceção silenciosamente — sempre loga via `IConnLogger`.

---

## 11. Mapeamento SOLID (justificativa por princípio)

- **SRP** — `TConnPoolManager` só gerencia pool; `TConnGarbageCollector` só coleta; `TConnSemaphore` só limita concorrência; `TConnConfig` só carrega config. Builder fluente (`IFDConn4D`) separado do runtime evita acúmulo de responsabilidades.
- **OCP** — novo engine = nova unit no adapter + registro. Nenhuma alteração em Core/Shared. `IConnEngine` é o ponto de extensão.
- **LSP** — qualquer `IConnEngine` é intercambiável; o `TConnPoolManager` opera sobre o contrato sem saber a implementação. Mocks substituem engines reais nos testes sem quebrar invariantes.
- **ISP** — interfaces pequenas e focadas: `IConnHealthCheck`, `IConnGC`, `IConnObserver` separados em vez de uma interface gorda. O registry usa só `IConn4DBase`.
- **DIP** — Core depende de abstrações; adapters implementam. A camada de composição (umbrella `Conn4D` + `TConn4DCoreFactory`) injeta as implementações por construtor. Nenhuma classe do Core instancia engine concreto.

---

## 12. Pontos de decisão (todos congelados na v1.0)

| Decisão | Escolha | Justificativa |
|---|---|---|
| DDD vs Clean Arch | Clean Architecture (Ports & Adapters) | Biblioteca de infra, sem domínio de negócio |
| Facade público | Removido | Interfaces já são simples; fachada seria indireção sem propósito |
| Acesso à conexão | `operator Implicit` em record no adapter | Sem genérico no call site, sem cast; Core permanece agnóstico |
| Genérico `IConn4D<T>` | Descartado | Implicit operator no adapter é mais limpo e dá ergonomia melhor |
| Ciclo de vida do Acquire | Lazy open | Config vem encadeada após Acquire |
| Singleton vs instância | Múltiplas instâncias + registry global | Cada Conn4D controla suas conexões; registry centraliza controle |
| Settings vs Fluent | Coexistem (mesmo record, last-write-wins) | Máxima flexibilidade de configuração |

---

## 13. Roadmap de implementação (fases)

1. **Shared** — tipos, config, exceptions, logger. Sem código executável.
2. **Core/Abstractions** — todas as interfaces. Valida a arquitetura antes de qualquer implementação.
3. **Core/Services (sem engine real)** — `TConnSemaphore`, `TConnThreadSafeQueue<T>`, `TConnPoolStore`, `TConnObserverBroadcaster`, `TConn4DRegistry`. Testáveis com mock de engine.
4. **Core/Services (pool + tx)** — `TConnPoolManager`, `TConnTransactionManager`, `TConnHealthMonitor`. Testes com `TMockEngine`.
5. **Seam + Adapter FireDAC** — `TConnRef`/`IConn4DNative` (Conn4D.Adapter.ConnRef), `TFireDACEngine`, `IFDConn4D`, `TFDConn4D.Acquire`. Integração real + testes de integração.
6. **Garbage Collector** — `TConnGarbageCollector` com `IConnClock` mockado; testes de lifecycle completo.
7. **Engines adicionais** — Zeos, UniDAC. Cada um isolado, fases independentes, Core intocado.

---

## 14. Critérios de aceitação

- [ ] Core e Shared compilam **sem** nenhuma unit de FireDAC/Zeos/UniDAC nos `uses`.
- [ ] `FDQuery.Connection := Conn4D.Connection;` compila sem cast e sem genérico.
- [ ] Trocar FireDAC por outro engine não altera nenhuma unit de Core/Shared.
- [ ] Teste de stress: N threads (N > poolSize) em paralelo nunca obtêm mais que `poolSize` conexões ativas, nunca recebem a mesma conexão simultaneamente, nunca causam deadlock.
- [ ] GC encerra conexão idle após `idleTimeout` e zombie após `maxLeaseTime` (verificável com relógio mockado).
- [ ] `Acquire` além de `poolSize` enfileira e respeita `acquireTimeout`, lançando `EConn4DTimeoutException` ao estourar.
- [ ] Cobertura de testes unitários do Core ≥ 80%, com engine 100% mockado (sem banco real).
- [ ] Registry permite shutdown global de todos os managers em uma chamada.
