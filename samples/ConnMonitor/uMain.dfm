object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'Conn4D - PRODUTOS / Concorrencia / Transacoes'
  ClientHeight = 640
  ClientWidth = 928
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlStatus: TPanel
    Left = 0
    Top = 618
    Width = 928
    Height = 22
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitTop = 610
    ExplicitWidth = 926
    object lblStatus: TLabel
      Left = 0
      Top = 0
      Width = 928
      Height = 22
      Align = alClient
      Caption = '  Pronto.'
      Layout = tlCenter
      ExplicitWidth = 45
      ExplicitHeight = 15
    end
  end
  object pgc: TPageControl
    Left = 0
    Top = 0
    Width = 928
    Height = 618
    ActivePage = tabProdutos
    Align = alClient
    TabOrder = 1
    ExplicitWidth = 926
    ExplicitHeight = 610
    object tabProdutos: TTabSheet
      Caption = 'Produtos &Monitor'
      object Splitter: TSplitter
        Left = 0
        Top = 382
        Width = 920
        Height = 4
        Cursor = crVSplit
        Align = alBottom
        ExplicitTop = 380
      end
      object pnlTop: TPanel
        Left = 0
        Top = 0
        Width = 920
        Height = 100
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitWidth = 918
        object lblFiltro: TLabel
          Left = 520
          Top = 14
          Width = 30
          Height = 15
          Caption = 'Filtro:'
        end
        object lblEdit: TLabel
          Left = 8
          Top = 50
          Width = 99
          Height = 15
          Caption = 'Editar selecionado:'
        end
        object lblCod: TLabel
          Left = 8
          Top = 73
          Width = 25
          Height = 15
          Caption = 'Cod:'
        end
        object lblDesc: TLabel
          Left = 116
          Top = 73
          Width = 32
          Height = 15
          Caption = 'Descr:'
        end
        object lblPreco: TLabel
          Left = 374
          Top = 73
          Width = 33
          Height = 15
          Caption = 'Preco:'
        end
        object lblCusto: TLabel
          Left = 510
          Top = 73
          Width = 34
          Height = 15
          Caption = 'Custo:'
        end
        object btnConsultar: TButton
          Left = 8
          Top = 8
          Width = 90
          Height = 28
          Caption = 'Consultar'
          TabOrder = 0
          OnClick = btnConsultarClick
        end
        object btnAlterar: TButton
          Left = 104
          Top = 8
          Width = 90
          Height = 28
          Caption = 'Alterar'
          TabOrder = 1
          OnClick = btnAlterarClick
        end
        object btnZombie: TButton
          Left = 200
          Top = 8
          Width = 140
          Height = 28
          Caption = 'Simular Zumbi'
          TabOrder = 2
          OnClick = btnZombieClick
        end
        object btnStress: TButton
          Left = 346
          Top = 8
          Width = 110
          Height = 28
          Caption = 'Stress (N)'
          TabOrder = 3
          OnClick = btnStressClick
        end
        object edtCount: TEdit
          Left = 462
          Top = 11
          Width = 40
          Height = 23
          TabOrder = 4
          Text = '5'
        end
        object edtFiltro: TEdit
          Left = 556
          Top = 11
          Width = 180
          Height = 23
          TabOrder = 5
        end
        object btnShutdown: TButton
          Left = 800
          Top = 8
          Width = 90
          Height = 28
          Caption = 'Shutdown'
          TabOrder = 6
          OnClick = btnShutdownClick
        end
        object edtCod: TEdit
          Left = 38
          Top = 70
          Width = 60
          Height = 23
          ReadOnly = True
          TabOrder = 7
        end
        object edtDesc: TEdit
          Left = 156
          Top = 70
          Width = 206
          Height = 23
          ReadOnly = True
          TabOrder = 8
        end
        object edtPreco: TEdit
          Left = 412
          Top = 70
          Width = 84
          Height = 23
          TabOrder = 9
        end
        object edtCusto: TEdit
          Left = 548
          Top = 70
          Width = 84
          Height = 23
          TabOrder = 10
        end
        object chkAtivo: TCheckBox
          Left = 648
          Top = 72
          Width = 80
          Height = 17
          Caption = 'Ativo'
          TabOrder = 11
        end
      end
      object gridProd: TStringGrid
        Left = 0
        Top = 100
        Width = 920
        Height = 282
        Align = alClient
        DefaultRowHeight = 22
        FixedCols = 0
        RowCount = 2
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing]
        TabOrder = 1
        OnClick = gridProdClick
        ExplicitWidth = 918
        ExplicitHeight = 274
      end
      object pnlMon: TPanel
        Left = 0
        Top = 386
        Width = 920
        Height = 202
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 2
        ExplicitTop = 378
        ExplicitWidth = 918
        object lblMonTitle: TLabel
          Left = 0
          Top = 0
          Width = 920
          Height = 15
          Align = alTop
          Caption = '  Monitor de conexoes (atualiza a cada 500 ms):'
          ExplicitWidth = 249
        end
        object gridMon: TStringGrid
          Left = 0
          Top = 15
          Width = 920
          Height = 187
          Align = alClient
          ColCount = 8
          DefaultRowHeight = 22
          FixedCols = 0
          RowCount = 2
          Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing]
          TabOrder = 0
          ExplicitWidth = 918
        end
      end
    end
    object tabConc: TTabSheet
      Caption = '&Concorrencia (deadlock)'
      ImageIndex = 1
      object pnlTopC: TPanel
        Left = 0
        Top = 0
        Width = 920
        Height = 84
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object lblCodC: TLabel
          Left = 8
          Top = 13
          Width = 25
          Height = 15
          Caption = 'Cod:'
        end
        object lblThreads: TLabel
          Left = 116
          Top = 13
          Width = 44
          Height = 15
          Caption = 'Threads:'
        end
        object lblHintC: TLabel
          Left = 8
          Top = 52
          Width = 880
          Height = 28
          AutoSize = False
          Caption = 
            '  N threads chamam o MESMO metodo atualizando descricao + valore' +
            's do MESMO produto ao mesmo tempo. Cada thread usa SUA conexao d' +
            'o pool; o Conn4D nao entra em deadlock (conflitos do banco viram' +
            ' rollback + mensagem).'
          WordWrap = True
        end
        object edtCodC: TEdit
          Left = 39
          Top = 10
          Width = 60
          Height = 23
          TabOrder = 0
          Text = '1'
        end
        object edtThreads: TEdit
          Left = 169
          Top = 10
          Width = 50
          Height = 23
          TabOrder = 1
          Text = '4'
        end
        object btnConcorrer: TButton
          Left = 240
          Top = 8
          Width = 200
          Height = 28
          Caption = 'Rodar concorrencia'
          TabOrder = 2
          OnClick = btnConcorrerClick
        end
        object btnLimparC: TButton
          Left = 446
          Top = 8
          Width = 90
          Height = 28
          Caption = 'Limpar log'
          TabOrder = 3
          OnClick = btnLimparCClick
        end
      end
      object memoConc: TMemo
        Left = 0
        Top = 84
        Width = 920
        Height = 504
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 1
        WordWrap = False
      end
    end
    object tabTx: TTabSheet
      Caption = '&Transacoes (commit/rollback)'
      ImageIndex = 2
      object pnlTopT: TPanel
        Left = 0
        Top = 0
        Width = 920
        Height = 84
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object lblCodT: TLabel
          Left = 8
          Top = 13
          Width = 25
          Height = 15
          Caption = 'Cod:'
        end
        object lblHintT: TLabel
          Left = 8
          Top = 52
          Width = 880
          Height = 28
          AutoSize = False
          Caption = 
            '  "Confirmar" faz um UPDATE e da Commit (valor persiste). "Forca' +
            'r erro" faz o UPDATE e injeta uma falha antes do Commit, forcand' +
            'o Rollback (valor revertido). A prova antes/depois e lida da bas' +
            'e.'
          WordWrap = True
        end
        object edtCodT: TEdit
          Left = 39
          Top = 10
          Width = 60
          Height = 23
          TabOrder = 0
          Text = '1'
        end
        object btnTxCommit: TButton
          Left = 116
          Top = 8
          Width = 180
          Height = 28
          Caption = 'Confirmar (commit)'
          TabOrder = 1
          OnClick = btnTxCommitClick
        end
        object btnTxRollback: TButton
          Left = 302
          Top = 8
          Width = 200
          Height = 28
          Caption = 'Forcar erro (rollback)'
          TabOrder = 2
          OnClick = btnTxRollbackClick
        end
        object btnLimparT: TButton
          Left = 508
          Top = 8
          Width = 90
          Height = 28
          Caption = 'Limpar log'
          TabOrder = 3
          OnClick = btnLimparTClick
        end
      end
      object memoTx: TMemo
        Left = 0
        Top = 84
        Width = 920
        Height = 504
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 1
        WordWrap = False
      end
    end
  end
  object Timer: TTimer
    Enabled = False
    OnTimer = TimerTimer
    Left = 760
    Top = 160
  end
end
