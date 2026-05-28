# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0-alpha.1] - 2026-05-25

### Changed
- **RAII value-type API**: `TConn4DHandle` and `TConn4DTransaction` are now lightweight record types (RAII). Acquiring a connection returns `TConn4DHandle` directly; `Handle.BeginTransaction` returns `TConn4DTransaction`. Implicit operators allow direct assignment to `TFDConnection` / `TFDTransaction`.
- **Fluent configurator**: pool registration moved to `TConn4D.Configure.Pool('name')…Apply` via `TConn4DConfigurator` / `TConn4DPoolBuilder`. Previous `IConnectionManager.RegisterPool` facade removed.
- **Spring4D no longer required**: `TConn4DContainer` (Spring4D bootstrap) is now opt-in. The core library depends only on FireDAC and DUnitX (tests). Remove `bitbucket.org/sglienke/spring4d` from `boss.json` if not using the IoC layer.
- `TConn4D.Acquire` now returns `TConn4DHandle` instead of `IConnectionLease`.
- `TConn4DTransaction.Commit` / `Rollback` replace the previous `IConn4DTransactionScope.Complete` / `Rollback` pattern.
- Added `TConn4D.Shutdown` for explicit cleanup on application exit.

### Removed
- `IConnectionLease`, `IConn4DTransactionScope`, `IConnectionManager`, `IConnectionSettingsBuilder` — replaced by the RAII record API.
- `TConn4DCast` — type-safe casts now done via `TConn4DHandle.Connection<T>` and `TConn4DTransaction.Transaction<T>` generic methods.

## [0.2.0-alpha.1] - 2026-05-18

### Added
- **Provider-neutral handle**: `IConn4DNativeConnection` and `IConn4DNativeTransaction` — zero `uses FireDAC` outside the Infrastructure layer.
- **`TConn4DCast`** type-safe generic accessor (`TConn4DCast.ConnectionAs<TFDConnection>`, `TConn4DCast.TransactionAs<TFDTransaction>`). Needed because Delphi 12 forbids generic methods in interfaces (`E2535`).
- `IConn4DTransactionScope.Rollback` — idempotent, state transitions to `tsRolledBack`. Subsequent `Complete` raises `EConn4DTransactionStateException`.
- `TConn4D.Acquire` promoted to public API (was internal helper) — leases a connection without opening a transaction.
- `IConnectionProvider.CreateHandleWrapper` — plugs custom providers without touching pool internals.
- `TConn4DContainer` Spring4D bootstrap.

### Removed
- **`IConn4DCommand`**, **`IConn4DReader`**, **`IConn4DReaderRow`** and all SQL-execution methods (`Execute`, `Query`, `Scalar`, `Prepare`, `Raw`) from `IConnectionManager`, `IConn4DTransactionScope`, and the `TConn4D` façade. SQL execution now belongs to a consumer package (e.g., Query4D).
- `IFireDacConnectionLease` — replaced by `IConnectionLease` with `Connection: IConn4DConnectionHandle`.
- `IConn4DLogger.OnQuery` / `TConn4DQueryKind` — the library no longer emits SQL events.

### Changed
- `IConnectionLease` redesigned: exposes `Connection: IConn4DConnectionHandle` instead of a raw `TFDConnection`.
- Pool infrastructure made fully provider-agnostic (`uses FireDAC.Comp.Client` confined to `04 - Infrastructure/FireDAC/`).
- `TConnectionManager._AddRef`/`_Release` override to `-1` (disables Delphi reference counting) — prevents accidental double-free when the class is used both as a strong reference and as a Spring4D singleton.

## [0.1.0-alpha.1] - 2026-05-08

- Initial public baseline.
- Named connection pools with lazy creation and idle-connection reuse.
- Fluent pool builder (`IConnectionSettingsBuilder`).
- `IConnectionManager` with `RegisterPool`, `BeginScope`, `Execute`, `Query`, `Scalar`.
- `IConn4DTransactionScope` with nested savepoint support.
- FireDAC adapter (`TFireDacConnectionProvider`).
- Background sweeper thread (idle timeout + unhealthy connection cleanup).
- Spring4D IoC bootstrap (`TConn4DContainer`).
- DUnitX test suite.
- Boss packaging metadata.
