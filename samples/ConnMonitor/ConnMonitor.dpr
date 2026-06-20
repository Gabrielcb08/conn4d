program ConnMonitor;

{
  Conn4D — Exemplo: PRODUTOS + Monitor de Conexões (VCL + SQLite, sem servidor).

  Demonstra a fachada tipada TFDConn4D.Acquire sobre uma tabela de negócio
  PRODUTOS: consultar, alterar (com transação), monitorar as conexões vivas do
  pool em tempo real (IConn4D.LiveConnections) e simular uma conexão zumbi que o
  garbage collector fecha automaticamente.
}

uses
  Vcl.Forms,
  uProdutosRepo in 'uProdutosRepo.pas',
  uMain in 'uMain.pas' {frmMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
