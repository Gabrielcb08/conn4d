unit Conn4D.Reg;

interface

procedure Register;

implementation

uses
  System.Classes,
  Conn4D.Presentation.Components.TConn4D;

procedure Register;
begin
  RegisterComponents('ORData', [TConn4D]);
end;

end.
