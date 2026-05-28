# Conn4D Documentation

Welcome to the Conn4D documentation. The main entry points are the project [README](../README.md) (English) and [README.pt-BR](../README.pt-BR.md) (Portuguese summary). This folder holds the deeper material.

## Index

| Document                              | What's inside                                                        |
| ------------------------------------- | -------------------------------------------------------------------- |
| [ARCHITECTURE.md](ARCHITECTURE.md)   | Layering, components, connection-acquire and transaction flows.       |
| [TESTING.md](TESTING.md)             | DUnitX framework, environment variables, running tests, conventions. |
| [CONTRIBUTING.md](CONTRIBUTING.md)   | Coding standards, PR checklist, bug reporting.                       |
| [BOSS.md](BOSS.md)                   | Install/update via Boss, release workflow, publish checklist.        |
| [CHANGELOG.md](CHANGELOG.md)         | Version-by-version change log (mirrors the root one).                |

## Quick links

- **Public API surface** — re-exported via `Conn4D.pas`: `TConn4D`, `TConn4DHandle`, `TConn4DTransaction`, `TConn4DConfigurator`, `TConn4DPoolBuilder`.
- **Samples**: [samples/BasicUsage](../samples/BasicUsage) and [samples/AdvancedUsage](../samples/AdvancedUsage) — runnable end-to-end demos.
- **Tests**: [tests/Conn4D.Tests/](../tests/Conn4D.Tests/) — DUnitX test suite.

## Project status

Conn4D is in **alpha** (`0.3.0-alpha.1`). The public API is stable for the documented features; the [CHANGELOG](CHANGELOG.md) lists what changed between versions.

Bug reports and feature requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
