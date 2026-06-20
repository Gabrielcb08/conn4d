# Conn4D — Especificação de Empacotamento, Componente e Monitoramento

> Complemento da `conn4d-spec.md`. Cobre: distribuição via Boss, pacotes
> runtime/design, componente visual na paleta **ORData**, engines opcionais por
> diretiva de compilação e a API de monitoramento de conexões usada pelo
> exemplo. Mantém as mesmas regras de camadas e SOLID da spec principal.

Versão: 1.0 · Stack: Delphi 12 (Athens) · Status: congelado

---

## 1. Engines opcionais por diretiva (`Conn4D.inc`)

O compilador Delphi **não** consegue detectar, sozinho, se ZeosLib/UniDAC
estão instalados na IDE. A solução robusta é **opt-in por define**, com guarda
interna que faz a unit compilar **vazia** quando o engine não está habilitado —
assim incluí-la num pacote **nunca** quebra a compilação.

Arquivo `src/Conn4D.inc`:

```pascal
{ Ative SOMENTE o engine cuja biblioteca esteja instalada na IDE. }
{.$DEFINE CONN4D_ZEOS}       // ZeosLib
{.$DEFINE CONN4D_UNIDAC}     // Devart UniDAC
```

Cada unit de engine opcional segue o padrão:

```pascal
unit Conn4D.Engine.Zeos;
{$I Conn4D.inc}
interface
{$IFDEF CONN4D_ZEOS}
uses ZConnection, ...;
type TZeosEngine = class(...) ... end;
{$ENDIF}
implementation
{$IFDEF CONN4D_ZEOS}
...
{$ENDIF}
end.
```

Regra: FireDAC é o engine padrão e **sempre** compila (vem com o Delphi). Zeos
e UniDAC só entram no binário quando o define correspondente é ligado.
Para ligar: remover o ponto do define em `Conn4D.inc` **ou** adicionar o símbolo
em *Project ▸ Options ▸ Conditional defines* do pacote.

---

## 2. Pacotes (em `packages/`, fora de `src/`)

Dois pacotes, padrão Delphi (runtime separado de design — exigência da IDE para
componentes instaláveis):

| Pacote | Arquivo | Papel | Requires |
|---|---|---|---|
| Runtime | `Conn4D.dpk` | Código da biblioteca (Shared+Core+Adapters+Componente). Linkável em apps. | `rtl`, `FireDAC` |
| Design | `dclConn4D.dpk` | Só registro na paleta + ícone. Instalado na IDE. | `designide`, `Conn4D` |

- O **design** depende do **runtime** (nunca o contrário).
- O design contém apenas `Conn4D.Register.pas` + o recurso de ícone `.dcr`.
- Nomes de saída: `Conn4D.bpl` / `dclConn4D.bpl` (units da lib seguem `Conn4D.*`).

---

## 3. Componente público — `TConn4D` (paleta ORData)

`TConn4D` (`src/Component/Conn4D.Component.pas`; fachada pública em `src/Conn4D.pas`) é o ponto de entrada público — **factory
programático** e **componente não-visual** ao mesmo tempo. O FireDAC é a engine
interna **padrão**.

### 3.1 Factory programático (class methods estáticos)

```pascal
Conn := TConn4D.Acquire;             // sem engine => FireDAC por default
Conn := TConn4D.Acquire(enZeos);     // outra engine (se habilitada em Conn4D.inc)

// Configuração fluente no TConnConfig; a fachada recebe pronta via Configure:
Conn := TConn4D.Acquire.Configure(
  TConnConfig.New.Provider('Firebird').Port(3050).Database('D:\dados\MEUBANCO.FDB'));
```

Devolve a interface **agnóstica** `IConn4DNative` (a engine fica escondida). O
acesso à conexão nativa é **sem cast** e sem nomear a engine — `Connection` devolve
o handle `TConnRef`, cujos operadores implícitos resolvem pelo destino:

```pascal
FDQuery.Connection := Conn.Connection;   // Conn: IConn4DNative — sem cast
```

### 3.2 Componente de paleta (arrastado no form/datamodule)

```pascal
TConn4D = class(TComponent)
  published
    property Engine: TConn4DEngine default enFireDAC;
    property Provider; Host; Port; Database; UserName; Password; ConnectTimeout;
    property PoolMinSize; PoolMaxSize; AcquireTimeout; MaxLeaseTime; IdleTimeout;
    property GCEnabled; GCInterval;
  public
    class function Acquire: IConn4DNative; overload; static;            // FireDAC default
    class function Acquire(const AEngine: TConn4DEngine): IConn4DNative; overload; static;
    function  Conn: IConn4DNative;                 // acessor lazy (modo componente)
    function  Connection: TConnRef;                // conexão nativa (sem cast)
    function  BeginTransaction: IConnTransaction;
    procedure ReleaseConnection;
    procedure Shutdown;
    function  LiveConnections: TArray<TConnLeaseInfo>;
end;
```

`TConn4DEngine = (enFireDAC, enZeos, enUniDAC)` é só **açúcar do Object Inspector**
(dropdown); a seleção real resolve por **registro** (ver abaixo). Selecionar uma
engine sem o define correspondente (Conn4D.inc) lança `EConn4DConfigException`.

Regras de arquitetura (Arquitetura Limpa — Regra da Dependência):
- `IConn4D` é a **porta pura** e vive em `Conn4D.Core` (Core sem engine, sem o
  seam). O acesso à conexão nativa NÃO mora nela (ISP).
- O **seam de fronteira** `Conn4D.Adapter.ConnRef` (anel de Interface Adapters)
  define o record `TConnRef` (operadores implícitos por engine) e a interface
  **agnóstica** `IConn4DNative = interface(IConn4D)` que acrescenta `Connection`.
  As fachadas `IFDConn4D`/`IZConn4D`/`IUniConn4D` **estendem** `IConn4DNative`.
- **OCP por registro** (`Conn4D.Adapter.Engines`): cada adapter se auto-registra na
  `initialization`, associando seu `EngineID` a uma fábrica `IConn4DNative`. O
  componente **resolve** pela chave — sem `case`, sem `uses` de adapter. Adicionar
  uma engine é adicionar uma unit; o componente fica intocado. A chave é o
  `EngineID` que a engine já declara — **API pública do componente segue tipada**
  (enum), nunca string.
- O umbrella `Conn4D` é a camada de composição: **linka** os adapters (Zeos/UniDAC
  sob IFDEF) para que se auto-registrem. Core/Shared permanecem sem engine —
  invariante verificada por `scripts/check-architecture.ps1`.
- As propriedades publicadas só montam um `TConnConfig`; a fachada nasce lazy no
  primeiro uso (spec §6).

Ícone: bitmap 24×24 num recurso `.dcr` cujo nome bate com a classe em maiúsculas
(`TCONN4D`), linkado no pacote de design via `{$R *.dcr}`.

---

## 4. API de monitoramento (Core, agnóstica de engine)

Para o exemplo mapear "conexões e há quanto tempo estão abertas", o Core expõe
uma projeção **somente-leitura** do estado do pool. Nada de novo acoplamento:
é um snapshot do `TConnPoolStore`, com idades calculadas pelo `IConnClock` já
injetado.

`TConnLeaseInfo` (em `Conn4D.Shared.Types`):

```pascal
TConnLeaseInfo = record
  Id:               TGUID;
  EngineID:         string;
  State:            TConnState;
  OwnerThreadId:    NativeUInt;
  CreatedAtMs:      Int64;
  AcquiredAtMs:     Int64;
  LastReleasedAtMs: Int64;
  AgeMs:            Int64;   // Now - CreatedAt (tempo de vida total)
  InUseForMs:       Int64;   // se InUse: Now - AcquiredAt; senão 0
  IdleForMs:        Int64;   // se Available: Now - LastReleasedAt; senão 0
end;
```

`IConnMonitor` (em `Conn4D.Core.Monitor`, ISP — interface pequena e focada):

```pascal
IConnMonitor = interface
  function LiveConnections: TArray<TConnLeaseInfo>;
end;
```

- `TConnPoolManager` implementa `IConnMonitor` (além de `IConnPool`/`IConn4DBase`).
- `TConnPoolStore.SnapshotLeases(NowMs)` produz o array sob lock curto.
- A fachada `TFDConn4DImpl` e o componente delegam via `Supports`.

---

## 5. Distribuição via Boss

`boss.json` na raiz declara `mainsrc` (search path do consumidor) e os
`projects` (pacotes compilados/instalados por `boss install`).

```json
{
  "name": "gabrielcb08/conn4d",
  "description": "Connection pool, GC e multi-thread safety para Delphi (Clean Arch).",
  "version": "1.0.0",
  "homepage": "https://github.com/gabrielcb08/conn4d",
  "mainsrc": "src",
  "projects": [
    "packages/Conn4D.dproj",
    "packages/dclConn4D.dproj"
  ],
  "dependencies": {}
}
```

Scripts (em `scripts/`, na raiz):
- `build.ps1` — compila os dois pacotes via `dcc32` (CI/linha de comando).
- `install.ps1` — compila e registra o `dclConn4D.bpl` na IDE (chave de registro
  `Known Packages`).

---

## 6. Exemplo — Monitor de conexões

App VCL (`samples/ConnMonitor/`): formulário com `TStringGrid` + `TTimer`. Usa
`TConn4D.Acquire` (FireDAC por default) conectando a um **Firebird**. As
configurações vêm de um INI na pasta `build/`:

- `settings.ini` — dados **reais**, local, **não** versionado (`.gitignore`).
- `settings.example.ini` — exemplo **fictício**, **versionado** no git.

O app procura `settings.ini` (ao lado do exe ou em `build\`) e, se não achar, cai
no `settings.example.ini`. Abre/empresta conexões em múltiplas threads e, a cada
tick do timer, chama `LiveConnections` para preencher o grid com:

| Coluna | Origem |
|---|---|
| Id | `TConnLeaseInfo.Id` |
| Engine | `EngineID` |
| Estado | `State` |
| Thread | `OwnerThreadId` |
| Idade (s) | `AgeMs / 1000` |
| Em uso (s) | `InUseForMs / 1000` |
| Ociosa (s) | `IdleForMs / 1000` |

Botões: *Abrir 1*, *Abrir N (stress)*, *Liberar*, *Shutdown*. Demonstra pool,
lease por thread e monitoramento em tempo real — tudo sem violar a arquitetura.
Workers são robustos a falha de conexão (Firebird indisponível vira mensagem de
status, não crash).

---

## 7. Critérios de aceitação (deste complemento)

- [ ] Incluir as units Zeos/UniDAC no pacote runtime **sem** os defines
      compila sem erro (units vazias).
- [ ] `Conn4D.Runtime.dpk` compila só com `rtl` + `FireDAC`.
- [ ] `Conn4D.Design.dpk` registra `TFDConn4DConnection` na paleta **ORData** com
      ícone.
- [ ] `boss install` resolve `mainsrc` e os pacotes.
- [ ] O exemplo lista conexões vivas e o tempo aberto, atualizando em tempo real.
- [ ] Core e Shared continuam **sem** `uses` de engine concreto (a API de
      monitoramento é agnóstica).
