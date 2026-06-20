unit Conn4D.Adapter.FireDAC.Provider.MSSQL;

{
  Conn4D — Provider FireDAC: Microsoft SQL Server

  Linka o driver físico do SQL Server (FireDAC.Phys.MSSQL). O MSSQL usa o driver
  ODBC do sistema (msodbcsql), normalmente instalado no SO — não há client lib
  redistribuível padronizada. Por isso o configurador só aponta o VendorLib se o
  app indicar um arquivo .dll EXPLÍCITO (ADefaultFileName='' => sem nome padrão).
  Inclua na uses da aplicação que usa SQL Server:

      uses Conn4D.Adapter.FireDAC.Provider.MSSQL;
}

interface

implementation

uses
  System.Classes,
  FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLDef,
  Conn4D.Core,
  Conn4D.Adapter.FireDAC.Providers,
  Conn4D.Adapter.FireDAC.VendorLib;

var
  GLink: TFDPhysMSSQLDriverLink;

initialization
  GLink := TFDPhysMSSQLDriverLink.Create(nil);
  TFDProviders.Register('MSSQL',
    procedure(const ACfg: IConnConfig)
    var
      Lib: string;
    begin
      Lib := ResolveVendorLib(ACfg, '');
      if Lib <> '' then
        GLink.VendorLib := Lib;
    end);

finalization
  GLink.Free;

end.
