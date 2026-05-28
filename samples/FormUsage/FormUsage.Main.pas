unit FormUsage.Main;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.IniFiles,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Conn4D,
  Conn4D.Presentation.Components.TConn4D;

type
  TFrmConn4DExample = class(TForm)
    PnlTop: TPanel;
    LblPoolName: TLabel;
    EdtPoolName: TEdit;
    BtnConfigure: TButton;
    BtnAcquire: TButton;
    MemoLog: TMemo;
    Conn4D1: TConn4D;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure BtnConfigureClick(Sender: TObject);
    procedure BtnAcquireClick(Sender: TObject);
  private
    procedure Log(const AMessage: string);
  end;

var
  FrmConn4DExample: TFrmConn4DExample;

implementation

{$R *.dfm}

procedure TFrmConn4DExample.FormCreate(Sender: TObject);
var
  Ini    : TIniFile;
  IniPath: string;
begin
  IniPath := ExtractFilePath(Application.ExeName) + 'settings.ini';
  if FileExists(IniPath) then
  begin
    Ini := TIniFile.Create(IniPath);
    try
      EdtPoolName.Text := Ini.ReadString('Database', 'PoolName', Conn4D1.PoolName);
    finally
      Ini.Free;
    end;
  end
  else
    EdtPoolName.Text := Conn4D1.PoolName;

  Log('Exemplo iniciado. Clique em Configurar Pool para conectar.');
end;

procedure TFrmConn4DExample.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  TConn4D.Shutdown;
end;

procedure TFrmConn4DExample.BtnConfigureClick(Sender: TObject);
var
  Ini    : TIniFile;
  IniPath: string;
begin
  Conn4D1.PoolName := Trim(EdtPoolName.Text);

  if Conn4D1.PoolName = '' then
    raise Exception.Create('Informe um nome de pool.');

  if TConn4D.PoolExists(Conn4D1.PoolName) then
  begin
    Log('Pool "' + Conn4D1.PoolName + '" ja existe.');
    Exit;
  end;

  IniPath := ExtractFilePath(Application.ExeName) + 'settings.ini';
  if not FileExists(IniPath) then
    raise Exception.CreateFmt(
      'settings.ini nao encontrado em %s.'#13#10 +
      'Copie settings.example.ini para settings.ini e preencha os dados de conexao.',
      [IniPath]);

  Ini := TIniFile.Create(IniPath);
  try
    TConn4D.Configure
      .Pool(Conn4D1.PoolName)
        .Host(Ini.ReadString ('Database', 'Host',            '127.0.0.1'))
        .Port(Ini.ReadInteger('Database', 'Port',            3050))
        .Database(Ini.ReadString ('Database', 'Database',   ''))
        .UserName(Ini.ReadString ('Database', 'UserName',   'SYSDBA'))
        .Password(Ini.ReadString ('Database', 'Password',   ''))
        .MaxPoolSize(Ini.ReadInteger('Database', 'MaxPoolSize',    10))
        .AcquireTimeout(Ini.ReadInteger('Database', 'AcquireTimeout', 10000))
        .AddParam('Protocol', Ini.ReadString('Database', 'Protocol', 'TCPIP'))
      .Apply;
  finally
    Ini.Free;
  end;

  Log('Pool "' + Conn4D1.PoolName + '" configurado.');
end;

procedure TFrmConn4DExample.BtnAcquireClick(Sender: TObject);
var
  Handle: TConn4DHandle;
begin
  if not TConn4D.PoolExists(Conn4D1.PoolName) then
    raise Exception.Create('Pool nao configurado. Clique em Configurar Pool primeiro.');

  Handle := TConn4D.Acquire(Conn4D1.PoolName);
  Log('Conexao adquirida com sucesso para o pool "' + Conn4D1.PoolName + '".');

  // O handle sera devolvido ao pool ao sair do escopo.
end;

procedure TFrmConn4DExample.Log(const AMessage: string);
begin
  MemoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' - ' + AMessage);
end;

end.
