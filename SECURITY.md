# Política de Segurança

## Reportando uma vulnerabilidade

Encontrou um problema de segurança no Conn4D? **Não abra uma _issue_ pública.**
Abra um [_security advisory_ privado](https://github.com/gabrielcb08/conn4d/security/advisories/new)
no GitHub ou entre em contato com o mantenedor. Faremos o possível para responder
em até alguns dias úteis.

---

## Boas práticas ao usar o Conn4D

O Conn4D **não armazena nem transmite** credenciais — ele apenas as repassa ao
driver no momento de abrir a conexão. A responsabilidade de proteger as
credenciais é da aplicação consumidora. Recomendações:

- **Nunca** comite credenciais reais (usuário, senha, host, caminho do banco).
- Mantenha a configuração sensível fora do código-fonte: arquivo `settings.ini`
  local (ignorado pelo git), variáveis de ambiente ou um cofre de segredos.
- Versione apenas um **`settings.example.ini`** com valores fictícios.
- Use contas de banco com **privilégio mínimo** — evite `SYSDBA`/`sa` em produção.
- Prefira conexões **criptografadas** (TLS) quando o driver/banco suportar.

> ℹ️ As credenciais `SYSDBA` / `masterkey` que aparecem na documentação e nos
> exemplos são os **valores de fábrica públicos do Firebird**, usados apenas para
> ilustração. **Não são segredos** e não devem ser usados em produção.

---

## O que NÃO deve ser versionado

O [`.gitignore`](.gitignore) já bloqueia os itens abaixo. Antes do primeiro
`git push`, confirme com `git status` que nenhum deles está sendo adicionado:

| Item | Por quê |
|---|---|
| `**/settings.ini` | Contém credenciais e caminhos reais de banco. |
| `**/*.delphilsp.json` | Cache do Delphi LSP — **vaza o layout completo do seu disco**, o usuário do Windows e caminhos de outros projetos (inclusive proprietários e componentes licenciados). |
| `*.local`, `*.dsk`, `*.identcache` | Configurações de IDE específicas da sua máquina. |
| `**/*.dll` | Binários redistribuíveis de terceiros (Firebird `fbclient.dll`, etc.). Não redistribua — o usuário baixa do fornecedor. Pode haver implicações de licença. |
| `bin/`, `**/build/`, `*.bpl`, `*.dcp`, `*.dcu`, `*.exe`, `*.lib`, `*.bpi` | Artefatos de compilação. Inúteis no repo e aumentam o tamanho. |
| `__history/`, `__recovery/` | Backups automáticos da IDE — podem conter versões antigas com dados sensíveis. |
| `.claude/settings.local.json` | Configuração local da ferramenta (caminhos absolutos da máquina). |
| `modules/`, `boss.lock` | Dependências resolvidas localmente pelo Boss. |

### Checklist antes de publicar

```sh
git status                 # nada sensível na lista?
git ls-files | grep -iE 'settings\.ini$|delphilsp|\.dll$'   # deve vir VAZIO
```

Se algum segredo já foi comitado em algum momento, **trocar a senha** é
obrigatório — remover do histórico (`git filter-repo` / BFG) não basta, pois o
dado pode já ter sido clonado.

---

## Superfície de segurança da biblioteca

- O Conn4D **não executa SQL** e não monta queries — não há, por construção,
  superfície de _SQL injection_ dentro da biblioteca. A montagem e execução de
  comandos é responsabilidade do código consumidor.
- O _pool_ impõe um **teto de conexões** (`MaxSize`) com fila e _timeout_, o que
  protege o servidor de banco contra esgotamento acidental de conexões.
- O **GC** recupera conexões vazadas, reduzindo o risco de exaustão por
  _leaks_ — incluindo `Rollback` automático de transações abandonadas.
