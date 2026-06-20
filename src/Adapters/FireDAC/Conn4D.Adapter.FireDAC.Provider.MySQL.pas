unit Conn4D.Adapter.FireDAC.Provider.MySQL;

{
  Conn4D — Provider FireDAC: MySQL / MariaDB

  Linka o driver físico do MySQL (FireDAC.Phys.MySQL) e registra um configurador
  que aponta o VendorLib (libmysql.dll) por plataforma. Inclua na uses da
  aplicação que usa MySQL/MariaDB:

      uses Conn4D.Adapter.FireDAC.Provider.MySQL;
}

interface

implementation

uses
  System.Classes,
  FireDAC.Phys.MySQL, FireDAC.Phys.MySQLDef,
  Conn4D.Core,
  Conn4D.Adapter.FireDAC.Providers,
  Conn4D.Adapter.FireDAC.VendorLib;

var
  GLink: TFDPhysMySQLDriverLink;

initialization
  GLink := TFDPhysMySQLDriverLink.Create(nil);
  TFDProviders.Register('MySQL',
    procedure(const ACfg: IConnConfig)
    var
      Lib: string;
    begin
      Lib := ResolveVendorLib(ACfg, 'libmysql.dll');
      if Lib <> '' then
        GLink.VendorLib := Lib;
    end);

finalization
  GLink.Free;

end.
