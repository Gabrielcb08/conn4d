# Contributing

Thanks for considering a contribution to Conn4D. This document covers the guardrails — coding conventions, architectural rules, and the PR checklist — so your work merges cleanly.

## Ground Rules

- **Preserve architectural boundaries.** Outer layers depend only on `Application Contracts`. `Application` never depends on `Infrastructure`. Domain holds only pure types (enums, exceptions, config records). If your change crosses these boundaries, open an issue first.
- **No FireDAC outside Infrastructure.** `uses FireDAC.Comp.Client` (or any FireDAC unit) must not appear outside `src/04 - Infrastructure/FireDAC/`. Verify with grep before opening a PR.
- **Add tests for behavioral changes.** Every bug fix, new feature, or behavior tweak needs a DUnitX test that fails before your change and passes after. See [TESTING.md](TESTING.md).
- **Keep methods small and focused.** Split private helpers before logic grows past one screen.
- **Don't introduce dependencies** beyond what's already in `boss.json`. New runtime deps need discussion.
- **Backwards compatibility on the public API** unless explicitly bumping a major/minor version. The public API is what `uses Conn4D;` exposes.

## Coding Standards

- **Target:** Delphi 12 (Athens). Earlier versions are not supported.
- **Style reference:** `src/03 - Application/Conn4D.Application.Handle.pas`. Mirror it.
- **Aligned colons** in field, parameter, and local-variable declarations:

  ```delphi
  var
    Pool     : TConn4DPool;
    Registry : TConn4DPoolRegistry;
    Config   : TConn4DPoolConfig;
  ```

- **Spaces around `:`** in every type annotation:

  ```delphi
  procedure Acquire(const APoolName : string; out AHandle : TConn4DHandle); ✓
  procedure Acquire(const APoolName: string; out AHandle: TConn4DHandle);   ✗
  ```

- **Favor interfaces and explicit dependencies.** Concrete types are confined to Infrastructure and the IoC registrations.
- **No hidden side effects** — no implicit global state, no static `var` accumulators outside `TConn4DPoolRegistry`.
- **Do not use exceptions for control flow.** They're for exceptional paths (pool exhausted, cast failure, transaction state violation), not branching.

## Naming

- **Interfaces:** `IConn4DXxx` (Application Contracts).
- **Classes:** `TConn4DXxx` for application/infrastructure classes; `TConn4DFireDACXxx` for FireDAC-specific implementations.
- **Records:** `TConn4DXxx` for public value types (`TConn4DHandle`, `TConn4DTransaction`, `TConn4DPoolConfig`).
- **Exceptions:** `EConn4DXxxException`, all descending from `EConn4DException`.
- **Test fixtures:** `TXxxTest`, units named `Conn4D.Tests.<Layer>.<XxxTest>.pas`.

## Pull Request Checklist

Before opening a PR:

- [ ] **Builds clean** on Delphi 12 (`packages/Delphi12/Conn4D.dproj` and `tests/Conn4D.Tests/Conn4D.Tests.dproj`).
- [ ] **No new compile warnings** introduced by your code.
- [ ] **All tests pass** with `Conn4D.Tests.exe --console` (integration tests skipped if env vars absent — that is acceptable).
- [ ] **New tests added** for new behavior — naming follows `Method_Scenario_ExpectedResult` (e.g., `Acquire_PoolExhausted_RaisesException`).
- [ ] **No layer-rule violations** — verify the `uses` clauses respect the dependency direction. No `FireDAC` outside Infrastructure.
- [ ] **`docs/CHANGELOG.md` updated** with a one-line entry under `Unreleased` or a new version block.
- [ ] **`docs/ARCHITECTURE.md` updated** if you added/removed/renamed a component.
- [ ] **No generated binaries committed.** `build/`, `__history/`, `*.identcache`, `*.local` stay out (already in `.gitignore`).
- [ ] **No formatting churn** — touch only the lines your feature/fix actually changes.

## Commit Messages

Keep them short, imperative, and focused on the **why**:

```
fix: TConn4DPool.Sweep releases idle slots correctly under concurrent acquire
feat: TConn4DHandle.IsValid check for disposed handles
docs: clarify RAII semantics for nested transactions in README
test: cover auto-rollback when TConn4DTransaction is abandoned
```

Prefixes (`fix`, `feat`, `docs`, `test`, `refactor`, `chore`) help the changelog automation but are not strictly required.

## Reporting Bugs

Open an issue with:

- **Conn4D version** (commit or tag).
- **Delphi version** (12 Athens, build number).
- **Minimal repro** — ideally a 10-line `.dpr` that fails.
- **Expected vs actual behavior**.
- **Stack trace** if a crash is involved.
- **Database and driver** (Firebird version, FireDAC driver ID, connection params — omit credentials).

## Suggesting Features

Issues labeled `enhancement` are welcome. Before sending code:

1. Open an issue describing the use case and the proposed API.
2. Wait for a thumbs-up on the approach — saves rework when the design doesn't fit.
3. Send a PR referencing the issue.

New database providers are especially welcome — see [ARCHITECTURE.md](ARCHITECTURE.md#adding-a-new-provider) for the three-step guide.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](../LICENSE).
