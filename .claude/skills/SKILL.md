---
name: conn4d-builder
description: "Build and extend the Conn4D Delphi connection-management library — a Clean Architecture / SOLID library with connection pooling, connection garbage collection, multi-thread safety, and pluggable database engines (FireDAC, Zeos, UniDAC). Use this skill whenever the user asks to implement, modify, review, or extend Conn4D: writing any Core/Shared/Adapter unit, adding a new database engine, implementing the pool manager, connection garbage collector, semaphore, thread-safe queue, transaction manager, registry, the fluent builder interfaces, or writing DUnitX tests for any of these. Trigger this even when the user only mentions a piece of the library (e.g. 'implement the pool manager', 'add a Zeos engine', 'write the IConnEngine for X', 'create the GC thread') without naming Conn4D explicitly, as long as the conversation is about this library. Enforces the layering, naming, thread-safety, and SOLID rules so generated code stays consistent and never violates the architecture."
---

# Conn4D Builder

Skill for implementing and extending the Conn4D connection-management library consistently. Conn4D is a Delphi infrastructure library — connection pool, connection garbage collection, multi-thread safety, and swappable engines — under Clean Architecture (Ports & Adapters) and SOLID. There is **no business domain**, so DDD does not apply.

Read the master spec (`conn4d-spec.md`) for the full contract surface before implementing anything substantial. This skill encodes the rules that the generated code must never violate.

## Layering — the rule that governs everything

Three layers plus a transversal one. Dependencies point inward only:

```
Adapters ──► Core ──► Shared
```

- **Shared** — types, config records, exceptions, `IConnLogger`. Depends on nothing.
- **Core** — abstractions (interfaces) + engine-agnostic algorithms (pool, GC, semaphore, queue, registry, transaction manager). Depends only on Shared.
- **Adapters** — the only layer allowed to `uses` a concrete engine (FireDAC, Zeos, UniDAC).

**Hard rule:** any unit under `Core/` or `Shared/` that has `FireDAC`, `Zeos`, or `Uni` in its `uses` clause is a bug. The Core sees engines only through `IConnEngine`, which returns `TObject`. If you ever feel tempted to reference a concrete connection type in Core, stop — that knowledge belongs in an Adapter.

## Naming conventions

Follow these exactly so the codebase reads as one voice:

- Units: `Conn4D.<Layer>.<Concern>.pas` (e.g. `Conn4D.Core.PoolManager.pas`, `Conn4D.Adapter.FireDAC.pas`).
- Interfaces: `IConn...` (`IConnEngine`, `IConnPool`, `IConn4DBase`). Engine-specific marker interface: `I<Engine>Conn4D` (`IFDConn4D`, `IZConn4D`).
- Classes: `TConn...` for Core services (`TConnPoolManager`, `TConnGarbageCollector`). The universal connection handle is the record `TConnRef` (one seam, not one per engine).
- Every interface carries a stable GUID. Never reuse a GUID across interfaces.
- Use ubiquitous, unabbreviated names. `AcquireTimeout`, not `AcqTO`.

## The connection-access pattern (most error-prone)

The consumer must be able to write, with no generic and **no cast**, holding an
engine-**agnostic** handle:

```pascal
FDQuery.Connection := Conn4D.Connection;          // component (TConn4D)
// or, programmatic, agnostic variable:
var Conn: IConn4DNative;
FDQuery.Connection := Conn.Connection;
```

This works because `Connection` returns the universal record `TConnRef`, which has
one `class operator Implicit` **per enabled engine** (FireDAC always; Zeos/UniDAC
under their `Conn4D.inc` defines). The compiler picks the operator by the
left-hand-side type. Because that record names framework types
(`TFDCustomConnection`, ...), it lives in the **boundary seam**
`Conn4D.Adapter.ConnRef` (the Interface Adapters ring) — **never in Core**. Core
(`Conn4D.Core`, `Conn4D.Shared`) must not `uses` an engine nor the seam: that is the
cardinal sin, enforced by `scripts/check-architecture.ps1`.

The seam also defines `IConn4DNative = interface(IConn4D)` — an **agnostic**
interface that extends the pure Core port and adds `Connection`. Consumers hold it
(or `IFDConn4D`, which extends it, or the `TConn4D` component) and call
`.Connection` with no cast. Switching engine later does not change the variable type
(it stays agnostic) — only the query class (`TFDQuery` → `TZQuery`) changes.

Key facts to keep correct:
- `operator Implicit` exists on **records**, not on interfaces or classes. Do not try to put it on `IConn4DBase`.
- The mismatch (assigning to the wrong engine's connection type) is caught at runtime by a checked `as` cast → `EInvalidCast`. The native engine in use is the one the query type expects.
- The record carries a **reference** to the native connection; it does not own it. The pool and GC own the lifetime. Consumer code never calls `Free` on the native connection.

## Thread-safety rules (deadlock prevention)

Before writing any code that touches shared state, read `references/threading-rules.md`. The non-negotiables:

1. All mutation of pool state goes through the single `TConnPoolStore`, guarded by `TCriticalSection`.
2. Lock acquisition order is fixed: `Semaphore.Wait` → `PoolLock.Enter` → `ContextLock.Enter`. Never invert, never nest outside this order. This is the structural guarantee against deadlock.
3. The GC runs on its own `TThread`, takes only short snapshot locks, and closes sockets outside any lock.
4. `Acquire` always honors `AcquireTimeout` and raises `EConn4DTimeoutException` on expiry — it never blocks forever.

## Adding a new engine

When the user asks to add Zeos, UniDAC, or any other engine, read `references/add-engine.md` and follow it. The short version: implement `IConnEngine` in `Conn4D.Engine.<Name>.pas`; create `I<Name>Conn4D = interface(IConn4DNative)` + `T<Name>Conn4D.Acquire` in `Conn4D.Adapter.<Name>.pas` (the impl implements `IConn4DNative.Connection` via `TConnRef.Wrap`); add one `class operator Implicit(...): T<Name>Connection` under the engine's IFDEF in the seam `Conn4D.Adapter.ConnRef`; **self-register the facade in the adapter's `initialization`** via `TConn4DEngines.Register('<engineid>', ...)` (`Conn4D.Adapter.Engines`) and link the adapter from the umbrella under IFDEF. The component `TConn4D` resolves by EngineID and is **never edited** for a new engine (OCP). Touch zero Core/Shared units — the only shared edits are the conditional operator in the seam and the conditional `uses` in the umbrella. If a change to Core seems necessary, the abstraction is wrong.

## Testing requirements

Use DUnitX. Every Core service is tested with `TMockEngine` and a mocked `IConnClock` — never a real database. Required test coverage:

- Pool: respects `MaxSize`, queues beyond capacity, honors `AcquireTimeout`, returns connections on `Release`, never hands the same connection to two threads.
- GC: evicts idle after `IdleTimeout`, kills zombies after `MaxLeaseTime` — driven by the mocked clock, with no `Sleep`.
- Thread safety: spawn N > poolSize threads, assert invariants (never more than poolSize active, never a duplicate handout, no deadlock).
- Engine swap: the same Core test suite passes with two different mock engines, proving LSP.

## SOLID checklist before finishing any unit

Run this mentally before declaring a unit done:

- Does this class have exactly one reason to change? (SRP)
- Could I add an engine without editing this file? (OCP — should be yes for Core)
- Does this depend on an abstraction rather than a concrete type? (DIP)
- Is the interface focused, or did it accumulate unrelated methods? (ISP)
- Would a mock substitute cleanly here? (LSP + testability)

If any answer is wrong, the unit is not done.

## Output expectations

Produce complete, compilable Delphi units — interface and implementation sections both present, `uses` clauses correct for the layer, GUIDs on interfaces. No pseudocode. When a unit is large, build it section by section and keep the final version coherent. State the architectural reasoning for non-obvious choices briefly, in prose, not as inline noise in the code.

## Reference files

- `references/threading-rules.md` — concurrency model, lock ordering, deadlock avoidance, GC threading. Read before writing any shared-state code.
- `references/add-engine.md` — step-by-step for adding a new database engine adapter. Read before adding Zeos, UniDAC, or any new driver.
