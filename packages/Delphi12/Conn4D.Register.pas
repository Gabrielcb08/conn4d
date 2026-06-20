unit Conn4D.Register;

{
  Conn4D — Registro na IDE (apenas no pacote de DESIGN dclConn4).

  Coloca o componente TConn4D na paleta ORData e linka o ícone 24x24 a partir do
  recurso Conn4D.Register.dcr (cujo bitmap se chama TCONN4D, igual à classe em
  maiúsculas). Esta unit não entra no runtime — só no design package.
}

interface

procedure Register;

implementation

uses
  System.Classes,
  Conn4D.Component;

{$R Conn4D.Register.dcr}

procedure Register;
begin
  RegisterComponents('ORData', [TConn4D]);
end;

end.
