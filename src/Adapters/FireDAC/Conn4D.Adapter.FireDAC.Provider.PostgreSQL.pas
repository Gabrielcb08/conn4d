unit Conn4D.Adapter.FireDAC.Provider.PostgreSQL;

{
  Conn4D — Provider FireDAC: PostgreSQL

  Linka o driver físico do PostgreSQL (FireDAC.Phys.PG) e registra um
  configurador que aponta o VendorLib (libpq.dll) por plataforma. Inclua na uses
  da aplicação que usa PostgreSQL:

      uses Conn4D.Adapter.FireDAC.Provider.PostgreSQL;
}

interface

implementation

uses
  System.Classes,
  FireDAC.Phys.PG, FireDAC.Phys.PGDef,
  Conn4D.Core,
  Conn4D.Adapter.FireDAC.Providers,
  Conn4D.Adapter.FireDAC.VendorLib;

var
  GLink: TFDPhysPgDriverLink;

initialization
  GLink := TFDPhysPgDriverLink.Create(nil);
  TFDProviders.Register('PG',
    procedure(const ACfg: IConnConfig)
    var
      Lib: string;
    begin
      Lib := ResolveVendorLib(ACfg, 'libpq.dll');
      if Lib <> '' then
        GLink.VendorLib := Lib;
    end);

finalization
  GLink.Free;

end.
