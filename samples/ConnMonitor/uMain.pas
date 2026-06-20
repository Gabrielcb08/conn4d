unit uMain;

{
  Conn4D — Exemplo: PRODUTOS + Monitor + Concorrência + Transações

  App VCL self-contained, organizado em ABAS (TPageControl), demonstrando o Conn4D
  sobre PRODUTOS(CODPRODUTO, DESCRICAO, PRECO, ATIVO, CUSTO):

  ABA 1 — Produtos & Monitor
    • CONSULTAR / ALTERAR (UPDATE em transação) e o MONITOR de conexões vivas
      (TTimer lê IConn4D.LiveConnections) + demo de ZUMBI coletado pelo GC.

  ABA 2 — Concorrência (deadlock)
    • N threads chamam o MESMO método (TProdutosRepo.AtualizarCompleto) atualizando
      DESCRIÇÃO e VALORES do MESMO produto ao mesmo tempo. Cada thread recebe SUA
      conexão emprestada do pool. Prova que o Conn4D NÃO entra em deadlock (ordem de
      locks): o app segue responsivo; conflitos de UPDATE do banco (deadlock/update
      conflict do Firebird) viram mensagem + rollback, nunca travam o pool.

  ABA 3 — Transações (commit/rollback)
    • Um UPDATE em transação que CONFIRMA (Commit, valor persiste) e outro que
      injeta um erro antes do Commit, forçando ROLLBACK (valor revertido) — com a
      prova antes/depois lida da própria base.

  Configuração via INI na pasta "build" (settings.ini real, não versionado, ou
  settings.example.ini). Os exemplos rodam na base configurada (ex.: Firebird).
}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.Grids, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Conn4D,
  uProdutosRepo;                // TProdutosRepo, TProduto

type
  TfrmMain = class(TForm)
    pgc: TPageControl;
    tabProdutos: TTabSheet;
    tabConc: TTabSheet;
    tabTx: TTabSheet;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    // --- Aba Produtos & Monitor ---
    pnlTop: TPanel;
    btnConsultar: TButton;
    btnAlterar: TButton;
    btnZombie: TButton;
    btnStress: TButton;
    btnShutdown: TButton;
    edtCount: TEdit;
    lblFiltro: TLabel;
    edtFiltro: TEdit;
    lblEdit: TLabel;
    lblCod: TLabel;
    edtCod: TEdit;
    lblDesc: TLabel;
    edtDesc: TEdit;
    lblPreco: TLabel;
    edtPreco: TEdit;
    lblCusto: TLabel;
    edtCusto: TEdit;
    chkAtivo: TCheckBox;
    gridProd: TStringGrid;
    Splitter: TSplitter;
    pnlMon: TPanel;
    lblMonTitle: TLabel;
    gridMon: TStringGrid;
    Timer: TTimer;
    // --- Aba Concorrência ---
    pnlTopC: TPanel;
    lblCodC: TLabel;
    edtCodC: TEdit;
    lblThreads: TLabel;
    edtThreads: TEdit;
    btnConcorrer: TButton;
    btnLimparC: TButton;
    lblHintC: TLabel;
    memoConc: TMemo;
    // --- Aba Transações ---
    pnlTopT: TPanel;
    lblCodT: TLabel;
    edtCodT: TEdit;
    btnTxCommit: TButton;
    btnTxRollback: TButton;
    btnLimparT: TButton;
    lblHintT: TLabel;
    memoTx: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnConsultarClick(Sender: TObject);
    procedure btnAlterarClick(Sender: TObject);
    procedure btnZombieClick(Sender: TObject);
    procedure btnStressClick(Sender: TObject);
    procedure btnShutdownClick(Sender: TObject);
    procedure gridProdClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure btnConcorrerClick(Sender: TObject);
    procedure btnLimparCClick(Sender: TObject);
    procedure btnTxCommitClick(Sender: TObject);
    procedure btnTxRollbackClick(Sender: TObject);
    procedure btnLimparTClick(Sender: TObject);
  private
    FConn:       IConn4DNative;
    FRepo:       TProdutosRepo;
    FProdutos:   TArray<TProduto>;
    FMaxLeaseMs: Cardinal;
    // estado do exemplo de concorrência
    FConcRunning:   Boolean;
    FConcRemaining: Integer;
    FConcCommitted: Integer;
    FConcConflict:  Integer;
    FConcError:     Integer;
    function ResolveIniPath: string;
    function LoadConfig(const AIniPath: string): IConnConfig;
    procedure SetupGrids;
    procedure Consultar;
    procedure FillEditorFromRow(const ARow: Integer);
    procedure SpawnWorker(const AHoldMs: Integer; const ALeak: Boolean);
    procedure RefreshMonitor;
    procedure SetStatus(const AText: string);
    // concorrência
    procedure SpawnConcWorker(const AIdx, ACod: Integer; const APreco, ACusto: Double);
    procedure FinishConc;
    procedure LogConc(const AText: string);   // thread-safe (marshala p/ a main)
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  System.IOUtils, System.Math, System.IniFiles, System.StrUtils, System.SyncObjs,
  Conn4D.Shared.Types,                       // TConnState/TConnLeaseInfo
  Conn4D.Adapter.ConnRef,                    // TConnRef: inline do operador implícito
  FireDAC.Comp.Client;                       // TFDQuery (acesso a dados)


function StateToStr(const AState: TConnState): string;
begin
  case AState of
    csCreated:   Result := 'Created';
    csAvailable: Result := 'Available';
    csInUse:     Result := 'InUse';
    csIdle:      Result := 'Idle';
    csZombie:    Result := 'Zombie';
    csDestroyed: Result := 'Destroyed';
  else
    Result := '?';
  end;
end;

function IsLockConflict(const AMsg: string): Boolean;
var
  M: string;
begin
  // Heurística de demo: erros típicos de concorrência (Firebird/SQLite/drivers).
  M := LowerCase(AMsg);
  Result := (Pos('deadlock', M) > 0) or (Pos('conflict', M) > 0) or
            (Pos('-913', M) > 0) or (Pos('concurrent', M) > 0) or
            (Pos('locked', M) > 0) or (Pos('lock', M) > 0);
end;

{ ---- Configuração -------------------------------------------------------- }

function TfrmMain.ResolveIniPath: string;
var
  Bases: TArray<string>;
  Dir, Base: string;
  I: Integer;
begin
  // O exe pode sair na raiz do sample, em .\build ou em .\Win32\Debug, conforme
  // a config do projeto. Montamos uma lista de pastas-candidatas (a do exe e
  // algumas pais, cada uma também com subpasta \build) e procuramos primeiro o
  // settings.ini REAL e, só depois, o settings.example.ini.
  Dir := ExtractFilePath(ParamStr(0));
  SetLength(Bases, 0);
  for I := 0 to 3 do  // exe dir + 3 níveis acima
  begin
    if Dir = '' then
      Break;
    Bases := Bases + [IncludeTrailingPathDelimiter(Dir)];
    Bases := Bases + [IncludeTrailingPathDelimiter(Dir) + 'build\'];
    Dir := ExtractFileDir(ExcludeTrailingPathDelimiter(Dir));
  end;

  for Base in Bases do                 // 1) procura o real
    if TFile.Exists(Base + 'settings.ini') then
      Exit(Base + 'settings.ini');
  for Base in Bases do                 // 2) cai no exemplo
    if TFile.Exists(Base + 'settings.example.ini') then
      Exit(Base + 'settings.example.ini');

  Result := '';
end;

function TfrmMain.LoadConfig(const AIniPath: string): IConnConfig;
var
  Ini: TIniFile;
  Provider, Database: string;
begin
  // Defaults self-contained: SQLite num arquivo ao lado do exe; GC agressivo e
  // MaxLeaseTime curto para a demo de zumbi ser visível em segundos.
  if AIniPath = '' then
  begin
    Result := TConnConfig.New
      .Provider('SQLite')
      .Database(ExtractFilePath(ParamStr(0)) + 'produtos_demo.sqlite')
      .MinSize(1).MaxSize(5)
      .AcquireTimeout(3000).MaxLeaseTime(8000).IdleTimeout(20000)
      .GCEnabled(True).GCInterval(2000)
      .Extra('BusyTimeout', '3000');
    Exit;
  end;

  Ini := TIniFile.Create(AIniPath);
  try
    Provider := Ini.ReadString('Connection', 'Provider', 'SQLite');
    Database := Ini.ReadString('Connection', 'Database', '');
    if SameText(Provider, 'SQLite') and (Database.Trim = '') then
      Database := ExtractFilePath(ParamStr(0)) + 'produtos_demo.sqlite';

    Result := TConnConfig.New
      .Provider(Provider)
      .Host(Ini.ReadString('Connection', 'Host', '127.0.0.1'))
      .Port(Ini.ReadInteger('Connection', 'Port', 3050))
      .Database(Database)
      .UserName(Ini.ReadString('Connection', 'UserName', 'SYSDBA'))
      .Password(Ini.ReadString('Connection', 'Password', 'masterkey'))
      .ConnectTimeout(Ini.ReadInteger('Connection', 'ConnectTimeout', 5000))
      .MinSize(Ini.ReadInteger('Pool', 'MinSize', 1))
      .MaxSize(Ini.ReadInteger('Pool', 'MaxSize', 5))
      .AcquireTimeout(Cardinal(Ini.ReadInteger('Pool', 'AcquireTimeout', 3000)))
      .MaxLeaseTime(Cardinal(Ini.ReadInteger('Pool', 'MaxLeaseTime', 8000)))
      .IdleTimeout(Cardinal(Ini.ReadInteger('Pool', 'IdleTimeout', 20000)))
      .GCEnabled(Ini.ReadBool('GC', 'Enabled', True))
      .GCInterval(Cardinal(Ini.ReadInteger('GC', 'Interval', 2000)))
      // Caminho da client lib (ex.: fbclient.dll) por plataforma. Vazio => o
      // resolver assume <exe>\dlls\x86 ou \dlls\x64.
      .VendorLibX86(Ini.ReadString('Connection', 'VendorLibX86', ''))
      .VendorLibX64(Ini.ReadString('Connection', 'VendorLibX64', ''));

    if SameText(Provider, 'SQLite') then
      Result := Result.Extra('BusyTimeout', '3000');
  finally
    Ini.Free;
  end;
end;

{ ---- Ciclo de vida do form ---------------------------------------------- }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  IniPath: string;
  Cfg: IConnConfig;
begin
  pgc.ActivePage := tabProdutos;

  IniPath := ResolveIniPath;
  Cfg := LoadConfig(IniPath);
  FMaxLeaseMs := Cfg.Pool.MaxLeaseTime;

  // Fachada agnóstica IConn4DNative: .Connection (TConnRef) já serve os TFDQuery.
  // Guarda a referência rica e configura (Configure devolve a porta IConn4D, que
  // descartamos — FConn segue apontando para a mesma instância já configurada).
  FConn := TConn4D.Acquire;
  FConn.Configure(Cfg);
  FRepo := TProdutosRepo.Create(FConn);

  SetupGrids;
  edtCount.Text := '5';
  edtThreads.Text := '4';
  Timer.Interval := 500;
  Timer.Enabled := True;

  try
    FRepo.EnsureSchema;
    Consultar;
    if Length(FProdutos) > 0 then
    begin
      edtCodC.Text := IntToStr(FProdutos[0].CodProduto);
      edtCodT.Text := IntToStr(FProdutos[0].CodProduto);
    end;
    SetStatus(Format('OK | %s @ %s | DB: %s | MaxLease=%d ms, GC=%d ms',
      [Cfg.Provider, IfThen(IniPath = '', '(defaults)', ExtractFileName(IniPath)),
       ExtractFileName(Cfg.Database), Cfg.Pool.MaxLeaseTime, Cfg.GC.Interval]));
  except
    on E: Exception do
      SetStatus('Falha ao preparar a base: ' + E.Message);
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  Timer.Enabled := False;
  FRepo.Free;
  if FConn <> nil then
    FConn.Shutdown;
end;

procedure TfrmMain.SetStatus(const AText: string);
begin
  lblStatus.Caption := '  ' + AText;
end;

procedure TfrmMain.SetupGrids;
begin
  // Grid de PRODUTOS
  gridProd.ColCount := 5;
  gridProd.FixedRows := 1;
  gridProd.RowCount := 2;
  gridProd.Cells[0, 0] := 'Cód';
  gridProd.Cells[1, 0] := 'Descrição';
  gridProd.Cells[2, 0] := 'Preço';
  gridProd.Cells[3, 0] := 'Ativo';
  gridProd.Cells[4, 0] := 'Custo';
  gridProd.ColWidths[0] := 50;
  gridProd.ColWidths[1] := 260;
  gridProd.ColWidths[2] := 90;
  gridProd.ColWidths[3] := 60;
  gridProd.ColWidths[4] := 90;

  // Grid do MONITOR de conexões
  gridMon.ColCount := 8;
  gridMon.FixedRows := 1;
  gridMon.RowCount := 2;
  gridMon.Cells[0, 0] := 'Id';
  gridMon.Cells[1, 0] := 'Engine';
  gridMon.Cells[2, 0] := 'Estado';
  gridMon.Cells[3, 0] := 'Thread';
  gridMon.Cells[4, 0] := 'Idade (s)';
  gridMon.Cells[5, 0] := 'Em uso (s)';
  gridMon.Cells[6, 0] := 'Ociosa (s)';
  gridMon.Cells[7, 0] := 'Aviso';
  gridMon.ColWidths[0] := 90;
  gridMon.ColWidths[1] := 70;
  gridMon.ColWidths[2] := 80;
  gridMon.ColWidths[3] := 70;
  gridMon.ColWidths[4] := 70;
  gridMon.ColWidths[5] := 80;
  gridMon.ColWidths[6] := 80;
  gridMon.ColWidths[7] := 160;
end;

{ ---- CONSULTAR / ALTERAR ------------------------------------------------- }

procedure TfrmMain.Consultar;
var
  I: Integer;
  P: TProduto;
begin
  FProdutos := FRepo.Listar(edtFiltro.Text);
  gridProd.RowCount := Max(2, Length(FProdutos) + 1);
  if Length(FProdutos) = 0 then
  begin
    for I := 0 to gridProd.ColCount - 1 do
      gridProd.Cells[I, 1] := '';
    Exit;
  end;
  for I := 0 to High(FProdutos) do
  begin
    P := FProdutos[I];
    gridProd.Cells[0, I + 1] := IntToStr(P.CodProduto);
    gridProd.Cells[1, I + 1] := P.Descricao;
    gridProd.Cells[2, I + 1] := FormatFloat('0.00', P.Preco);
    gridProd.Cells[3, I + 1] := IfThen(P.Ativo, 'Sim', 'Não');
    gridProd.Cells[4, I + 1] := FormatFloat('0.00', P.Custo);
  end;
  FillEditorFromRow(gridProd.Row);
end;

procedure TfrmMain.btnConsultarClick(Sender: TObject);
begin
  try
    Consultar;
    SetStatus(Format('Consulta OK: %d produto(s).', [Length(FProdutos)]));
  except
    on E: Exception do
      SetStatus('Erro na consulta: ' + E.Message);
  end;
end;

procedure TfrmMain.FillEditorFromRow(const ARow: Integer);
var
  Idx: Integer;
begin
  Idx := ARow - 1;  // linha 0 é o cabeçalho
  if (Idx < 0) or (Idx > High(FProdutos)) then
    Exit;
  edtCod.Text   := IntToStr(FProdutos[Idx].CodProduto);
  edtDesc.Text  := FProdutos[Idx].Descricao;
  edtPreco.Text := FormatFloat('0.00', FProdutos[Idx].Preco);
  edtCusto.Text := FormatFloat('0.00', FProdutos[Idx].Custo);
  chkAtivo.Checked := FProdutos[Idx].Ativo;
end;

procedure TfrmMain.gridProdClick(Sender: TObject);
begin
  FillEditorFromRow(gridProd.Row);
end;

procedure TfrmMain.btnAlterarClick(Sender: TObject);
var
  Cod: Integer;
  Preco, Custo: Double;
begin
  Cod := StrToIntDef(edtCod.Text, 0);
  if Cod = 0 then
  begin
    SetStatus('Selecione um produto na grade antes de alterar.');
    Exit;
  end;
  Preco := StrToFloatDef(edtPreco.Text, -1);
  Custo := StrToFloatDef(edtCusto.Text, -1);
  if (Preco < 0) or (Custo < 0) then
  begin
    SetStatus('Preço/Custo inválidos.');
    Exit;
  end;
  try
    if FRepo.Alterar(Cod, Preco, Custo, chkAtivo.Checked) then
    begin
      Consultar;
      SetStatus(Format('Produto %d alterado (transação confirmada).', [Cod]));
    end
    else
      SetStatus(Format('Produto %d não encontrado.', [Cod]));
  except
    on E: Exception do
      SetStatus('Erro ao alterar (rollback): ' + E.Message);
  end;
end;

{ ---- MONITOR / WORKERS / ZUMBI ------------------------------------------ }

procedure TfrmMain.SpawnWorker(const AHoldMs: Integer; const ALeak: Boolean);
begin
  // Worker normal: adquire, segura, DEVOLVE (Release).
  // Worker zumbi (ALeak): adquire, usa e some sem Release -> conexão fica InUse
  //   órfã; o GC a reclama sozinho passado o MaxLeaseTime.
  TThread.CreateAnonymousThread(
    procedure
    var
      Q: TFDQuery;
      Msg: string;
    begin
      try
        FConn.Open;  // acquire + open vinculado a ESTA thread

        // Prova que a conexão é real: uma consulta barata em PRODUTOS.
        Q := TFDQuery.Create(nil);
        try
          Q.Connection := FConn.Connection;
          Q.Open('SELECT COUNT(*) FROM PRODUTOS');
        finally
          Q.Free;
        end;

        Sleep(AHoldMs);

        if not ALeak then
          FConn.Release   // devolução normal ao pool
        else
          // VAZAMENTO PROPOSITAL: nada de Release. A thread termina e a conexão
          // continua marcada InUse; o GarbageCollector vai matá-la sozinho.
          ;
      except
        on E: Exception do
        begin
          Msg := E.Message;
          if not ALeak then
            FConn.Release;
          TThread.Queue(nil,
            procedure
            begin
              SetStatus('Worker: ' + Msg);
            end);
        end;
      end;
    end).Start;
end;

procedure TfrmMain.btnStressClick(Sender: TObject);
var
  N, I: Integer;
begin
  N := StrToIntDef(edtCount.Text, 5);
  for I := 1 to N do
    SpawnWorker(1500 + Random(4000), False {devolve normalmente});
  SetStatus(Format('Disparados %d workers saudáveis (pool limita as ativas).', [N]));
end;

procedure TfrmMain.btnZombieClick(Sender: TObject);
begin
  // Segura MUITO além do MaxLeaseTime e NUNCA devolve: vira zumbi e o GC fecha.
  SpawnWorker(60000, True {vaza de propósito});
  SetStatus(Format('Conexão zumbi criada. O GC vai fechá-la sozinho ' +
    'após ~%d ms (MaxLeaseTime) — observe o monitor abaixo.', [FMaxLeaseMs]));
end;

procedure TfrmMain.btnShutdownClick(Sender: TObject);
begin
  FConn.Shutdown;
  SetStatus('Pool encerrado (Shutdown). GC parado e conexões drenadas.');
end;

procedure TfrmMain.RefreshMonitor;
var
  Leases: TArray<TConnLeaseInfo>;
  I: Integer;
  L: TConnLeaseInfo;
  Active, Idle: Integer;
  Aviso: string;
  St: TConnPoolStats;
begin
  Leases := FConn.LiveConnections;
  gridMon.RowCount := Max(2, Length(Leases) + 1);
  if Length(Leases) = 0 then
    for I := 0 to gridMon.ColCount - 1 do
      gridMon.Cells[I, 1] := '';

  Active := 0;
  Idle := 0;
  for I := 0 to High(Leases) do
  begin
    L := Leases[I];
    if L.State = csInUse then Inc(Active);
    if L.State = csAvailable then Inc(Idle);

    Aviso := '';
    // O store mantém InUse até o GC reclamar; sinalizamos o "prestes a virar
    // zumbi" comparando o tempo de uso com o MaxLeaseTime configurado.
    if (L.State = csInUse) and (L.InUseForMs > Int64(FMaxLeaseMs)) then
      Aviso := 'ZUMBI -> será coletada';

    gridMon.Cells[0, I + 1] := Copy(GUIDToString(L.Id), 2, 8);
    gridMon.Cells[1, I + 1] := L.EngineID;
    gridMon.Cells[2, I + 1] := StateToStr(L.State);
    gridMon.Cells[3, I + 1] := IntToStr(L.OwnerThreadId);
    gridMon.Cells[4, I + 1] := FormatFloat('0.0', L.AgeMs / 1000);
    gridMon.Cells[5, I + 1] := FormatFloat('0.0', L.InUseForMs / 1000);
    gridMon.Cells[6, I + 1] := FormatFloat('0.0', L.IdleForMs / 1000);
    gridMon.Cells[7, I + 1] := Aviso;
  end;

  St := FConn.Stats;
  SetStatus(Format(
    'Conexões vivas: %d (ativas: %d, ociosas: %d) | Pool %s: total=%d/%d, ' +
    'criadas=%d, evictadas=%d',
    [Length(Leases), Active, Idle, St.EngineID, St.Total, St.MaxSize,
     St.CreatedTotal, St.EvictedTotal]));
end;

procedure TfrmMain.TimerTimer(Sender: TObject);
begin
  if FConn <> nil then
    RefreshMonitor;
end;

{ ---- ABA 2: CONCORRÊNCIA (deadlock) ------------------------------------- }

procedure TfrmMain.LogConc(const AText: string);
begin
  // Chamado de QUALQUER thread: marshala para a main para tocar a VCL com segurança.
  TThread.Queue(nil,
    procedure
    begin
      memoConc.Lines.Add(AText);
    end);
end;

procedure TfrmMain.SpawnConcWorker(const AIdx, ACod: Integer;
  const APreco, ACusto: Double);
begin
  // Cada thread chama o MESMO método do repo. Os parâmetros são capturados por
  // valor (uma chamada por worker), então AIdx/ACod/APreco/ACusto são estáveis.
  TThread.CreateAnonymousThread(
    procedure
    var
      Tid: Cardinal;
      Descr: string;
    begin
      Tid := GetCurrentThreadId;
      Descr := Format('Conc t%d (thr %d) %s',
        [AIdx, Tid, FormatDateTime('hh:nn:ss.zzz', Now)]);
      try
        FRepo.AtualizarCompleto(ACod, Descr, APreco, ACusto, True {Ativo});
        TInterlocked.Increment(FConcCommitted);
        LogConc(Format('t%d (thr %d): COMMIT ok (preco=%.2f)', [AIdx, Tid, APreco]));
      except
        on E: Exception do
          if IsLockConflict(E.Message) then
          begin
            TInterlocked.Increment(FConcConflict);
            LogConc(Format('t%d (thr %d): CONFLITO/deadlock do banco -> rollback: %s',
              [AIdx, Tid, E.Message]));
          end
          else
          begin
            TInterlocked.Increment(FConcError);
            LogConc(Format('t%d (thr %d): ERRO -> rollback: %s', [AIdx, Tid, E.Message]));
          end;
      end;
      // Última thread a terminar fecha o cenário (na main thread).
      if TInterlocked.Decrement(FConcRemaining) = 0 then
        TThread.Queue(nil, procedure begin FinishConc end);
    end).Start;
end;

procedure TfrmMain.FinishConc;
begin
  FConcRunning := False;
  btnConcorrer.Enabled := True;
  memoConc.Lines.Add(Format(
    '--- FIM: %d commit, %d conflito(s)/deadlock do banco, %d erro(s). ' +
    'Conn4D NÃO entrou em deadlock (app respondeu o tempo todo). ---',
    [FConcCommitted, FConcConflict, FConcError]));
  Consultar;  // mostra o estado final do produto na aba 1
end;

procedure TfrmMain.btnConcorrerClick(Sender: TObject);
var
  Cod, N, I: Integer;
  Base: TProduto;
begin
  if FConcRunning then
  begin
    SetStatus('Concorrência já em execução — aguarde terminar.');
    Exit;
  end;
  Cod := StrToIntDef(edtCodC.Text, 0);
  N := StrToIntDef(edtThreads.Text, 4);
  if (Cod = 0) or (N <= 0) then
  begin
    SetStatus('Informe um Cod e um nº de threads válidos.');
    Exit;
  end;
  try
    if not FRepo.Obter(Cod, Base) then
    begin
      SetStatus(Format('Produto %d não existe.', [Cod]));
      Exit;
    end;
  except
    on E: Exception do
    begin
      SetStatus('Falha ao ler o produto: ' + E.Message);
      Exit;
    end;
  end;

  FConcRunning   := True;
  btnConcorrer.Enabled := False;
  FConcCommitted := 0;
  FConcConflict  := 0;
  FConcError     := 0;
  FConcRemaining := N;

  memoConc.Lines.Add('');
  memoConc.Lines.Add(Format(
    '== %d threads atualizando AO MESMO TEMPO o produto %d ' +
    '(descrição + preço + custo). Mesmo código, lease por thread. ==', [N, Cod]));
  if N > Integer(FConn.Stats.MaxSize) then
    memoConc.Lines.Add(Format(
      '   (dica: nº de threads (%d) > pool MaxSize (%d): algumas vão esperar ' +
      'AcquireTimeout — é esperado.)', [N, FConn.Stats.MaxSize]));

  for I := 1 to N do
    SpawnConcWorker(I, Cod, Base.Preco + I, Base.Custo + I);

  SetStatus(Format('Concorrência: %d threads no produto %d. Veja o log da aba.', [N, Cod]));
end;

procedure TfrmMain.btnLimparCClick(Sender: TObject);
begin
  memoConc.Clear;
end;

{ ---- ABA 3: TRANSAÇÕES (commit/rollback) -------------------------------- }

procedure TfrmMain.btnTxCommitClick(Sender: TObject);
var
  Cod: Integer;
  Antes, Depois: TProduto;
  NovoPreco, NovoCusto: Double;
begin
  Cod := StrToIntDef(edtCodT.Text, 0);
  if (Cod = 0) or (not FRepo.Obter(Cod, Antes)) then
  begin
    SetStatus(Format('Produto %s inválido.', [edtCodT.Text]));
    Exit;
  end;
  NovoPreco := Antes.Preco + 1;
  NovoCusto := Antes.Custo + 1;
  try
    FRepo.ExecutarTransacao(Cod, NovoPreco, NovoCusto, False {sem erro -> Commit});
    FRepo.Obter(Cod, Depois);
    memoTx.Lines.Add(Format(
      'COMMIT   cod=%d | antes=%.2f -> commit=%.2f | depois=%.2f  %s',
      [Cod, Antes.Preco, NovoPreco, Depois.Preco,
       IfThen(SameValue(Depois.Preco, NovoPreco), '(persistido OK)', '(INESPERADO)')]));
    Consultar;
    SetStatus(Format('Transação confirmada no produto %d.', [Cod]));
  except
    on E: Exception do
      memoTx.Lines.Add('Falha inesperada no commit: ' + E.Message);
  end;
end;

procedure TfrmMain.btnTxRollbackClick(Sender: TObject);
var
  Cod: Integer;
  Antes, Depois: TProduto;
  NovoPreco, NovoCusto: Double;
begin
  Cod := StrToIntDef(edtCodT.Text, 0);
  if (Cod = 0) or (not FRepo.Obter(Cod, Antes)) then
  begin
    SetStatus(Format('Produto %s inválido.', [edtCodT.Text]));
    Exit;
  end;
  NovoPreco := Antes.Preco + 99;
  NovoCusto := Antes.Custo + 99;
  try
    FRepo.ExecutarTransacao(Cod, NovoPreco, NovoCusto, True {injeta erro -> Rollback});
    memoTx.Lines.Add('INESPERADO: a transação deveria ter falhado e dado rollback.');
  except
    on E: Exception do
    begin
      FRepo.Obter(Cod, Depois);
      memoTx.Lines.Add(Format(
        'ROLLBACK cod=%d | antes=%.2f, tentou=%.2f -> ERRO: %s | depois=%.2f  %s',
        [Cod, Antes.Preco, NovoPreco, E.Message, Depois.Preco,
         IfThen(SameValue(Depois.Preco, Antes.Preco), '(revertido OK)', '(INESPERADO)')]));
      Consultar;
      SetStatus(Format('Rollback no produto %d: valor preservado.', [Cod]));
    end;
  end;
end;

procedure TfrmMain.btnLimparTClick(Sender: TObject);
begin
  memoTx.Clear;
end;

end.
