# Testing

Conn4D ships a DUnitX-based test suite covering pool mechanics, transaction scopes, settings loaders, and Spring4D bootstrap. Integration tests against a real Firebird database are skipped automatically when the required environment variables are absent.

## Framework

- **[DUnitX](https://github.com/VSoftTechnologies/DUnitX)** — vendored under `modules/DUnitX/`.
- The test project is a Delphi 12 VCL application that also runs as a console runner (`--console`).
- Memory leak reporting is opt-in via `--leaks` (combine with `--console`).

## Project layout

```
tests/
└─ Conn4D.Tests/
   ├─ Application/
   │  ├─ Conn4D.Tests.Application.TransactionScopeRegistryTest.pas  ← savepoint / scope registry
   │  └─ Conn4D.Tests.Application.TransactionScopeTest.pas          ← Commit / Rollback / abandon
   ├─ Infrastructure/
   │  ├─ Conn4D.Tests.Infrastructure.LeaseTest.pas                   ← pool acquisition, reuse
   │  ├─ Conn4D.Tests.Infrastructure.FirebirdIntegrationTest.pas     ← real Firebird (env-gated)
   │  └─ Conn4D.Tests.Infrastructure.JsonLoaderTest.pas              ← JSON settings loader
   ├─ Support/
   │  └─ Conn4D.Tests.Support.Fakes.pas                              ← fake provider, fake handles
   ├─ Conn4D.Tests.dpr
   └─ Conn4D.Tests.dproj
```

## Coverage

The current suite covers:

- **Pool registration** — `Configure.Pool(…).Apply`, duplicate names, invalid config.
- **Acquisition** — lazy creation of native handles, idle-slot reuse, `MaxPoolSize` enforcement, `AcquireTimeout` expiry → `EConn4DPoolExhaustedException`.
- **Concurrent acquisition** — multiple threads acquiring from the same pool simultaneously.
- **Sweep** — idle-timeout reclaim, unhealthy-connection detection and replacement.
- **Pool isolation** — two independently named pools do not share slots.
- **Transaction scope** — `Commit`, `Rollback` (idempotent), auto-rollback on abandon (`tsAbandoned`), `Complete` after `Rollback` raises `EConn4DTransactionException`.
- **Savepoints** — nested `BeginTransaction` on the same pool emits `SAVEPOINT`, verifies depth / `IsRoot`.
- **Spring4D bootstrap** — `TConn4DContainer.RegisterServices` resolves `IConnectionManager`.
- **Settings loaders** — `TConn4DJsonLoader` parses pool config from JSON; `TConn4DIniLoader` from INI.
- **Real Firebird integration** — `TFirebirdIntegrationTest` (skipped when env vars absent).

## Environment variables for integration tests

Set these before running the suite to enable the Firebird integration fixture:

| Variable                    | Example value                       |
| --------------------------- | ----------------------------------- |
| `CONN4D_FIREBIRD_DATABASE`  | `D:\Data\APP.FDB`                   |
| `CONN4D_FIREBIRD_HOST`      | `127.0.0.1`                         |
| `CONN4D_FIREBIRD_PORT`      | `3050`                              |
| `CONN4D_FIREBIRD_USER`      | `SYSDBA`                            |
| `CONN4D_FIREBIRD_PASSWORD`  | `masterkey`                         |

When any variable is absent, `TFirebirdIntegrationTest` skips automatically — the rest of the suite still runs.

## Running the tests

### Inside the IDE

Open `tests/Conn4D.Tests/Conn4D.Tests.dproj` in RAD Studio 12 and run (F9). The VCL form lets you tick fixtures and run subsets.

### Headless (CI-friendly)

```powershell
# Build
msbuild tests\Conn4D.Tests\Conn4D.Tests.dproj `
        /t:Build /p:Config=Debug /p:Platform=Win32 /v:minimal

# Run in console mode
tests\Conn4D.Tests\build\Win32\Debug\Conn4D.Tests.exe --console
```

Expected tail (without Firebird env vars):

```
Done testing.
Tests Found   : 30
Tests Ignored : 0
Tests Passed  : 29
Tests Skipped : 1    ← FirebirdIntegrationTest (env vars absent)
Tests Failed  : 0
Tests Errored : 0
```

Exit code is `0` on full success, `1` on any failure — usable directly from CI scripts.

### Flags

| Flag         | Effect                                                                |
| ------------ | --------------------------------------------------------------------- |
| `--console`  | Run the suite as a console process (no VCL form), prints DUnitX log. |
| `--leaks`    | Enable `ReportMemoryLeaksOnShutdown` (combine with `--console`).     |
| `--pause`    | Wait for ENTER after console output.                                  |

## Adding a new test fixture

1. Create a unit under the appropriate folder (`Application/`, `Infrastructure/`):

   ```delphi
   unit Conn4D.Tests.Application.MyFeatureTest;

   interface

   uses
     DUnitX.TestFramework;

   type
     [TestFixture]
     TMyFeatureTest = class
     public
       [Test] procedure Acquire_ReturnsValidHandle;
     end;

   implementation

   uses
     Conn4D;

   procedure TMyFeatureTest.Acquire_ReturnsValidHandle;
   var
     Handle : TConn4DHandle;
   begin
     // arrange: pool configured in test setup
     Handle := TConn4D.Acquire('test-pool');
     Assert.IsTrue(Handle.IsValid);
   end;

   initialization
     TDUnitX.RegisterTestFixture(TMyFeatureTest);

   end.
   ```

2. Add it to **both** `Conn4D.Tests.dpr` and `Conn4D.Tests.dproj` (in the `<ItemGroup>` of `DCCReference`).
3. Rebuild and run.

## Conventions

- **One assertion per behavior** — focused tests with names that read like English sentences (`Acquire_PoolExhausted_RaisesException`).
- **Use the fake provider** (`TConn4D.Tests.Support.Fakes`) for unit tests — it implements `IConn4DProvider` without FireDAC, so tests run without a database.
- **Integration tests require a live Firebird** — guard them with the env-var check pattern used in `TFirebirdIntegrationTest`.
- **Performance tests must assert relative behavior**, not absolute thresholds, so they remain stable across machines.
