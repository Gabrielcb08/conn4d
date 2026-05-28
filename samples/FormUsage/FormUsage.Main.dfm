object FrmConn4DExample: TFrmConn4DExample
  Left = 0
  Top = 0
  Caption = 'Conn4D - FormUsage'
  ClientHeight = 430
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnClose = FormClose
  OnCreate = FormCreate
  TextHeight = 15
  object PnlTop: TPanel
    Left = 0
    Top = 0
    Width = 760
    Height = 81
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 758
    object LblPoolName: TLabel
      Left = 16
      Top = 14
      Width = 106
      Height = 15
      Caption = 'Nome do pool ativo'
    end
    object EdtPoolName: TEdit
      Left = 16
      Top = 35
      Width = 273
      Height = 23
      TabOrder = 0
      Text = 'default'
    end
    object BtnConfigure: TButton
      Left = 304
      Top = 33
      Width = 153
      Height = 27
      Caption = 'Configurar Pool'
      TabOrder = 1
      OnClick = BtnConfigureClick
    end
    object BtnAcquire: TButton
      Left = 472
      Top = 33
      Width = 201
      Height = 27
      Caption = 'Testar Acquire'
      TabOrder = 2
      OnClick = BtnAcquireClick
    end
  end
  object MemoLog: TMemo
    Left = 0
    Top = 81
    Width = 760
    Height = 349
    Align = alClient
    Lines.Strings = (
      'Log do exemplo...')
    ScrollBars = ssVertical
    TabOrder = 1
    ExplicitWidth = 758
    ExplicitHeight = 341
  end
  object Conn4D1: TConn4D
    PoolName = 'default'
    Left = 608
    Top = 32
  end
end
