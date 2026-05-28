# Conn4D

Provider-neutral connection management library for Delphi 12 with first-class FireDAC + Firebird adapter, named pools, RAII leasing, transactional scopes with nested savepoints, background sweep, async helpers and Spring4D integration.

**Conn4D is a connection library. It does not execute SQL.** Query execution, parameter binding and result-set mapping are deliberately out of scope — the consumer (or a layer built on top of Conn4D) emits SQL against the connection/transaction handles exposed by the API.

## Installation

```bash
boss install https://github.com/gabrielcb08/conn4d@v0.3.0-alpha.1
```

Dependencies:

- `spring4d`
- `DUnitX`

## Architecture

```text
src/
├─ 01 - Domain/                  ← exceptions, defaults, tx state enum
├─ 02 - Application Contracts/   ← public interfaces (provider-neutral)
├─ 03 - Application/             ← manager, builder, scope registry
├─ 04 - Infrastructure/
│  ├─ Async/                     ← TConn4DTaskExtensions
│  ├─ FireDAC/                   ← provider, connection handle, transaction handle, scope
│  ├─ Logging/                   ← TNullLogger base class
│  ├─ Pooling/                   ← pool, slot, lease
│  └─ Settings/                  ← JSON / INI loaders
├─ 05 - Presentation/Facades/    ← static façade TConn4D
└─ 06 - IoC/                     ← Spring4D bootstrap (TConn4DContainer)
```

### Public contracts

- `IConnectionManager` — pool registration, `Acquire`, `BeginScope`, `Sweep`.
- `IConnectionSettingsBuilder` — fluent pool builder.
- `IConnectionLease` — RAII borrow with provider-neutral `Connection: IConn4DConnectionHandle`.
- `IConn4DConnectionHandle` — neutral connection wrapper with `AsType<T>` cast helper.
- `IConn4DTransactionHandle` — neutral transaction wrapper exposing the active transaction and `SavepointName`.
- `IConn4DTransactionScope` — `Complete`, `Rollback`, `State`, `Depth`, `IsRoot`, `Connection`, `Transaction`.
- `IConn4DLogger` — observability hooks for pool and transaction lifecycle.
- `IConn4DSettingsLoader` — JSON / INI bootstrap.
- `TConn4D` — static façade.
- `TConn4DContainer` — Spring4D bootstrap.

### Lifecycle

1. The application registers Conn4D in Spring4D (or in its own container).
2. One or more named pools are registered through the fluent builder.
3. `Acquire('pool-name')` borrows a connection without opening a transaction. `BeginScope('pool-name')` borrows a connection and opens a transaction.
4. Nested `BeginScope` calls on the same `(thread, pool)` share the root connection and emit SAVEPOINTs — no extra pool slot is consumed.
5. Releasing the last reference to the lease (or scope) returns the connection to the pool. A scope without `Complete` rolls back automatically and emits `OnTransactionAbandoned`.
6. A dedicated sweeper thread reclaims idle and unhealthy connections in the background.

### Pool policy

- lazy creation of native handles;
- preferential reuse of idle, healthy connections;
- `MaxPoolSize` default `10`;
- `AcquireTimeout` default `5000 ms`;
- `IdleTimeout` default `300000 ms`;
- `SweepInterval` default `60000 ms`;
- `EConn4DPoolExhaustedException` when the pool is full and no slot becomes available within the timeout.

### Provider-neutral handle

`IConn4DConnectionHandle` is the only object the public API hands out to access the native driver connection. To reach the FireDAC `TFDConnection`:

```delphi
var Conn := Lease.Connection.AsType<TFDConnection>;
```

`AsType<T>` performs an `is`-check and raises `EConn4DHandleCastException` if the native object is nil or of the wrong type — a clear failure mode if a future provider is wired into the same code path.

Default transaction options (`'read_committed,rec_version,wait'`) are Firebird-specific. Override them per-pool with `.DefaultTransactionOptions('isolation=...')` when targeting another driver.

## Quick start

### Bootstrap

```delphi
uses
  Conn4D;

begin
  TConn4DContainer.RegisterServices; // registers IConnectionProvider + IConnectionManager singletons
end;
```

For an external container:

```delphi
uses
  Spring.Container,
  Conn4D;

var
  Container: TContainer;
begin
  Container := TContainer.Create;
  TConn4DContainer.RegisterServices(Container);
  Container.Build;
end;
```

### Register a pool

```delphi
TConn4D.RegisterPool('default')
  .Host('127.0.0.1')
  .Port(3050)
  .Database('C:\Dados\APP.FDB')
  .UserName('SYSDBA')
  .Password('masterkey')
  .DriverID('FB')
  .MaxPoolSize(10)
  .AcquireTimeout(5000)
  .IdleTimeout(300000)
  .SweepInterval(60000)
  .AddParam('Protocol', 'TCPIP')
  .Register;
```

### Acquire a lease (no implicit transaction)

```delphi
uses
  FireDAC.Comp.Client,
  Conn4D,
  Conn4D.Application.Contracts.IConnectionLease;

var
  Lease: IConnectionLease;
  Query: TFDQuery;
begin
  Lease := TConn4D.Acquire('default');

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Lease.Connection.AsType<TFDConnection>;
    Query.SQL.Text := 'select current_date from rdb$database';
    Query.Open;
  finally
    Query.Free;
  end;
end;
```

### Transactional scope

```delphi
uses
  FireDAC.Comp.Client,
  Conn4D,
  Conn4D.Application.Contracts.IConn4DTransactionScope;

var
  Tx: IConn4DTransactionScope;
  Query: TFDQuery;
begin
  Tx := TConn4D.BeginScope('default');
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Tx.Connection.AsType<TFDConnection>;
    Query.Transaction := Tx.Transaction.AsType<TFDTransaction>;
    Query.SQL.Text := 'UPDATE PRODUTOS SET DESCRICAO = :d WHERE ID = :id';
    Query.ParamByName('d').AsString := 'NEW';
    Query.ParamByName('id').AsInteger := 42;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
  Tx.Complete; // commits when the last reference is released
end;
```

Calling `Tx.Rollback` forces an immediate rollback. The scope state transitions to `tsRolledBack`; subsequent `Complete` raises `EConn4DTransactionStateException`. Nested `BeginScope` calls on the same `(thread, pool)` emit `SAVEPOINT <name>` and share the outer connection.

### Async scope

```delphi
TConn4D.BeginScopeAsync('default',
  procedure(const AScope: IConn4DTransactionScope)
  begin
    // ... run TFDQuery against AScope.Connection / AScope.Transaction ...
    AScope.Complete;
  end);
```

## Out of scope

The following are intentionally **not** part of Conn4D and belong in a layer built on top of it:

- SQL execution helpers (`Execute`, `Query`, `Scalar`);
- Result-set readers / row mappers;
- Parameter binding APIs;
- ORM / repository / unit-of-work abstractions.

A consuming package (for instance, a future `Query4D`) is the right place for those concerns. Inside Conn4D, the only public surface that accepts SQL is the consumer's own `TFDQuery` bound to a scope handle.

## Spring4D

`TConn4DContainer` registers:

- `TFireDacConnectionProvider` as `IConnectionProvider`;
- `TConnectionManager` as `IConnectionManager` (singleton);
- the active `IConn4DLogger` (defaults to `TNullLogger`).

The parameterless overload registers in `GlobalContainer` and calls `Build`. The overload with an external container only registers — the caller controls `Build`.

## Distribution layout

- `boss.json`
- `packages/Delphi12/Conn4D.dpk` / `.dproj`
- `samples/BasicUsage` / `samples/AdvancedUsage`
- `tests/Conn4D.Tests`

## Tests

The DUnitX suite covers:

- pool registration and acquisition;
- idle reuse of pooled connections;
- protection against discarding a leased connection;
- idle timeout sweep;
- unhealthy-connection sweep;
- pool isolation;
- `MaxPoolSize` and `AcquireTimeout` enforcement;
- concurrent acquisition;
- Spring4D bootstrap;
- transaction scope `Rollback`, idempotency, and savepoint exposure;
- real Firebird integration (skipped when environment variables are absent).

Environment variables for the integration tests:

- `CONN4D_FIREBIRD_DATABASE`
- `CONN4D_FIREBIRD_HOST`
- `CONN4D_FIREBIRD_PORT`
- `CONN4D_FIREBIRD_USER`
- `CONN4D_FIREBIRD_PASSWORD`

## v0.2 notes

- Breaking change from `0.1.0-alpha.1`: `Execute`, `Query`, `Scalar`, `Prepare`, `IConn4DCommand`, `IConn4DReader` and `IFireDacConnectionLease` were removed. Replace `Lease.Handle` with `Lease.Connection.AsType<TFDConnection>` and run SQL against your own `TFDQuery`.
- Provider-neutral by design. The FireDAC adapter (`TFireDacConnectionProvider` + `TConn4DFireDacConnectionHandle` + `TConn4DFireDacTransactionHandle`) is the bundled implementation; additional providers can plug in by implementing `IConnectionProvider.CreateHandleWrapper`.
- Default transaction options are Firebird-specific and per-pool overridable.
