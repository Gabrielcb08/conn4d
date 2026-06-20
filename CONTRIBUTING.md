# Contribuindo com o Conn4D

Obrigado pelo interesse em contribuir! Este guia resume o fluxo e as regras que
mantêm a arquitetura do projeto íntegra.

## Pré-requisitos

- **Delphi 12 (Athens)**.
- [Boss](https://github.com/HashLoad/boss) para resolver dependências (`DUnitX`).
- PowerShell (os scripts de build estão em `scripts/`).

```sh
boss install        # instala dependências de desenvolvimento
```

## Fluxo de trabalho

1. Faça um _fork_ e crie um _branch_ a partir de `main`
   (`feature/...` ou `fix/...`).
2. Implemente a mudança **com testes** (DUnitX, em `tests/`).
3. Rode os testes e o verificador de arquitetura (veja abaixo).
4. Abra um _Pull Request_ descrevendo **o quê** e **por quê**.

## Regras de arquitetura (obrigatórias)

O Conn4D segue _Clean Architecture_ (Ports & Adapters). Todo PR deve respeitar a
**Regra da Dependência** — `Adapters ──► Core ──► Shared`:

- **`Core` e `Shared` NUNCA** podem dar `uses` em FireDAC, Zeos ou UniDAC
  concretos. Drivers só aparecem em `src/Adapters/`.
- Programe contra **interfaces**, nunca contra classes concretas.
- Novo engine = nova unit em `Adapters/` + auto-registro; **não** altere Core/Shared.
- Respeite a **ordem de aquisição de locks** (semáforo → pool → contexto). Quebrar
  essa ordem reintroduz risco de _deadlock_ — veja
  [docs/conn4d-spec.md](docs/conn4d-spec.md#7-modelo-de-concorrência-e-anti-deadlock).

Valide localmente:

```sh
powershell -ExecutionPolicy Bypass -File scripts/check-architecture.ps1
powershell -ExecutionPolicy Bypass -File scripts/build.ps1
```

O `check-architecture.ps1` falha se encontrar `uses` de driver no anel interno.

## Padrão de código

- Convenção de nomes: units `Conn4D.<Camada>.<Nome>`; interfaces começam com `I`,
  classes com `T`. Siga o estilo do código existente.
- Toda dependência externa é **injetada por interface** (incluindo o relógio,
  `IConnClock`, para testes determinísticos sem `Sleep`).
- Mensagens de exceção claras, derivando de `EConn4DException`.

## Testes

- Cubra a mudança com testes unitários; o engine deve ser **mockado** (sem banco
  real). Use os mocks em `tests/Mocks/`.
- Para comportamento dependente de tempo (GC, timeouts), use o relógio mockado —
  nunca `Sleep` em teste.

## Reportando bugs

Abra uma _issue_ com: versão do Delphi, engine/banco, passos para reproduzir e o
comportamento esperado vs. obtido. **Não inclua credenciais reais** em logs ou
prints. Para falhas de segurança, siga a [SECURITY.md](SECURITY.md).
