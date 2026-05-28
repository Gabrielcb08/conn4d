object frmTestRunner: TfrmTestRunner
  Left = 0
  Top = 0
  Caption = 'Conn4D - Test Runner'
  ClientHeight = 720
  ClientWidth = 1100
  Color = 16448250
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 1100
    Height = 80
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object lblTitle: TLabel
      Left = 24
      Top = 16
      Width = 246
      Height = 30
      Caption = 'Conn4D '#183' Test Runner'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 3614495
      Font.Height = -22
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblSubtitle: TLabel
      Left = 24
      Top = 50
      Width = 138
      Height = 17
      Caption = '0 teste(s) selecionado(s)'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 8418411
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object pnlActions: TPanel
    Left = 0
    Top = 80
    Width = 1100
    Height = 60
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 1
    object btnRunAll: TButton
      Left = 24
      Top = 14
      Width = 156
      Height = 34
      Caption = 'Executar'
      Default = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 0
      OnClick = btnRunAllClick
    end
    object btnSelectAll: TButton
      Left = 188
      Top = 14
      Width = 130
      Height = 34
      Caption = 'Marcar todos'
      TabOrder = 1
      OnClick = btnSelectAllClick
    end
    object btnUnselectAll: TButton
      Left = 326
      Top = 14
      Width = 130
      Height = 34
      Caption = 'Desmarcar todos'
      TabOrder = 2
      OnClick = btnUnselectAllClick
    end
    object btnClear: TButton
      Left = 464
      Top = 14
      Width = 130
      Height = 34
      Caption = 'Limpar resultados'
      TabOrder = 3
      OnClick = btnClearClick
    end
    object pgbProgress: TProgressBar
      Left = 612
      Top = 21
      Width = 464
      Height = 20
      Anchors = [akLeft, akTop, akRight]
      Smooth = True
      TabOrder = 4
    end
  end
  object pnlStats: TPanel
    Left = 0
    Top = 140
    Width = 1100
    Height = 100
    Align = alTop
    BevelOuter = bvNone
    Color = 16448250
    ParentBackground = False
    TabOrder = 2
    object pnlCardTotal: TPanel
      Left = 24
      Top = 12
      Width = 252
      Height = 76
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 0
      object lblCardTotalCaption: TLabel
        Left = 16
        Top = 12
        Width = 47
        Height = 14
        Caption = 'TOTAL'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8418411
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object lblCardTotalValue: TLabel
        Left = 16
        Top = 28
        Width = 18
        Height = 40
        Caption = '0'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 3614495
        Font.Height = -32
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
    end
    object pnlCardPass: TPanel
      Left = 284
      Top = 12
      Width = 252
      Height = 76
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 1
      object lblCardPassCaption: TLabel
        Left = 16
        Top = 12
        Width = 79
        Height = 14
        Caption = 'APROVADOS'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8418411
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object lblCardPassValue: TLabel
        Left = 16
        Top = 28
        Width = 18
        Height = 40
        Caption = '0'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 6210850
        Font.Height = -32
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
    end
    object pnlCardFail: TPanel
      Left = 544
      Top = 12
      Width = 252
      Height = 76
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 2
      object lblCardFailCaption: TLabel
        Left = 16
        Top = 12
        Width = 51
        Height = 14
        Caption = 'FALHAS'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8418411
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object lblCardFailValue: TLabel
        Left = 16
        Top = 28
        Width = 18
        Height = 40
        Caption = '0'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 4474596
        Font.Height = -32
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
    end
    object pnlCardTime: TPanel
      Left = 804
      Top = 12
      Width = 252
      Height = 76
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 3
      object lblCardTimeCaption: TLabel
        Left = 16
        Top = 12
        Width = 49
        Height = 14
        Caption = 'TEMPO'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8418411
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object lblCardTimeValue: TLabel
        Left = 16
        Top = 28
        Width = 53
        Height = 40
        Caption = '0 ms'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 15426853
        Font.Height = -32
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
    end
  end
  object pnlMain: TPanel
    Left = 0
    Top = 240
    Width = 1100
    Height = 480
    Align = alClient
    BevelOuter = bvNone
    Color = 16448250
    ParentBackground = False
    TabOrder = 3
    object splMain: TSplitter
      Left = 380
      Top = 0
      Width = 6
      Height = 480
      Color = 16448250
      ParentColor = False
    end
    object pnlLeft: TPanel
      Left = 0
      Top = 0
      Width = 380
      Height = 480
      Align = alLeft
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 0
      object pnlLeftHeader: TPanel
        Left = 0
        Top = 0
        Width = 380
        Height = 36
        Align = alTop
        BevelOuter = bvNone
        Color = clWhite
        ParentBackground = False
        TabOrder = 0
        object lblTreeHeader: TLabel
          Left = 16
          Top = 12
          Width = 47
          Height = 14
          Caption = 'TESTES'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8418411
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object btnExpandBlock: TButton
          Left = 180
          Top = 6
          Width = 32
          Height = 24
          Caption = '+'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -15
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          TabOrder = 0
          OnClick = btnExpandBlockClick
        end
        object btnCollapseBlock: TButton
          Left = 216
          Top = 6
          Width = 32
          Height = 24
          Caption = '-'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -15
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          TabOrder = 1
          OnClick = btnCollapseBlockClick
        end
        object btnExpandTests: TButton
          Left = 252
          Top = 6
          Width = 58
          Height = 24
          Caption = 'Abrir Todos'
          TabOrder = 2
          OnClick = btnExpandTestsClick
        end
        object btnCollapseTests: TButton
          Left = 314
          Top = 6
          Width = 62
          Height = 24
          Caption = 'Fechar Todos'
          TabOrder = 3
          OnClick = btnCollapseTestsClick
        end
      end
      object tvTests: TTreeView
        Left = 0
        Top = 36
        Width = 380
        Height = 444
        Align = alClient
        BorderStyle = bsNone
        Color = clWhite
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 3614495
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = []
        Indent = 24
        ParentFont = False
        ReadOnly = True
        RowSelect = True
        ShowButtons = True
        ShowLines = True
        ShowRoot = False
        TabOrder = 0
        OnKeyDown = tvTestsKeyDown
        OnMouseDown = tvTestsMouseDown
      end
    end
    object pnlRight: TPanel
      Left = 386
      Top = 0
      Width = 714
      Height = 480
      Align = alClient
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 1
      object pnlRightHeader: TPanel
        Left = 0
        Top = 0
        Width = 714
        Height = 36
        Align = alTop
        BevelOuter = bvNone
        Color = clWhite
        ParentBackground = False
        TabOrder = 0
        object lblLogHeader: TLabel
          Left = 16
          Top = 12
          Width = 130
          Height = 14
          Caption = 'LOG DE EXECU'#199#195'O'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8418411
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
      end
      object redLog: TRichEdit
        Left = 0
        Top = 36
        Width = 714
        Height = 444
        Align = alClient
        BorderStyle = bsNone
        Color = clWhite
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
        Zoom = 100
      end
    end
  end
end

