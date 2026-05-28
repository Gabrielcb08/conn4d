<div align="center">

# Conn4D

**Biblioteca de gerenciamento de conexões para Delphi 12** — pools nomeados, handles RAII, escopos transacionais com savepoints aninhados, varredura em segundo plano e adaptador FireDAC incluído.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Delphi 12](https://img.shields.io/badge/Delphi-12%20Athens-red.svg)](https://www.embarcadero.com/products/delphi)
[![Boss](https://img.shields.io/badge/Boss-package-orange.svg)](https://github.com/HashLoad/boss)
[![Version](https://img.shields.io/badge/version-0.3.0--alpha.1-green.svg)](CHANGELOG.md)

[English](README.md) · [Português (BR)](README.pt-BR.md)

</div>

---

> **Nota:** Esta é a versão resumida em português. A documentação completa está em inglês — [README.md](README.md) e [docs/](docs/).

## Sumário

- [O que é](#o-que-é)
- [Por que usar](#por-que-usar)
- [Instalação](#instalação)
- [Início Rápido](#início-rápido)
- [Documentação Completa](#documentação-completa)
- [Licença](#licença)

---

## O que é

Conn4D é uma **biblioteca de gerenciamento de conexões** — ela não executa SQL, não mapeia resultados e não é um ORM. O que ela faz:

- Registra **pools nomeados** com criação preguiçosa e reuso de conexões ociosas.
- Expõe conexões como **`TConn4DHandle`** (RAII record) — a conexão é devolvida ao pool quando o handle sai de escopo.
- Expõe transações como **`TConn4DTransaction`** (RAII record) — rollback automático se `Commit` não for chamado.
- Suporta **savepoints aninhados**: múltiplos `BeginTransaction` na mesma `(thread, pool)` emitem `SAVEPOINT`, sem consumir slot extra do pool.
- Executa uma **thread de varredura** em segundo plano para reclamar conexões ociosas ou não saudáveis.

Execute SQL contra a conexão/transação usando seu próprio `TFDQuery`.

## Por que usar

| Problema | Solução do Conn4D |
|----------|-------------------|
| Abrir/fechar conexão manualmente a cada operação | `TConn4D.Acquire` devolve ao pool no destrutor do handle |
| Rollback esquecido em exceção | `TConn4DTransaction` faz rollback automático se `Commit` não for chamado |
| `TFDConnection` global compartilhada em multithread | Pool isolado por nome, slots independentes por thread |
| Código acoplado ao FireDAC | Contratos provider-neutral — o adaptador FireDAC é plug-in |

## Instalação

```bash
boss install https://github.com/gabrielcb08/conn4d@v0.3.0-alpha.1
```

Dependência de runtime: **FireDAC** (incluso no Delphi 12).  
O Spring4D é opcional — necessário apenas se usar `TConn4DContainer` para bootstrap via IoC.

## Início Rápido

### Registrar um pool

```delphi
uses
  Conn4D;

TConn4D.Configure
  .Pool('default')
    .Host('127.0.0.1')
    .Port(3050)
    .Database('C:\Dados\APP.FDB')
    .UserName('SYSDBA')
    .Password('masterkey')
    .DriverID('FB')
    .MaxPoolSize(10)
    .AcquireTimeout(5000)
  .Apply;
```

### Adquirir conexão (sem transação)

```delphi
var
  Handle : TConn4DHandle;
  Query  : TFDQuery;
begin
  Handle := TConn4D.Acquire('default');

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Handle;              // operador implícito TFDConnection
    Query.SQL.Text := 'SELECT * FROM PRODUTOS WHERE ATIVO = 1';
    Query.Open;
  finally
    Query.Free;
  end;
end;
```

### Escopo transacional

```delphi
var
  Handle : TConn4DHandle;
  Tx     : TConn4DTransaction;
  Query  : TFDQuery;
begin
  Handle := TConn4D.Acquire('default');
  Tx     := Handle.BeginTransaction;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection  := Handle;             // operador implícito
    Query.Transaction := Tx;                // operador implícito TFDTransaction
    Query.SQL.Text    := 'UPDATE PRODUTOS SET DESCRICAO = :d WHERE ID = :id';
    Query.ParamByName('d').AsString  := 'Novo nome';
    Query.ParamByName('id').AsInteger := 42;
    Query.ExecSQL;
  finally
    Query.Free;
  end;

  Tx.Commit;
end;
```

> Se `Commit` não for chamado (exceção, saída de escopo), a transação é desfeita automaticamente.

### Escopo assíncrono

```delphi
TConn4D.BeginScopeAsync('default',
  procedure(const AScope: IConn4DTransactionScope)
  begin
    // ... usar AScope.Connection / AScope.Transaction ...
    AScope.Complete;
  end);
```

## Documentação Completa

| Documento | Conteúdo |
|-----------|----------|
| [README.md](README.md) | Guia completo em inglês |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Camadas, componentes, fluxos de aquisição e transação |
| [docs/TESTING.md](docs/TESTING.md) | DUnitX, variáveis de ambiente, como executar |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Padrões de código, checklist de PR |
| [docs/BOSS.md](docs/BOSS.md) | Instalação via Boss, workflow de release |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | Histórico de versões |

Exemplos executáveis em [samples/BasicUsage](samples/BasicUsage) e [samples/AdvancedUsage](samples/AdvancedUsage).

---

## Licença

Distribuído sob a [Licença MIT](LICENSE) — uso livre para projetos comerciais e pessoais.
