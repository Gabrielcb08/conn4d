# Conn4D

> **Gerenciamento de conexões de banco de dados para Delphi** — pool, coleta de lixo (GC) de conexões, segurança em múltiplas threads e **abstração de engine** (FireDAC, Zeos, UniDAC) sob _Clean Architecture_ e SOLID.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Delphi](https://img.shields.io/badge/Delphi-12%20Athens-E62128.svg)](https://www.embarcadero.com/products/delphi)
[![Boss](https://img.shields.io/badge/Boss-ready-2C8EBB.svg)](https://github.com/HashLoad/boss)
[![Status](https://img.shields.io/badge/status-v2.0-green.svg)](#roadmap)

Conn4D é uma biblioteca de **infraestrutura** (não de domínio): ela cuida do _ciclo de vida_ das conexões — abrir, reaproveitar, vigiar e fechar — para que a sua aplicação não precise. **Não executa SQL, não é um ORM e não tem query builder.** O foco é uma única coisa, bem feita: entregar conexões saudáveis ao seu código, com segurança, sob qualquer carga de threads.

---

## Índice

- [Para quem é isto?](#para-quem-é-isto)
- [O problema que o Conn4D resolve](#o-problema-que-o-conn4d-resolve)
- [Conceitos fundamentais](#conceitos-fundamentais)
- [Arquitetura](#arquitetura)
- [Recursos](#recursos)
- [Engines e bancos suportados](#engines-e-bancos-suportados)
- [Instalação](#instalação)
- [Início rápido](#início-rápido)
- [Configuração](#configuração)
- [Transações](#transações)
- [Monitoramento de conexões](#monitoramento-de-conexões)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Exemplo: ConnMonitor](#exemplo-connmonitor)
- [Testes](#testes)
- [Adicionando um novo engine](#adicionando-um-novo-engine)
- [Roadmap](#roadmap)
- [Segurança](#segurança)
- [Contribuindo](#contribuindo)
- [Licença](#licença)

---

## Para quem é isto?

Para quem desenvolve em **Delphi** aplicações que abrem conexões de banco com frequência — serviços REST (Horse, DataSnap, RAD Server), aplicações multithread, _workers_, jobs em background — e quer parar de gerenciar conexões "na mão".

Se você já escreveu algo como `FDConnection1.Connected := True` espalhado pelo código, esqueceu de fechar uma conexão e viu o banco recusar novos logins, ou teve _race conditions_ ao compartilhar uma conexão entre threads — o Conn4D existe para resolver exatamente esses problemas.

---

## O problema que o Conn4D resolve

Abrir uma conexão de banco é **caro** (handshake TCP, autenticação, alocação de recursos no servidor). Em uma aplicação que atende muitas requisições, abrir e fechar uma conexão por operação é lento e não escala. As armadilhas clássicas:

| Problema | Sem pool | Com Conn4D |
|---|---|---|
| **Custo de abertura** | Cada operação paga o _handshake_ completo. | Conexões são reaproveitadas de um _pool_. |
| **Vazamento de conexão** | Esqueceu de fechar? A conexão fica presa até o servidor derrubá-la. | O **GC** detecta a conexão "zumbi" e a recupera automaticamente. |
| **Conexões ociosas** | Ficam abertas consumindo recursos do servidor à toa. | O **GC** encerra conexões _idle_ após um tempo configurável. |
| **Concorrência** | Compartilhar uma conexão entre threads gera _race condition_ / corrupção. | _Thread-safety_ por design; cada thread recebe sua própria conexão emprestada. |
| **Esgotamento (DoS acidental)** | N threads abrem N conexões → o servidor recusa. | O _pool_ limita o total; excedentes aguardam em fila com _timeout_. |
| **Acoplamento ao driver** | Trocar FireDAC por outro driver = reescrever a aplicação. | Você programa contra **interfaces**; trocar o engine não toca o seu código. |

---

## Conceitos fundamentais

Quatro ideias sustentam a biblioteca:

### 1. Pool de conexões
Um **pool** é um conjunto de conexões já abertas, mantidas prontas para uso. Quando seu código pede uma conexão (`Acquire`), o pool entrega uma já existente em vez de criar do zero; quando você termina (`Release`/`ReturnToPool`), ela volta ao pool — **não é destruída**. O pool tem um tamanho máximo (`MaxSize`): pedidos além do limite **entram em uma fila** e aguardam até uma conexão liberar ou até estourar o `AcquireTimeout` (que lança `EConn4DTimeoutException`, falha controlada, nunca trava).

### 2. Garbage Collector (GC) de conexões
Diferente do GC de memória da linguagem, este coleta **conexões**. Uma _thread_ separada acorda periodicamente (`GCInterval`, padrão 30s) e:

- **Conexão ociosa (idle):** disponível há mais tempo que `IdleTimeout` → é fechada para liberar recursos.
- **Conexão zumbi (zombie):** emprestada há mais tempo que `MaxLeaseTime` (sinal de vazamento — a thread morreu ou esqueceu de liberar) → faz `Rollback` de transação aberta, registra o ocorrido com _thread id_ e horário, e destrói.

Isso torna a aplicação **autocurável**: vazamentos não derrubam o sistema; o GC os recolhe.

```
Created ──init──► Available ──acquire──► InUse ──release──► Available
                     │                      │
                idle timeout           lease timeout
                     ▼                      ▼
                   Idle                  Zombie
                     │                      │
                GC.collect             GC.forceKill
                     └──────► Destroyed ◄───┘
```

### 3. Thread-safety por design
Todo o estado mutável vive em **um único componente** (`TConnPoolStore`), protegido por seção crítica. Os _locks_ são adquiridos sempre na **mesma ordem fixa** (semáforo → pool → contexto), o que **elimina deadlock estruturalmente** — não existe ciclo de espera possível. O GC roda em thread própria e fecha sockets _fora_ do lock, minimizando contenção. Cada thread só enxerga a conexão que pegou emprestada.

### 4. Abstração de engine (Ports & Adapters)
O _engine_ é o driver que realmente fala com o banco (FireDAC, Zeos, UniDAC). No Conn4D, o engine é uma **estratégia substituível**: todo o núcleo conversa apenas com a interface `IConnEngine`. Trocar de driver é **trocar um registro**, não reescrever a aplicação. O seu código nunca nomeia o engine nem faz _cast_:

```pascal
FDQuery.Connection := Conn.Connection;   // sem cast, sem nomear a engine
```

---

## Arquitetura

Conn4D segue **Clean Architecture** (Ports & Adapters). Como é uma biblioteca de infraestrutura — sem regras de negócio — **não se aplica DDD**. A regra de ouro é a **Regra da Dependência**: camadas externas dependem das internas, nunca o contrário.

```
   Adapters  ───►  Core  ───►  Shared
      │                          ▲
      └──────────────────────────┘

  • Shared  : tipos, config, exceptions, logger. Não conhece ninguém.
  • Core    : contratos (interfaces) + algoritmos agnósticos de driver.
              NUNCA dá `uses` em FireDAC/Zeos/UniDAC.
  • Adapters: ÚNICA camada que conhece engines concretos.
```

Princípios não-negociáveis:

1. **Inversão de dependência total** — todo contrato vive no `Core`; o `Core` jamais referencia um driver concreto.
2. **Engine substituível** — trocar de engine = trocar um registro. Zero impacto fora do adapter.
3. **Thread-safety por design** — estado centralizado, ordem de lock fixa, deadlock impossível por construção.
4. **Testabilidade de primeira classe** — toda dependência é injetada por interface; o engine é 100% _mockável_ (testes rodam sem banco real).
5. **SOLID aplicado de verdade** — cada princípio com justificativa concreta (veja [docs/conn4d-spec.md](docs/conn4d-spec.md#11-mapeamento-solid-justificativa-por-princípio)).

> 📚 A especificação técnica completa está em **[docs/conn4d-spec.md](docs/conn4d-spec.md)** e o empacotamento/componente em **[docs/conn4d-packaging-spec.md](docs/conn4d-packaging-spec.md)**.

---

## Recursos

- ✅ **Pool de conexões por instância** com tamanho mínimo/máximo e fila de espera.
- ✅ **GC de conexões** — encerra ociosas e recupera zumbis (vazamentos) automaticamente.
- ✅ **Thread-safe por design** — sem _race condition_, sem _deadlock_ (ordem de lock fixa).
- ✅ **Agnóstico de engine** — FireDAC incluso; Zeos e UniDAC opcionais por diretiva.
- ✅ **Acesso à conexão nativa sem _cast_** — `operator Implicit` resolve o tipo pelo destino.
- ✅ **API fluente** para configuração (`TConnConfig.New.Provider(...).Port(...)`).
- ✅ **Componente de paleta** `TConn4D` (arraste no form) **ou** _factory_ programático.
- ✅ **Transações** com níveis de isolamento.
- ✅ **Monitoramento em tempo real** — `LiveConnections` expõe estado, idade e thread dona de cada conexão.
- ✅ **Observers** — assine eventos do ciclo de vida (criada, adquirida, liberada, despejada...).
- ✅ **Distribuição via [Boss](https://github.com/HashLoad/boss)**.

---

## Engines e bancos suportados

| Engine | Status | Como habilitar |
|---|---|---|
| **FireDAC** | ✅ Padrão (sempre compila — vem com o Delphi) | Nenhuma ação |
| **Zeos** | 🧩 Opcional | `{$DEFINE CONN4D_ZEOS}` em [src/Conn4D.inc](src/Conn4D.inc) |
| **UniDAC** | 🧩 Opcional | `{$DEFINE CONN4D_UNIDAC}` em [src/Conn4D.inc](src/Conn4D.inc) |

> Engines opcionais usam **compilação condicional**: com o define desligado, a unit compila **vazia**, então incluí-la num pacote nunca quebra a build mesmo sem a biblioteca instalada.

Provedores prontos no adapter FireDAC: **Firebird**, **PostgreSQL**, **MySQL**, **MS SQL Server** e **SQLite**.

**Requisitos:** Delphi 12 (Athens). O núcleo é Windows/cross-platform; o exemplo `ConnMonitor` é VCL (Windows).

---

## Instalação

### Via Boss (recomendado)

```sh
boss install github.com/gabrielcb08/conn4d
```

O `boss.json` declara `mainsrc` (search path) e os pacotes. O `postinstall` compila os pacotes automaticamente.

### Manual

1. Clone o repositório.
2. Em **Project ▸ Options ▸ Delphi Compiler ▸ Search path**, adicione as pastas de `src/` (`src`, `src\Shared`, `src\Core\Abstractions`, `src\Core\Services`, `src\Adapters`, `src\Adapters\FireDAC`, `src\Component`).
3. (Opcional) Para usar o **componente** na paleta, abra e instale `packages/Delphi12/dclConn4D.dproj` na IDE.
4. No seu código: `uses Conn4D;` — essa unit única reexporta tudo o que o consumidor precisa.

---

## Início rápido

A unit `Conn4D` é a **fachada pública**: um `uses Conn4D;` dá acesso ao factory/componente `TConn4D`, à config `TConnConfig` e às interfaces.

### Como factory programático

```pascal
uses Conn4D;

var
  Conn: IConn4DNative;   // interface AGNÓSTICA — não nomeia a engine
  Qry:  TFDQuery;
begin
  // Sem engine => FireDAC por padrão. Configuração fluente entregue pronta:
  Conn := TConn4D.Acquire.Configure(
    TConnConfig.New
      .Provider('Firebird')
      .Host('127.0.0.1').Port(3050)
      .Database('C:\dados\MEUBANCO.FDB')
      .UserName('SYSDBA').Password('masterkey')
      .MaxSize(10).AcquireTimeout(5000).IdleTimeout(120000)
      .GCEnabled(True).GCInterval(30000));

  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := Conn.Connection;   // SEM cast → TFDCustomConnection
    Qry.Open('SELECT * FROM PRODUTOS');
    // ... use o dataset ...
  finally
    Qry.Free;
    // NUNCA dê Free na conexão nativa: o pool e o GC cuidam disso.
  end;
end;
```

### Como componente (paleta ORData)

Arraste um `TConn4D` no _form_/_datamodule_, preencha as propriedades no _Object Inspector_ (`Provider`, `Host`, `Port`, `Database`, `PoolMaxSize`, `GCEnabled`...) e use:

```pascal
FDQuery1.Connection := Conn4D1.Connection;   // lazy: abre no primeiro uso
```

> **Lazy open:** o `Acquire` cria o gerenciador e o registra; a conexão física só abre no primeiro uso real (`.Connection`, `.BeginTransaction` ou `.Open` explícito). Isso permite encadear a configuração depois do `Acquire`.

---

## Configuração

A configuração é uma **interface** (`IConnConfig`), construída por um _builder_ fluente. É o **único lugar** com _setters_ de config.

```pascal
Cfg := TConnConfig.New
  .Provider('Firebird').Host('127.0.0.1').Port(3050)
  .Database('C:\dados\MEUBANCO.FDB').UserName('SYSDBA').Password('masterkey')
  .MinSize(1).MaxSize(10)
  .AcquireTimeout(5000)    // ms para conseguir uma conexão antes de falhar
  .MaxLeaseTime(60000)     // ms até uma conexão emprestada virar "zumbi"
  .IdleTimeout(120000)     // ms até uma conexão disponível virar "ociosa"
  .GCEnabled(True).GCInterval(30000);
```

| Parâmetro | Padrão | Significado |
|---|---|---|
| `MinSize` | 1 | Conexões mantidas no mínimo. |
| `MaxSize` | 10 | Teto de conexões simultâneas (excedentes vão para a fila). |
| `AcquireTimeout` | 5000 ms | Espera máxima por uma conexão antes de lançar timeout. |
| `MaxLeaseTime` | 60000 ms | Tempo emprestada até ser considerada zumbi (vazamento). |
| `IdleTimeout` | 120000 ms | Tempo disponível até ser considerada ociosa e fechada. |
| `GCEnabled` | True | Liga/desliga o coletor. |
| `GCInterval` | 30000 ms | De quanto em quanto tempo o GC roda. |

### Configuração por arquivo INI

O exemplo lê de um `.ini`. Por segurança, **dados reais ficam em `settings.ini` (ignorado pelo git)** e o repositório versiona apenas `settings.example.ini` com valores fictícios:

```ini
[Connection]
Provider=Firebird
Host=127.0.0.1
Port=3050
Database=C:\caminho\para\MEUBANCO.FDB
UserName=SYSDBA
Password=masterkey

[Pool]
MinSize=1
MaxSize=5
AcquireTimeout=5000
MaxLeaseTime=30000
IdleTimeout=120000

[GC]
Enabled=1
Interval=30000
```

> ⚠️ **Nunca** comite credenciais reais. Copie `settings.example.ini` para `settings.ini` e edite o local — veja [SECURITY.md](SECURITY.md).

---

## Transações

```pascal
var Tx: IConnTransaction;
begin
  Tx := Conn.BeginTransaction;   // abre a conexão física, se ainda lazy
  try
    // ... operações via Conn.Connection ...
    Tx.Commit;
  except
    Tx.Rollback;
    raise;
  end;
end;
```

Níveis de isolamento são expostos por `IConnTransaction`. Se uma conexão vazar com transação aberta, o **GC faz `Rollback` automático** ao recolhê-la.

---

## Monitoramento de conexões

O `Core` expõe uma projeção **somente-leitura** do estado do pool (snapshot sob lock curto, agnóstico de engine):

```pascal
var Leases: TArray<TConnLeaseInfo>;
begin
  Leases := Conn.LiveConnections;
  for var L in Leases do
    Writeln(Format('%s | estado=%d | thread=%d | idade=%dms | em uso=%dms',
      [GUIDToString(L.Id), Ord(L.State), L.OwnerThreadId, L.AgeMs, L.InUseForMs]));
end;
```

`TConnLeaseInfo` traz: `Id`, `EngineID`, `State`, `OwnerThreadId`, `CreatedAtMs`, `AcquiredAtMs`, `LastReleasedAtMs`, `AgeMs`, `InUseForMs`, `IdleForMs`. Veja o exemplo **ConnMonitor** abaixo, que renderiza isso em tempo real num grid.

---

## Estrutura do repositório

```
Conn4D/
├── src/
│   ├── Conn4D.pas              # fachada pública: uses Conn4D;
│   ├── Conn4D.inc              # defines dos engines opcionais
│   ├── Shared/                 # tipos, config, exceptions, logger (sem dependências)
│   ├── Core/
│   │   ├── Abstractions/       # interfaces puras (IConnEngine, IConnPool, IConnGC...)
│   │   └── Services/           # PoolManager, GarbageCollector, PoolStore, Registry...
│   ├── Adapters/               # única camada que conhece drivers
│   │   ├── FireDAC/            # engine padrão + provedores (FB, PG, MySQL, MSSQL, SQLite)
│   │   └── Zeos/  · UniDAC/    # engines opcionais (compilação condicional)
│   └── Component/              # TConn4D (componente de paleta + factory)
├── packages/Delphi12/          # Conn4D.dpk (runtime) + dclConn4D.dpk (design)
├── tests/                      # DUnitX (engine 100% mockado)
├── samples/ConnMonitor/        # app VCL de demonstração
├── scripts/                    # build/install/check-architecture (PowerShell)
├── docs/                       # especificações técnicas
└── boss.json                   # manifesto Boss
```

---

## Exemplo: ConnMonitor

Em [samples/ConnMonitor/](samples/ConnMonitor/), um app VCL demonstra o pool ao vivo: um `TStringGrid` + `TTimer` que a cada tique chama `LiveConnections` e mostra cada conexão, seu estado, a thread dona e há quanto tempo está aberta/ociosa. Botões **Abrir 1**, **Abrir N (stress)**, **Liberar** e **Shutdown** permitem ver o pool, a fila e o GC trabalhando em tempo real.

Por padrão usa **SQLite** (roda sem servidor): se `Database` ficar vazio, o app cria um `produtos_demo.sqlite` ao lado do executável. Para Firebird/Postgres, ajuste o `settings.ini` (veja `settings.example.ini`). Os _workers_ são robustos a falha de conexão — banco indisponível vira mensagem de status, não _crash_.

---

## Testes

Testes em **[DUnitX](https://github.com/VSoftTechnologies/DUnitX)**, em `tests/`, com o engine **100% mockado** (sem banco real):

- `Conn4D.Test.PoolManager` — empréstimo/devolução, limites, fila.
- `Conn4D.Test.GarbageCollector` — despejo de idle/zombie com relógio mockado (`IConnClock`).
- `Conn4D.Test.ThreadSafety` — _stress_ com N threads (N > poolSize): nunca excede o limite, nunca entrega a mesma conexão a duas threads, nunca trava.
- `Conn4D.Test.Registry`, `Conn4D.Test.EngineSwap`, `Conn4D.Test.Config`, `Conn4D.Test.Component`.

Abra `tests/Conn4D.Tests.dproj` e rode, ou use `scripts/build.ps1`.

---

## Adicionando um novo engine

Graças ao **OCP**, adicionar um engine **não toca** Core nem Shared:

1. Crie `src/Adapters/<Engine>/Conn4D.Engine.<Engine>.pas` implementando `IConnEngine`.
2. Crie o adapter/fachada (`IXxxConn4D = interface(IConn4DNative)`) e a _factory_.
3. Auto-registre na `initialization` da unit (chave = `EngineID`).
4. Adicione o `{$DEFINE CONN4D_<ENGINE>}` em `Conn4D.inc` e linke a unit na fachada.

O script `scripts/check-architecture.ps1` valida que Core/Shared continuam **sem** `uses` de driver concreto.

---

## Roadmap

- [x] Núcleo: pool, GC, thread-safety, registry, transações.
- [x] Adapter FireDAC (Firebird, PostgreSQL, MySQL, MSSQL, SQLite).
- [x] Componente de paleta + factory + monitoramento.
- [ ] Adapters Zeos e UniDAC estáveis (estrutura pronta, sob diretiva).
- [ ] Suporte cross-platform expandido nos exemplos.

---

## Segurança

Antes de tornar o repositório público, leia **[SECURITY.md](SECURITY.md)**. Pontos-chave:

- Credenciais reais ficam em `settings.ini`, **ignorado pelo git**. Só `settings.example.ini` (fictício) é versionado.
- O `.gitignore` exclui binários, caches do compilador, DLLs de terceiros e o cache do Delphi LSP (`*.delphilsp.json`), que vazaria o layout do seu disco.
- As credenciais que aparecem na documentação (`SYSDBA`/`masterkey`) são os **valores de fábrica públicos do Firebird**, usados apenas como exemplo — não são segredos reais.

---

## Contribuindo

Contribuições são bem-vindas! Veja **[CONTRIBUTING.md](CONTRIBUTING.md)** para o fluxo de trabalho, padrão de código e as regras de arquitetura que todo PR deve respeitar.

---

## Licença

Distribuído sob a licença **MIT**. Veja [LICENSE](LICENSE).
