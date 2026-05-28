program FormUsage;

uses
  Vcl.Forms,
  FireDAC.Phys.FB,
  FormUsage.Main in 'FormUsage.Main.pas' {FrmConn4DExample};

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmConn4DExample, FrmConn4DExample);
  Application.Run;
end.
