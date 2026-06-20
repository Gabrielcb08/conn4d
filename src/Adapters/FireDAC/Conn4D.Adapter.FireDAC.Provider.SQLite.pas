unit Conn4D.Adapter.FireDAC.Provider.SQLite;

{
  Conn4D — Provider FireDAC: SQLite

  Linka o driver físico do SQLite (FireDAC.Phys.SQLite). O SQLite é compilado
  ESTATICAMENTE no FireDAC, então não há client lib externa a configurar — o
  configurador registrado é um no-op (mantido por simetria; se um dia o app usar
  uma sqlite3.dll externa, basta apontar VendorLibX86/X64 para o arquivo .dll).
  Inclua na uses da aplicação que usa SQLite:

      uses Conn4D.Adapter.FireDAC.Provider.SQLite;
}

interface

implementation

uses
  System.Classes,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  Conn4D.Core,
  Conn4D.Adapter.FireDAC.Providers,
  Conn4D.Adapter.FireDAC.VendorLib;

var
  GLink: TFDPhysSQLiteDriverLink;

initialization
  GLink := TFDPhysSQLiteDriverLink.Create(nil);
  TFDProviders.Register('SQLite',
    procedure(const ACfg: IConnConfig)
    var
      Lib: string;
    begin
      // Só aplica se o usuário apontou uma sqlite3.dll externa explícita
      // (ADefaultFileName='' => não assume nome padrão).
      Lib := ResolveVendorLib(ACfg, '');
      if Lib <> '' then
        GLink.VendorLib := Lib;
    end);

finalization
  GLink.Free;

end.
