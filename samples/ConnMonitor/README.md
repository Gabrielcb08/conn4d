# Conn4D — Exemplo: PRODUTOS + Monitor de Conexões

App VCL que demonstra, ponta a ponta, o uso do Conn4D sobre uma tabela de
negócio **PRODUTOS**(`CODPRODUTO`, `DESCRICAO`, `PRECO`, `ATIVO`, `CUSTO`):

| Recurso | O que faz |
|---|---|
| **Consultar** | `SELECT` em `PRODUTOS` pelo pool (lease por thread, devolvido no `finally`). Filtro opcional por descrição. |
| **Alterar** | `UPDATE` de `PRECO`/`CUSTO`/`ATIVO` do item selecionado **dentro de uma transação** (`BeginTransaction` → `Commit`/`Rollback`). |
| **Stress (N)** | Dispara N threads que pegam, seguram e **devolvem** conexões — exercita o pool. |
| **Simular Zumbi** | Uma thread adquire uma conexão e **nunca chama `Release`** (vazamento). Passado o `MaxLeaseTime`, ela vira zumbi e o **Garbage Collector a fecha sozinho**. |
| **Monitor** | A cada 500 ms lê `IConn4D.LiveConnections` + `Stats` e mostra estado, idade, tempo em uso/ocioso e um aviso quando uma conexão está prestes a ser coletada. |

## Como rodar (zero setup)

O exemplo é **self-contained com SQLite** — não precisa de servidor.

1. Abra `ConnMonitor.dproj` no Delphi (Win32) e rode (F9), **ou** compile pela
   linha de comando com o `dcc32`.
2. Se **não** houver `settings.ini`, o app usa SQLite por padrão, cria
   `produtos_demo.sqlite` ao lado do executável e **semeia** a tabela `PRODUTOS`.
3. Clique **Consultar** para listar, selecione uma linha, ajuste Preço/Custo/Ativo
   e clique **Alterar**. Clique **Simular Zumbi** e observe, no monitor de baixo,
   a conexão ficar `InUse`, receber o aviso `ZUMBI -> será coletada` e desaparecer
   sozinha após o GC rodar.

## Apontar para uma base real (Firebird, Postgres, etc.)

Copie `settings.example.ini` para `settings.ini` (na pasta `build`, não versionado)
e preencha o bloco `[Connection]`. O **mesmo código** roda contra a base
existente — `EnsureSchema` só cria/semeia a tabela se ela não existir/estiver vazia.

> A resolução do INI prefere `settings.ini` sobre `settings.example.ini`. Para
> voltar à demo SQLite, remova/renomeie `settings.ini` ou ponha `Provider=SQLite`.

## Parâmetros relevantes (`settings.example.ini`)

```ini
[Pool]
MaxLeaseTime=8000     ; ms até uma conexão InUse virar zumbi
IdleTimeout=20000     ; ms até uma conexão ociosa ser evictada
[GC]
Enabled=1
Interval=2000         ; o GC acorda a cada 2s e fecha zumbis/ociosas
```

> **Nota de arquitetura:** o garbage collector passou a ser ligado pela fachada
> (`Conn4D.Adapter.FireDAC`) quando `GCEnabled=1`. Sem isso, `GCEnabled`/
> `GCInterval` ficariam inertes e vazamentos nunca seriam recuperados em runtime.

## `uses` do FireDAC — resolvidas pela própria biblioteca (auto-link)

Você **não** precisa listar `FireDAC.VCLUI.Wait`, `FireDAC.Stan.*`, `FireDAC.DApt`
nem `FireDAC.Phys.*` na aplicação. Basta usar a fachada:

```pascal
uses
  Conn4D, Conn4D.Adapter.FireDAC,   // fachada (puxa wait-cursor VCL + drivers)
  FireDAC.Comp.Client;              // só p/ TFDQuery, se você usar consultas
```

O adapter, na sua `implementation`, inclui automaticamente
`Conn4D.Adapter.FireDAC.VCL` — bootstrap que linka o wait-cursor (GUIx) VCL, a
infraestrutura de conexão **e** os 5 drivers (`Firebird`, `SQLite`, `PostgreSQL`,
`MySQL`, `MSSQL`), cada um já resolvendo o VendorLib por plataforma.

### Opt-out (`CONN4D_NOAUTOLINK`)

Builds que devem ficar **agnósticos de UI/driver** definem o símbolo
`CONN4D_NOAUTOLINK` para desligar o auto-link:

- o **pacote runtime** `Conn4.bpl` (mantém `requires rtl, FireDAC`);
- o **runner de testes** (console, sem VCL).

Definido em `packages/Conn4D.dproj`, `tests/Conn4D.Tests.dproj` e
`scripts/build.ps1`. Apps comuns **não** definem nada e recebem tudo automático.

> Console/FMX: o bootstrap mira VCL. Para esses alvos, defina `CONN4D_NOAUTOLINK`
> e inclua manualmente `FireDAC.ConsoleUI.Wait` / `FireDAC.FMXUI.Wait` + os
> `Conn4D.Adapter.FireDAC.Provider.<X>` que usar.

### Client library (vendor lib) por plataforma

O caminho do `fbclient.dll` / `libpq.dll` / etc. vem da config, por plataforma:

```ini
[Connection]
VendorLibX86=        ; vazio => <exe>\dlls\x86\<dll>
VendorLibX64=        ; vazio => <exe>\dlls\x64\<dll>
```

Ou no código: `TConnConfig.New.Provider('Firebird').VendorLibX86('C:\FB\fbclient.dll')`.
Aceita uma **pasta** (o resolver acrescenta o nome padrão da DLL do provider) ou
o **caminho completo de um `.dll`**. Se nada for encontrado, o FireDAC cai na
busca padrão do SO.
