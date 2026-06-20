unit uProdutosRepo;

{
  Conn4D — Exemplo: Repositório PRODUTOS

  Camada de acesso a dados sobre a interface agnóstica IConn4DNative. Demonstra o
  uso REAL do pool para CRUD + transação, sem nunca dar Free na conexão nativa (ela
  pertence ao pool/GC). Cada operação:

    1. obtém a conexão emprestada DESTA thread via FConn.Connection (lazy acquire);
    2. executa via TFDQuery (Connection := FConn.Connection, operador implícito);
    3. devolve o empréstimo ao pool com FConn.Release no finally.

  Tabela:
    PRODUTOS(CODPRODUTO, DESCRICAO, PRECO, ATIVO, CUSTO)
  ATIVO é persistido como CHAR(1) 'S'/'N' (convenção comum em bases BR/Firebird)
  e exposto como Boolean. O schema é criado/semeado de forma idempotente — roda
  tanto em SQLite (demo self-contained) quanto em Firebird/etc. já existentes.
}

interface

uses
  System.SysUtils,
  Conn4D,                    // IConn4DNative, TConnRef (acesso agnóstico à conexão)
  Conn4D.Core.Transaction;   // IConnTransaction

type
  /// <summary>Projeção de uma linha de PRODUTOS (apenas dados).</summary>
  TProduto = record
    CodProduto: Integer;
    Descricao:  string;
    Preco:      Double;
    Ativo:      Boolean;
    Custo:      Double;
  end;

  /// <summary>Repositório da tabela PRODUTOS sobre o pool Conn4D.</summary>
  TProdutosRepo = class
  private
    FConn: IConn4DNative;
    function TableExists: Boolean;
    function IsEmpty: Boolean;
    procedure Seed;
  public
    constructor Create(const AConn: IConn4DNative);

    /// <summary>Cria a tabela se não existir e semeia dados de exemplo (idempotente).</summary>
    procedure EnsureSchema;

    /// <summary>Consulta produtos; AFiltro casa por DESCRICAO (LIKE, opcional).</summary>
    function Listar(const AFiltro: string = ''): TArray<TProduto>;

    /// <summary>Lê um produto pelo código. False se não existir.</summary>
    function Obter(const ACod: Integer; out AProd: TProduto): Boolean;

    /// <summary>Altera PRECO/CUSTO/ATIVO de um produto dentro de uma transação.</summary>
    function Alterar(const ACod: Integer; const APreco, ACusto: Double;
      const AAtivo: Boolean): Boolean;

    /// <summary>
    /// Atualiza DESCRICAO+PRECO+CUSTO+ATIVO de um produto numa transação
    /// (commit/rollback). É o MESMO método chamado por várias threads no exemplo
    /// de concorrência — exercita lease por thread e UPDATE concorrente na mesma
    /// linha. Devolve True se afetou a linha; relança o erro do driver (após
    /// rollback) para a thread classificar (ex.: deadlock/update conflict).
    /// </summary>
    function AtualizarCompleto(const ACod: Integer; const ADescr: string;
      const APreco, ACusto: Double; const AAtivo: Boolean): Boolean;

    /// <summary>
    /// Executa um UPDATE de PRECO/CUSTO dentro de uma transação. Se AInjetarErro,
    /// levanta uma exceção ANTES do Commit para forçar Rollback — provando
    /// atomicidade (o valor não muda). Sem erro, confirma (Commit).
    /// </summary>
    function ExecutarTransacao(const ACod: Integer; const ANovoPreco, ANovoCusto: Double;
      const AInjetarErro: Boolean): Boolean;
  end;

implementation

uses
  System.StrUtils,       // IfThen (string)
  Conn4D.Adapter.ConnRef,  // TConnRef: inline do operador implícito p/ TFDCustomConnection
  FireDAC.Comp.Client,   // TFDQuery
  FireDAC.Stan.Param,    // TFDParam (setters de parâmetro)
  Data.DB;               // TField

constructor TProdutosRepo.Create(const AConn: IConn4DNative);
begin
  inherited Create;
  FConn := AConn;
end;

function TProdutosRepo.TableExists: Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn.Connection;
    try
      // Consulta barata; se a tabela não existe, o driver lança e tratamos como False.
      Q.Open('SELECT 1 FROM PRODUTOS WHERE 1 = 0');
      Result := True;
    except
      Result := False;
    end;
  finally
    Q.Free;
  end;
end;

function TProdutosRepo.IsEmpty: Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn.Connection;
    Q.Open('SELECT COUNT(*) AS N FROM PRODUTOS');
    Result := Q.Fields[0].AsInteger = 0;
  finally
    Q.Free;
  end;
end;

procedure TProdutosRepo.Seed;
const
  // Descrição, Preço, Ativo, Custo — códigos atribuídos pelo loop.
  SAMPLES: array[0..6] of record D: string; P, C: Double; A: Boolean; end = (
    (D: 'Caderno 96 folhas';      P: 12.90;  C: 6.10;  A: True),
    (D: 'Caneta esferográfica';   P: 2.50;   C: 0.85;  A: True),
    (D: 'Mochila escolar';        P: 149.90; C: 88.00; A: True),
    (D: 'Estojo simples';         P: 19.90;  C: 9.40;  A: False),
    (D: 'Lápis HB (caixa 12)';    P: 8.75;   C: 3.20;  A: True),
    (D: 'Borracha branca';        P: 1.90;   C: 0.55;  A: True),
    (D: 'Régua 30cm';             P: 4.30;   C: 1.75;  A: False));
var
  Q: TFDQuery;
  I: Integer;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn.Connection;
    Q.SQL.Text :=
      'INSERT INTO PRODUTOS (CODPRODUTO, DESCRICAO, PRECO, ATIVO, CUSTO) ' +
      'VALUES (:COD, :DESCR, :PRECO, :ATIVO, :CUSTO)';
    for I := Low(SAMPLES) to High(SAMPLES) do
    begin
      Q.ParamByName('COD').AsInteger     := I + 1;
      Q.ParamByName('DESCR').AsString    := SAMPLES[I].D;
      Q.ParamByName('PRECO').AsCurrency  := SAMPLES[I].P;
      Q.ParamByName('ATIVO').AsString    := IfThen(SAMPLES[I].A, 'S', 'N');
      Q.ParamByName('CUSTO').AsCurrency  := SAMPLES[I].C;
      Q.ExecSQL;
    end;
  finally
    Q.Free;
  end;
end;

procedure TProdutosRepo.EnsureSchema;
var
  Q: TFDQuery;
begin
  try
    if not TableExists then
    begin
      Q := TFDQuery.Create(nil);
      try
        Q.Connection := FConn.Connection;
        // Tipos genéricos aceitos pelos drivers usados na demo. Em bases legadas
        // a tabela já existe e este ramo nem roda.
        Q.ExecSQL(
          'CREATE TABLE PRODUTOS ('                 +
          '  CODPRODUTO INTEGER NOT NULL PRIMARY KEY,' +
          '  DESCRICAO  VARCHAR(100),'              +
          '  PRECO      NUMERIC(15,4),'             +
          '  ATIVO      CHAR(1),'                   +
          '  CUSTO      NUMERIC(15,4))');
      finally
        Q.Free;
      end;
    end;

    if IsEmpty then
      Seed;
  finally
    FConn.Release;  // devolve o empréstimo desta thread ao pool
  end;
end;

function TProdutosRepo.Listar(const AFiltro: string): TArray<TProduto>;
var
  Q: TFDQuery;
  List: TArray<TProduto>;
  N: Integer;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn.Connection;
    try
      if AFiltro.Trim = '' then
        Q.Open('SELECT CODPRODUTO, DESCRICAO, PRECO, ATIVO, CUSTO ' +
               'FROM PRODUTOS ORDER BY CODPRODUTO')
      else
      begin
        Q.SQL.Text :=
          'SELECT CODPRODUTO, DESCRICAO, PRECO, ATIVO, CUSTO ' +
          'FROM PRODUTOS WHERE UPPER(DESCRICAO) LIKE :F ORDER BY CODPRODUTO';
        Q.ParamByName('F').AsString := '%' + AFiltro.Trim.ToUpper + '%';
        Q.Open;
      end;

      SetLength(List, 0);
      N := 0;
      while not Q.Eof do
      begin
        SetLength(List, N + 1);
        List[N].CodProduto := Q.FieldByName('CODPRODUTO').AsInteger;
        List[N].Descricao  := Q.FieldByName('DESCRICAO').AsString;
        List[N].Preco      := Q.FieldByName('PRECO').AsCurrency;
        List[N].Ativo      := SameText(Q.FieldByName('ATIVO').AsString.Trim, 'S');
        List[N].Custo      := Q.FieldByName('CUSTO').AsCurrency;
        Inc(N);
        Q.Next;
      end;
      Result := List;
    finally
      FConn.Release;
    end;
  finally
    Q.Free;
  end;
end;

function TProdutosRepo.Alterar(const ACod: Integer; const APreco, ACusto: Double;
  const AAtivo: Boolean): Boolean;
var
  Tx: IConnTransaction;
  Q: TFDQuery;
  Affected: Integer;
begin
  // Transação agnóstica de engine pela fachada; commit/rollback explícitos.
  Tx := FConn.BeginTransaction;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := FConn.Connection;
      Q.SQL.Text :=
        'UPDATE PRODUTOS SET PRECO = :PRECO, CUSTO = :CUSTO, ATIVO = :ATIVO ' +
        'WHERE CODPRODUTO = :COD';
      Q.ParamByName('PRECO').AsCurrency := APreco;
      Q.ParamByName('CUSTO').AsCurrency := ACusto;
      Q.ParamByName('ATIVO').AsString   := IfThen(AAtivo, 'S', 'N');
      Q.ParamByName('COD').AsInteger    := ACod;
      Q.ExecSQL;
      Affected := Q.RowsAffected;
    finally
      Q.Free;
    end;
    Tx.Commit;
  except
    if Tx.IsActive then
      Tx.Rollback;
    raise;
  end;
  FConn.Release;
  Result := Affected > 0;
end;

function TProdutosRepo.Obter(const ACod: Integer; out AProd: TProduto): Boolean;
var
  Q: TFDQuery;
begin
  AProd := Default(TProduto);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn.Connection;
    Q.SQL.Text :=
      'SELECT CODPRODUTO, DESCRICAO, PRECO, ATIVO, CUSTO ' +
      'FROM PRODUTOS WHERE CODPRODUTO = :COD';
    Q.ParamByName('COD').AsInteger := ACod;
    Q.Open;
    Result := not Q.Eof;
    if Result then
    begin
      AProd.CodProduto := Q.FieldByName('CODPRODUTO').AsInteger;
      AProd.Descricao  := Q.FieldByName('DESCRICAO').AsString;
      AProd.Preco      := Q.FieldByName('PRECO').AsCurrency;
      AProd.Ativo      := SameText(Q.FieldByName('ATIVO').AsString.Trim, 'S');
      AProd.Custo      := Q.FieldByName('CUSTO').AsCurrency;
    end;
  finally
    Q.Free;
    FConn.Release;
  end;
end;

function TProdutosRepo.AtualizarCompleto(const ACod: Integer; const ADescr: string;
  const APreco, ACusto: Double; const AAtivo: Boolean): Boolean;
var
  Tx: IConnTransaction;
  Q: TFDQuery;
  Affected: Integer;
begin
  Tx := FConn.BeginTransaction;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := FConn.Connection;
      Q.SQL.Text :=
        'UPDATE PRODUTOS SET DESCRICAO = :DESCR, PRECO = :PRECO, ' +
        'CUSTO = :CUSTO, ATIVO = :ATIVO WHERE CODPRODUTO = :COD';
      Q.ParamByName('DESCR').AsString   := ADescr;
      Q.ParamByName('PRECO').AsCurrency := APreco;
      Q.ParamByName('CUSTO').AsCurrency := ACusto;
      Q.ParamByName('ATIVO').AsString   := IfThen(AAtivo, 'S', 'N');
      Q.ParamByName('COD').AsInteger    := ACod;
      Q.ExecSQL;
      Affected := Q.RowsAffected;
    finally
      Q.Free;
    end;
    Tx.Commit;
  except
    if Tx.IsActive then
      Tx.Rollback;
    FConn.Release;   // devolve o lease ANTES de relançar
    raise;
  end;
  FConn.Release;
  Result := Affected > 0;
end;

function TProdutosRepo.ExecutarTransacao(const ACod: Integer;
  const ANovoPreco, ANovoCusto: Double; const AInjetarErro: Boolean): Boolean;
var
  Tx: IConnTransaction;
  Q: TFDQuery;
  Affected: Integer;
begin
  Tx := FConn.BeginTransaction;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := FConn.Connection;
      Q.SQL.Text :=
        'UPDATE PRODUTOS SET PRECO = :PRECO, CUSTO = :CUSTO WHERE CODPRODUTO = :COD';
      Q.ParamByName('PRECO').AsCurrency := ANovoPreco;
      Q.ParamByName('CUSTO').AsCurrency := ANovoCusto;
      Q.ParamByName('COD').AsInteger    := ACod;
      Q.ExecSQL;
      Affected := Q.RowsAffected;
    finally
      Q.Free;
    end;

    // Falha SIMULADA depois do UPDATE e antes do Commit: o except abaixo desfaz
    // tudo (Rollback). Prova de atomicidade — o PRECO não é persistido.
    if AInjetarErro then
      raise Exception.CreateFmt(
        'Erro simulado no produto %d: forçando rollback da transação.', [ACod]);

    Tx.Commit;
  except
    if Tx.IsActive then
      Tx.Rollback;
    FConn.Release;
    raise;
  end;
  FConn.Release;
  Result := Affected > 0;
end;

end.
