# Architecture

Conn4D is built on Clean Architecture with strict dependency boundaries. This document covers the layering, the responsibility of each component, and the runtime flows for connection acquisition and transactional scopes.

## Principles

- **Clean Architecture** with dependencies pointing inward (toward Domain and Application Contracts).
- **Provider-neutral** — the public API has zero dependency on FireDAC. The FireDAC adapter lives entirely in `04 - Infrastructure/FireDAC/` and is plug-in replaceable.
- **RAII by default** — `TConn4DHandle` and `TConn4DTransaction` are records; the pool slot is released and the transaction is rolled back automatically when the record goes out of scope without an explicit `Commit`.
- **No SQL execution, no ORM** — Conn4D hands out connection/transaction handles; SQL execution belongs in a consumer layer (e.g., Query4D).
- **Optional Spring4D** — `TConn4DContainer` provides IoC bootstrap if Spring4D is present, but the core library has no hard dependency on it.

## Layering

```
src/
├─ 01 - Domain/                  ← enums, exceptions, value objects, pool config
├─ 02 - Application Contracts/   ← provider-neutral interfaces (ports)
├─ 03 - Application/             ← pool management, RAII records, fluent configurator
├─ 04 - Infrastructure/
│  ├─ Async/                     ← TConn4DTaskExtensions (async scope helpers)
│  ├─ FireDAC/                   ← IConn4DProvider adapter for FireDAC
│  ├─ Logging/                   ← TNullLogger base class (virtual, override-friendly)
│  ├─ Pooling/                   ← TConn4DPool and slot management
│  └─ Settings/                  ← JSON / INI configuration loaders
├─ 05 - Presentation/Facades/    ← TConn4D static façade
└─ 06 - IoC/                     ← TConn4DContainer (Spring4D bootstrap, opt-in)
```

`02 - Application Contracts` concentrates every port consumed by outer layers: the provider contract (`IConn4DProvider`), native connection/transaction wrappers (`IConn4DNativeConnection`, `IConn4DNativeTransaction`), and the internal pool contract (`IConn4DPool`). Outer layers depend **only** on these contracts — never on Infrastructure implementations.

## Components

| Layer                 | Component                            | Responsibility                                               |
| --------------------- | ------------------------------------ | ------------------------------------------------------------ |
| Domain                | `TConn4DPoolState`                   | Enum: pool slot states                                       |
| Domain                | `TConn4DTxState`                     | Enum: `tsActive`, `tsCommitted`, `tsRolledBack`, `tsAbandoned` |
| Domain                | `TConn4DDefaults`                    | Default pool policy constants (MaxPoolSize, timeouts)        |
| Domain                | `TConn4DPoolConfig`                  | Pool configuration record (`ApplyDefaults`, `Validate`)     |
| Domain                | `EConn4D*Exception`                  | Exception hierarchy                                          |
| Application Contract  | `IConn4DNativeConnection`            | Provider-neutral connection wrapper                          |
| Application Contract  | `IConn4DNativeTransaction`           | Provider-neutral transaction wrapper                         |
| Application Contract  | `IConn4DProvider`                    | Extension point for database engines                         |
| Application Contract  | `IConn4DPool`                        | Internal pool contract (`Acquire`, `Release`, `Sweep`)       |
| Application           | `TConn4DHandle`                      | RAII record — leases a connection, releases on destruction   |
| Application           | `TConn4DTransaction`                 | RAII record — wraps a transaction, auto-rollback on abandon  |
| Application           | `TConn4DConfigurator`                | Entry point for pool registration fluent chain               |
| Application           | `TConn4DPoolBuilder`                 | Fluent builder (Host, Port, Database, DriverID, limits)      |
| Application           | `TConn4DPool`                        | Thread-safe pool: lazy creation, idle reuse, slot tracking   |
| Application           | `TConn4DPoolRegistry`                | Singleton registry of named pools + sweeper thread lifecycle |
| Infrastructure        | `TConn4DFireDACProvider`             | `IConn4DProvider` for FireDAC; creates/connects/validates connections |
| Infrastructure        | `TConn4DFireDACNativeConnection`     | `IConn4DNativeConnection` wrapping `TFDConnection`           |
| Infrastructure        | `TConn4DFireDACNativeTransaction`    | `IConn4DNativeTransaction` wrapping `TFDTransaction`         |
| Infrastructure        | `TConn4DTaskExtensions`              | Async scope helpers                                          |
| Infrastructure        | `TNullLogger`                        | No-op logger base; override in consumer for observability    |
| Infrastructure        | Settings loaders                     | JSON (`TConn4DJsonLoader`) and INI (`TConn4DIniLoader`) bootstrap |
| Presentation          | `TConn4D`                            | Static façade (`Configure`, `Acquire`, `PoolExists`, `Sweep`, `Shutdown`) |
| IoC                   | `TConn4DContainer`                   | Spring4D registrations (opt-in)                              |

## Connection Acquire Flow

1. Consumer calls `TConn4D.Acquire('pool-name')`, which resolves the pool from `TConn4DPoolRegistry`.
2. `TConn4DPool.Acquire` selects the first idle, healthy slot (or creates a new one up to `MaxPoolSize`).
3. If no slot is available within `AcquireTimeout`, `EConn4DPoolExhaustedException` is raised.
4. The slot's native connection is wrapped by `IConn4DProvider.CreateNativeConnectionWrapper` into an `IConn4DNativeConnection`.
5. A `TConn4DHandle` record is returned to the consumer, holding a reference to the slot guard.
6. When the `TConn4DHandle` is destroyed (scope exit or explicit release), the slot guard releases the slot back to the pool.

## Transaction Flow

1. Consumer calls `Handle.BeginTransaction`, which asks the pool to open a transaction on the leased connection.
2. For a root scope, `TConn4DFireDACNativeTransaction` creates a `TFDTransaction` linked to the connection.
3. For nested scopes on the same `(thread, pool)`, a `SAVEPOINT <name>` is emitted — no extra pool slot consumed.
4. A `TConn4DTransaction` record is returned to the consumer.
5. `Tx.Commit` commits (or releases the savepoint for nested scopes).
6. `Tx.Rollback` is idempotent — rolls back to savepoint on nested, full rollback on root. State → `tsRolledBack`; subsequent `Commit` raises `EConn4DTransactionException`.
7. If neither `Commit` nor `Rollback` is called and the record is destroyed, the transaction is automatically rolled back and state → `tsAbandoned`.

## Background Sweep

`TConn4DPoolRegistry` starts a sweeper thread on first pool registration. The sweeper periodically calls `TConn4DPool.Sweep` on each registered pool:

- Slots idle longer than `IdleTimeout` are disconnected and returned to the free list.
- Slots whose health check (`IsHealthy`) fails are disconnected and rebuilt on next `Acquire`.
- `TConn4D.Sweep('pool-name')` triggers a manual sweep and returns the number of slots reclaimed.

## Adding a New Provider

1. Implement `IConn4DProvider` — `Name`, `CreateHandle`, `EnsureConnected`, `IsHealthy`, `DestroyHandle`, `CreateNativeConnectionWrapper`.
2. Implement `IConn4DNativeConnection` for the native connection type.
3. Implement `IConn4DNativeTransaction` for the native transaction type.
4. Register the provider via `TConn4D.RegisterProvider(TMyProvider.Create)` before configuring pools.

No changes to the pool, registry, or public API are required.

## Coding Style

The reference unit for formatting is `src/03 - Application/Conn4D.Application.Handle.pas`:

- Aligned colons in field, parameter, and local-variable declarations.
- Spaces around `:` in every type annotation.
- One concept per method; private helpers split before logic grows past a screen.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full PR checklist.
