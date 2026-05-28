unit Conn4D.Tests.UI.MainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.ImgList,
  DUnitX.TestFramework,
  DUnitX.Extensibility,
  Conn4D.Tests.UI.VisualLogger;

const
  ICON_NEUTRAL = 0;
  ICON_RUNNING = 1;
  ICON_PASS    = 2;
  ICON_FAIL    = 3;

  CHECK_UNCHECKED = 1;
  CHECK_CHECKED   = 2;
  CHECK_PARTIAL   = 3;

type
  TfrmTestRunner = class(TForm)
    pnlHeader: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    pnlActions: TPanel;
    btnRunAll: TButton;
    btnSelectAll: TButton;
    btnUnselectAll: TButton;
    btnClear: TButton;
    pgbProgress: TProgressBar;
    pnlStats: TPanel;
    pnlCardTotal: TPanel;
    lblCardTotalCaption: TLabel;
    lblCardTotalValue: TLabel;
    pnlCardPass: TPanel;
    lblCardPassCaption: TLabel;
    lblCardPassValue: TLabel;
    pnlCardFail: TPanel;
    lblCardFailCaption: TLabel;
    lblCardFailValue: TLabel;
    pnlCardTime: TPanel;
    lblCardTimeCaption: TLabel;
    lblCardTimeValue: TLabel;
    pnlMain: TPanel;
    pnlLeft: TPanel;
    pnlLeftHeader: TPanel;
    lblTreeHeader: TLabel;
    btnExpandBlock: TButton;
    btnCollapseBlock: TButton;
    btnExpandTests: TButton;
    btnCollapseTests: TButton;
    tvTests: TTreeView;
    splMain: TSplitter;
    pnlRight: TPanel;
    pnlRightHeader: TPanel;
    lblLogHeader: TLabel;
    redLog: TRichEdit;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnRunAllClick(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);
    procedure btnUnselectAllClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnExpandBlockClick(Sender: TObject);
    procedure btnCollapseBlockClick(Sender: TObject);
    procedure btnExpandTestsClick(Sender: TObject);
    procedure btnCollapseTestsClick(Sender: TObject);
    procedure tvTestsMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure tvTestsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FRunner: ITestRunner;
    FFixtureList: ITestFixtureList;
    FFixtureNodes: TDictionary<string, TTreeNode>;
    FTestNodes: TDictionary<string, TTreeNode>;
    FTestRefs: TDictionary<string, ITest>;
    FStatusImages: TImageList;
    FCheckImages: TImageList;
    FTotalTests: Integer;
    FCompletedTests: Integer;
    FRunning: Boolean;

    procedure BuildImageLists;
    function MakeStatusBitmap(const AKind: Integer): TBitmap;
    function MakeCheckBitmap(const AKind: Integer): TBitmap;

    procedure DiscoverTests;
    procedure CollectFixtures(const AList: ITestFixtureList);
    procedure ApplySelectionToFixtureList(const AList: ITestFixtureList; const ASelectedKeys: TStrings);
    procedure AddFixtureNode(const AFixture: ITestFixture);
    function TestKey(const AFixture, ATest: string): string;

    procedure SetTestNodeIcon(const ANode: TTreeNode; const AIcon: Integer);
    procedure UpdateFixtureNodeIcon(const ANode: TTreeNode);
    procedure ToggleNodeCheck(const ANode: TTreeNode);
    procedure SetSubtreeCheck(const ANode: TTreeNode; const AState: Integer);
    procedure UpdateParentCheck(const ANode: TTreeNode);
    procedure SetAllChecks(const AState: Integer);
    procedure SetFixtureExpansion(const AExpanded: Boolean);
    procedure SetSelectedFixtureExpansion(const AExpanded: Boolean);
    procedure ApplyEnabledFromChecks;

    procedure AppendLog(const AMessage: string; const AColor: TColor);
    procedure UpdateStatsCards(const APassed, AFailed, ATotal: Integer; const ATimeMs: Int64);
    procedure ResetResults;
    procedure SetRunningState(const ARunning: Boolean);
    procedure UpdateSubtitle;

    procedure HandleTestingStarts(const ATestCount: Cardinal);
    procedure HandleFixtureStart(const AFixtureName: string);
    procedure HandleTestStart(const AFixtureName, ATestName: string);
    procedure HandleTestPass(const AFixtureName, ATestName: string; const ADurationMs: Int64);
    procedure HandleTestFail(const AFixtureName, ATestName, AMessage: string; const ADurationMs: Int64);
    procedure HandleTestingEnds(const APassed, AFailed, AErrors: Integer; const ATotalMs: Int64);
    procedure HandleLog(const AMessage: string);
  end;

var
  frmTestRunner: TfrmTestRunner;

implementation

{$R *.dfm}

const
  CL_PASS    : TColor = $005EC522;  // #22C55E
  CL_FAIL    : TColor = $004444EF;  // #EF4444
  CL_RUNNING : TColor = $000B9EF5;  // #F59E0B
  CL_NEUTRAL : TColor = $00AFA39C;  // #9CA3AF
  CL_ACCENT  : TColor = $00EB6325;  // #2563EB
  CL_TEXT    : TColor = $0037291F;  // #1F2937
  CL_MUTED   : TColor = $0080726B;  // #6B7280
  CL_BORDER  : TColor = $00E1DFDD;  // border gray
  CL_SURFACE : TColor = clWhite;
  CL_BG      : TColor = $00FBFAF9;  // #F9FAFB

procedure TfrmTestRunner.FormCreate(Sender: TObject);
begin
  FFixtureNodes := TDictionary<string, TTreeNode>.Create;
  FTestNodes    := TDictionary<string, TTreeNode>.Create;
  FTestRefs     := TDictionary<string, ITest>.Create;
  FTotalTests   := 0;
  FCompletedTests := 0;
  FRunning      := False;

  BuildImageLists;
  tvTests.Images      := FStatusImages;
  tvTests.StateImages := FCheckImages;

  redLog.Clear;
  AppendLog('Pronto. Marque os testes desejados e clique em "Executar".', CL_MUTED);

  DiscoverTests;
  UpdateStatsCards(0, 0, FTotalTests, 0);
  UpdateSubtitle;
end;

procedure TfrmTestRunner.FormDestroy(Sender: TObject);
begin
  // Release DUnitX object graph before shutdown leak check.
  FFixtureList := nil;
  FRunner := nil;
  FTestRefs.Clear;

  FFixtureNodes.Free;
  FTestNodes.Free;
  FTestRefs.Free;
  FStatusImages.Free;
  FCheckImages.Free;
end;

function TfrmTestRunner.MakeStatusBitmap(const AKind: Integer): TBitmap;
var
  C: TCanvas;
  CircleColor: TColor;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.Width := 16;
  Result.Height := 16;
  C := Result.Canvas;
  C.Brush.Color := CL_SURFACE;
  C.FillRect(Rect(0, 0, 16, 16));

  case AKind of
    ICON_RUNNING: CircleColor := CL_RUNNING;
    ICON_PASS:    CircleColor := CL_PASS;
    ICON_FAIL:    CircleColor := CL_FAIL;
  else
    CircleColor := CL_NEUTRAL;
  end;

  if AKind = ICON_NEUTRAL then
  begin
    C.Brush.Style := bsClear;
    C.Pen.Color := CL_NEUTRAL;
    C.Pen.Width := 1;
    C.Ellipse(3, 3, 13, 13);
    C.Brush.Style := bsSolid;
  end
  else
  begin
    C.Pen.Color := CircleColor;
    C.Brush.Color := CircleColor;
    C.Ellipse(2, 2, 14, 14);

    if AKind = ICON_PASS then
    begin
      C.Pen.Color := clWhite;
      C.Pen.Width := 2;
      C.MoveTo(5, 8);
      C.LineTo(7, 10);
      C.LineTo(11, 5);
    end
    else if AKind = ICON_FAIL then
    begin
      C.Pen.Color := clWhite;
      C.Pen.Width := 2;
      C.MoveTo(5, 5);
      C.LineTo(11, 11);
      C.MoveTo(11, 5);
      C.LineTo(5, 11);
    end;
  end;
end;

function TfrmTestRunner.MakeCheckBitmap(const AKind: Integer): TBitmap;
var
  C: TCanvas;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.Width := 16;
  Result.Height := 16;
  C := Result.Canvas;
  C.Brush.Color := CL_SURFACE;
  C.FillRect(Rect(0, 0, 16, 16));

  case AKind of
    CHECK_UNCHECKED:
      begin
        C.Brush.Color := CL_SURFACE;
        C.Pen.Color := CL_NEUTRAL;
        C.Pen.Width := 1;
        C.Rectangle(2, 2, 14, 14);
      end;
    CHECK_CHECKED:
      begin
        C.Brush.Color := CL_ACCENT;
        C.Pen.Color := CL_ACCENT;
        C.Rectangle(2, 2, 14, 14);
        C.Pen.Color := clWhite;
        C.Pen.Width := 2;
        C.MoveTo(5, 8);
        C.LineTo(7, 10);
        C.LineTo(11, 5);
      end;
    CHECK_PARTIAL:
      begin
        C.Brush.Color := CL_ACCENT;
        C.Pen.Color := CL_ACCENT;
        C.Rectangle(2, 2, 14, 14);
        C.Pen.Color := clWhite;
        C.Pen.Width := 2;
        C.MoveTo(5, 8);
        C.LineTo(11, 8);
      end;
  end;
end;

procedure TfrmTestRunner.BuildImageLists;
var
  BMP: TBitmap;
  I: Integer;
begin
  FStatusImages := TImageList.CreateSize(16, 16);
  FStatusImages.Masked := False;
  FStatusImages.ColorDepth := cd24Bit;
  for I := 0 to 3 do
  begin
    BMP := MakeStatusBitmap(I);
    try
      FStatusImages.Add(BMP, nil);
    finally
      BMP.Free;
    end;
  end;

  FCheckImages := TImageList.CreateSize(16, 16);
  FCheckImages.Masked := False;
  FCheckImages.ColorDepth := cd24Bit;
  // StateIndex=0 means "no state image" — add a blank dummy first
  BMP := TBitmap.Create;
  try
    BMP.PixelFormat := pf24bit;
    BMP.Width := 16;
    BMP.Height := 16;
    BMP.Canvas.Brush.Color := CL_SURFACE;
    BMP.Canvas.FillRect(Rect(0, 0, 16, 16));
    FCheckImages.Add(BMP, nil);
  finally
    BMP.Free;
  end;
  for I := 1 to 3 do
  begin
    BMP := MakeCheckBitmap(I);
    try
      FCheckImages.Add(BMP, nil);
    finally
      BMP.Free;
    end;
  end;
end;

function TfrmTestRunner.TestKey(const AFixture, ATest: string): string;
begin
  Result := AFixture + '::' + ATest;
end;

procedure TfrmTestRunner.DiscoverTests;
begin
  FRunner := TDUnitX.CreateRunner;
  FRunner.UseRTTI := True;
  FFixtureList := FRunner.BuildFixtures as ITestFixtureList;

  tvTests.Items.BeginUpdate;
  try
    tvTests.Items.Clear;
    FFixtureNodes.Clear;
    FTestNodes.Clear;
    FTestRefs.Clear;
    FTotalTests := 0;

    CollectFixtures(FFixtureList);
  finally
    tvTests.Items.EndUpdate;
  end;

  SetFixtureExpansion(True);
end;

procedure TfrmTestRunner.CollectFixtures(const AList: ITestFixtureList);
var
  Fixture: ITestFixture;
begin
  if AList = nil then
    Exit;

  for Fixture in AList do
  begin
    if (Fixture.Tests <> nil) and (Fixture.Tests.Count > 0) then
      AddFixtureNode(Fixture);

    if Fixture.HasChildFixtures then
      CollectFixtures(Fixture.Children);
  end;
end;

procedure TfrmTestRunner.ApplySelectionToFixtureList(const AList: ITestFixtureList;
  const ASelectedKeys: TStrings);
var
  Fixture: ITestFixture;
  Test: ITest;
begin
  if (AList = nil) or (ASelectedKeys = nil) then
    Exit;

  for Fixture in AList do
  begin
    for Test in Fixture.Tests do
      Test.Enabled := ASelectedKeys.IndexOf(TestKey(Fixture.Name, Test.Name)) >= 0;

    if Fixture.HasChildFixtures then
      ApplySelectionToFixtureList(Fixture.Children, ASelectedKeys);
  end;
end;

procedure TfrmTestRunner.AddFixtureNode(const AFixture: ITestFixture);
var
  FixtureNode, TestNode: TTreeNode;
  Test: ITest;
  Key: string;
begin
  FixtureNode := tvTests.Items.Add(nil, AFixture.Name);
  FixtureNode.ImageIndex := ICON_NEUTRAL;
  FixtureNode.SelectedIndex := ICON_NEUTRAL;
  FixtureNode.StateIndex := CHECK_CHECKED;
  FFixtureNodes.AddOrSetValue(AFixture.Name, FixtureNode);

  for Test in AFixture.Tests do
  begin
    if not Test.Enabled then
      Continue;
    TestNode := tvTests.Items.AddChild(FixtureNode, Test.Name);
    TestNode.ImageIndex := ICON_NEUTRAL;
    TestNode.SelectedIndex := ICON_NEUTRAL;
    TestNode.StateIndex := CHECK_CHECKED;
    Key := TestKey(AFixture.Name, Test.Name);
    FTestNodes.AddOrSetValue(Key, TestNode);
    FTestRefs.AddOrSetValue(Key, Test);
    Inc(FTotalTests);
  end;
end;

procedure TfrmTestRunner.SetTestNodeIcon(const ANode: TTreeNode; const AIcon: Integer);
begin
  if ANode = nil then Exit;
  ANode.ImageIndex := AIcon;
  ANode.SelectedIndex := AIcon;
end;

procedure TfrmTestRunner.UpdateFixtureNodeIcon(const ANode: TTreeNode);
var
  Child: TTreeNode;
  HasFail, HasPass, HasRunning, HasNeutral: Boolean;
begin
  if ANode = nil then Exit;
  HasFail := False; HasPass := False; HasRunning := False; HasNeutral := False;
  Child := ANode.getFirstChild;
  while Child <> nil do
  begin
    case Child.ImageIndex of
      ICON_FAIL:    HasFail := True;
      ICON_PASS:    HasPass := True;
      ICON_RUNNING: HasRunning := True;
      ICON_NEUTRAL: HasNeutral := True;
    end;
    Child := Child.getNextSibling;
  end;

  if HasRunning then
    SetTestNodeIcon(ANode, ICON_RUNNING)
  else if HasFail then
    SetTestNodeIcon(ANode, ICON_FAIL)
  else if HasPass and not HasNeutral then
    SetTestNodeIcon(ANode, ICON_PASS)
  else
    SetTestNodeIcon(ANode, ICON_NEUTRAL);
end;

procedure TfrmTestRunner.SetSubtreeCheck(const ANode: TTreeNode; const AState: Integer);
var
  Child: TTreeNode;
begin
  ANode.StateIndex := AState;
  Child := ANode.getFirstChild;
  while Child <> nil do
  begin
    Child.StateIndex := AState;
    Child := Child.getNextSibling;
  end;
end;

procedure TfrmTestRunner.UpdateParentCheck(const ANode: TTreeNode);
var
  Child: TTreeNode;
  HasChecked, HasUnchecked: Boolean;
begin
  if (ANode = nil) or (ANode.Parent = nil) then Exit;
  HasChecked := False;
  HasUnchecked := False;
  Child := ANode.Parent.getFirstChild;
  while Child <> nil do
  begin
    if Child.StateIndex = CHECK_CHECKED then HasChecked := True;
    if Child.StateIndex = CHECK_UNCHECKED then HasUnchecked := True;
    Child := Child.getNextSibling;
  end;

  if HasChecked and not HasUnchecked then
    ANode.Parent.StateIndex := CHECK_CHECKED
  else if HasUnchecked and not HasChecked then
    ANode.Parent.StateIndex := CHECK_UNCHECKED
  else
    ANode.Parent.StateIndex := CHECK_PARTIAL;
end;

procedure TfrmTestRunner.ToggleNodeCheck(const ANode: TTreeNode);
var
  NewState: Integer;
begin
  if ANode = nil then Exit;
  if ANode.StateIndex = CHECK_CHECKED then
    NewState := CHECK_UNCHECKED
  else
    NewState := CHECK_CHECKED;

  if ANode.HasChildren then
    SetSubtreeCheck(ANode, NewState)
  else
  begin
    ANode.StateIndex := NewState;
    UpdateParentCheck(ANode);
  end;
  UpdateSubtitle;
end;

procedure TfrmTestRunner.SetAllChecks(const AState: Integer);
var
  Node: TTreeNode;
begin
  Node := tvTests.Items.GetFirstNode;
  while Node <> nil do
  begin
    Node.StateIndex := AState;
    Node := Node.GetNext;
  end;
  UpdateSubtitle;
end;

procedure TfrmTestRunner.SetFixtureExpansion(const AExpanded: Boolean);
var
  Node: TTreeNode;
begin
  tvTests.Items.BeginUpdate;
  try
    Node := tvTests.Items.GetFirstNode;
    while Node <> nil do
    begin
      if AExpanded then
        Node.Expand(False)
      else
        Node.Collapse(False);
      Node := Node.getNextSibling;
    end;
  finally
    tvTests.Items.EndUpdate;
  end;
end;

procedure TfrmTestRunner.SetSelectedFixtureExpansion(const AExpanded: Boolean);
var
  Node: TTreeNode;
begin
  Node := tvTests.Selected;
  if Node = nil then
    Exit;

  if Node.Parent <> nil then
    Node := Node.Parent;

  if AExpanded then
    Node.Expand(False)
  else
    Node.Collapse(False);
end;

procedure TfrmTestRunner.ApplyEnabledFromChecks;
var
  Pair: TPair<string, ITest>;
  Node: TTreeNode;
begin
  for Pair in FTestRefs do
  begin
    if FTestNodes.TryGetValue(Pair.Key, Node) then
      Pair.Value.Enabled := (Node.StateIndex = CHECK_CHECKED);
  end;
end;

procedure TfrmTestRunner.AppendLog(const AMessage: string; const AColor: TColor);
begin
  redLog.SelStart := redLog.GetTextLen;
  redLog.SelLength := 0;
  redLog.SelAttributes.Color := AColor;
  redLog.Lines.Add(AMessage);
  SendMessage(redLog.Handle, EM_SCROLLCARET, 0, 0);
end;

procedure TfrmTestRunner.UpdateStatsCards(const APassed, AFailed, ATotal: Integer;
  const ATimeMs: Int64);
begin
  lblCardTotalValue.Caption := IntToStr(ATotal);
  lblCardPassValue.Caption  := IntToStr(APassed);
  lblCardFailValue.Caption  := IntToStr(AFailed);
  if ATimeMs >= 1000 then
    lblCardTimeValue.Caption := Format('%.2f s', [ATimeMs / 1000])
  else
    lblCardTimeValue.Caption := Format('%d ms', [ATimeMs]);
end;

procedure TfrmTestRunner.UpdateSubtitle;
var
  Node: TTreeNode;
  Selected: Integer;
begin
  Selected := 0;
  for Node in FTestNodes.Values do
    if Node.StateIndex = CHECK_CHECKED then
      Inc(Selected);
  lblSubtitle.Caption := Format('%d teste(s) selecionado(s) de %d', [Selected, FTotalTests]);
end;

procedure TfrmTestRunner.ResetResults;
var
  Node: TTreeNode;
begin
  for Node in FTestNodes.Values do
    SetTestNodeIcon(Node, ICON_NEUTRAL);
  for Node in FFixtureNodes.Values do
    SetTestNodeIcon(Node, ICON_NEUTRAL);
  pgbProgress.Position := 0;
  UpdateStatsCards(0, 0, FTotalTests, 0);
end;

procedure TfrmTestRunner.SetRunningState(const ARunning: Boolean);
begin
  FRunning := ARunning;
  btnRunAll.Enabled       := not ARunning;
  btnSelectAll.Enabled    := not ARunning;
  btnUnselectAll.Enabled  := not ARunning;
  btnClear.Enabled        := not ARunning;
  btnExpandBlock.Enabled  := not ARunning;
  btnCollapseBlock.Enabled := not ARunning;
  btnExpandTests.Enabled  := not ARunning;
  btnCollapseTests.Enabled := not ARunning;
end;

procedure TfrmTestRunner.HandleTestingStarts(const ATestCount: Cardinal);
begin
  pgbProgress.Min := 0;
  pgbProgress.Max := Integer(ATestCount);
  pgbProgress.Position := 0;
  FCompletedTests := 0;
  AppendLog(Format('Iniciando %d teste(s)...', [ATestCount]), CL_MUTED);
end;

procedure TfrmTestRunner.HandleFixtureStart(const AFixtureName: string);
begin
  AppendLog('', clBlack);
  AppendLog('▸ ' + AFixtureName, CL_ACCENT);
end;

procedure TfrmTestRunner.HandleTestStart(const AFixtureName, ATestName: string);
var
  Node: TTreeNode;
begin
  if FTestNodes.TryGetValue(TestKey(AFixtureName, ATestName), Node) then
  begin
    SetTestNodeIcon(Node, ICON_RUNNING);
    UpdateFixtureNodeIcon(Node.Parent);
    tvTests.Selected := Node;
  end;
end;

procedure TfrmTestRunner.HandleTestPass(const AFixtureName, ATestName: string;
  const ADurationMs: Int64);
var
  Node, FixtureNode: TTreeNode;
begin
  if FTestNodes.TryGetValue(TestKey(AFixtureName, ATestName), Node) then
  begin
    SetTestNodeIcon(Node, ICON_PASS);
    if FFixtureNodes.TryGetValue(AFixtureName, FixtureNode) then
      UpdateFixtureNodeIcon(FixtureNode);
  end;
  AppendLog(Format('   ✓ %s   %d ms', [ATestName, ADurationMs]), CL_PASS);
  Inc(FCompletedTests);
  pgbProgress.Position := FCompletedTests;
end;

procedure TfrmTestRunner.HandleTestFail(const AFixtureName, ATestName,
  AMessage: string; const ADurationMs: Int64);
var
  Node, FixtureNode: TTreeNode;
begin
  if FTestNodes.TryGetValue(TestKey(AFixtureName, ATestName), Node) then
  begin
    SetTestNodeIcon(Node, ICON_FAIL);
    if FFixtureNodes.TryGetValue(AFixtureName, FixtureNode) then
      UpdateFixtureNodeIcon(FixtureNode);
  end;
  AppendLog(Format('   ✗ %s   %d ms', [ATestName, ADurationMs]), CL_FAIL);
  AppendLog('     → ' + AMessage, CL_FAIL);
  Inc(FCompletedTests);
  pgbProgress.Position := FCompletedTests;
end;

procedure TfrmTestRunner.HandleTestingEnds(const APassed, AFailed,
  AErrors: Integer; const ATotalMs: Int64);
begin
  AppendLog('', clBlack);
  if (AFailed = 0) and (AErrors = 0) then
    AppendLog(Format('Concluído em %d ms — %d aprovado(s)', [ATotalMs, APassed]), CL_PASS)
  else
    AppendLog(Format('Concluído em %d ms — %d aprovado(s), %d falha(s), %d erro(s)',
      [ATotalMs, APassed, AFailed, AErrors]), CL_FAIL);
  UpdateStatsCards(APassed, AFailed + AErrors, FTotalTests, ATotalMs);
  SetRunningState(False);
  pgbProgress.Position := pgbProgress.Max;
end;

procedure TfrmTestRunner.HandleLog(const AMessage: string);
begin
  AppendLog('     ' + AMessage, CL_MUTED);
end;

procedure TfrmTestRunner.btnRunAllClick(Sender: TObject);
var
  Logger: TVisualTestLogger;
  LoggerIntf: ITestLogger;
  Node: TTreeNode;
  RunnerRef: ITestRunner;
begin
  SetRunningState(True);

  for Node in FTestNodes.Values do
    SetTestNodeIcon(Node, ICON_NEUTRAL);
  for Node in FFixtureNodes.Values do
    SetTestNodeIcon(Node, ICON_NEUTRAL);

  redLog.Clear;
  pgbProgress.Position := 0;

  Logger := TVisualTestLogger.Create;
  LoggerIntf := Logger;
  Logger.OnTestingStartsEvent := HandleTestingStarts;
  Logger.OnFixtureStartEvent  := HandleFixtureStart;
  Logger.OnTestStartEvent     := HandleTestStart;
  Logger.OnTestPassEvent      := HandleTestPass;
  Logger.OnTestFailEvent      := HandleTestFail;
  Logger.OnTestingEndsEvent   := HandleTestingEnds;
  Logger.OnLogEvent           := HandleLog;

  TThread.CreateAnonymousThread(
    procedure
    var
      FixtureList: ITestFixtureList;
    begin
      try
        try
          RunnerRef := TDUnitX.CreateRunner;
          RunnerRef.UseRTTI := True;
          FixtureList := RunnerRef.BuildFixtures as ITestFixtureList;

          // Match selected tests by "Fixture::Test" keys.
          var EffectiveKeys := TStringList.Create;
          try
            EffectiveKeys.Sorted := True;
            EffectiveKeys.Duplicates := dupIgnore;
            TThread.Synchronize(nil,
              procedure
              var
                Pair: TPair<string, TTreeNode>;
              begin
                for Pair in FTestNodes do
                  if Pair.Value.StateIndex = CHECK_CHECKED then
                    EffectiveKeys.Add(Pair.Key);
              end);

            ApplySelectionToFixtureList(FixtureList, EffectiveKeys);
          finally
            EffectiveKeys.Free;
          end;

          RunnerRef.AddLogger(LoggerIntf);
          RunnerRef.Execute;
        except
          on E: Exception do
          begin
            var Msg := E.Message;
            TThread.Queue(nil,
              procedure
              begin
                AppendLog('ERRO: ' + Msg, CL_FAIL);
                SetRunningState(False);
              end);
          end;
        end;
      finally
        Logger.OnTestingStartsEvent := nil;
        Logger.OnFixtureStartEvent  := nil;
        Logger.OnTestStartEvent     := nil;
        Logger.OnTestPassEvent      := nil;
        Logger.OnTestFailEvent      := nil;
        Logger.OnTestingEndsEvent   := nil;
        Logger.OnLogEvent           := nil;
        LoggerIntf := nil;
        RunnerRef := nil;
      end;
    end).Start;
end;

procedure TfrmTestRunner.btnSelectAllClick(Sender: TObject);
begin
  SetAllChecks(CHECK_CHECKED);
end;

procedure TfrmTestRunner.btnUnselectAllClick(Sender: TObject);
begin
  SetAllChecks(CHECK_UNCHECKED);
end;

procedure TfrmTestRunner.btnClearClick(Sender: TObject);
begin
  redLog.Clear;
  ResetResults;
  AppendLog('Resultados limpos.', CL_MUTED);
end;

procedure TfrmTestRunner.btnExpandBlockClick(Sender: TObject);
begin
  SetSelectedFixtureExpansion(True);
end;

procedure TfrmTestRunner.btnCollapseBlockClick(Sender: TObject);
begin
  SetSelectedFixtureExpansion(False);
end;

procedure TfrmTestRunner.btnExpandTestsClick(Sender: TObject);
begin
  SetFixtureExpansion(True);
end;

procedure TfrmTestRunner.btnCollapseTestsClick(Sender: TObject);
begin
  SetFixtureExpansion(False);
end;

procedure TfrmTestRunner.tvTestsMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  HitTest: THitTests;
  Node: TTreeNode;
begin
  if FRunning then Exit;
  if Button <> mbLeft then Exit;

  HitTest := tvTests.GetHitTestInfoAt(X, Y);
  Node := tvTests.GetNodeAt(X, Y);

  if htOnStateIcon in HitTest then
  begin
    if Node <> nil then
      ToggleNodeCheck(Node);
    Exit;
  end;

  if (Node <> nil)
    and (Node.Parent = nil)
    and Node.HasChildren
    and ((htOnItem in HitTest) or (htOnLabel in HitTest)
      or (htOnIcon in HitTest) or (htOnButton in HitTest)) then
  begin
    if Node.Expanded then
      Node.Collapse(False)
    else
      Node.Expand(False);
  end;
end;

procedure TfrmTestRunner.tvTestsKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if FRunning then Exit;
  if (Key = VK_SPACE) and (tvTests.Selected <> nil) then
  begin
    ToggleNodeCheck(tvTests.Selected);
    Key := 0;
  end;
end;

end.

