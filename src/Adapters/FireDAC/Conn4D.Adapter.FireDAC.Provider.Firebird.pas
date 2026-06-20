unit Conn4D.Adapter.FireDAC.Provider.Firebird;

{
  Conn4D — Provider FireDAC: Firebird

  Linka o driver físico do Firebird (FireDAC.Phys.FB) e registra um configurador
  que aponta o VendorLib (fbclient.dll) por plataforma, resolvido da config (ou
  do default <exe>\dlls\x86|x64). Inclua na uses da aplicação que usa Firebird:

      uses Conn4D.Adapter.FireDAC.Provider.Firebird;
}

interface

implementation

uses
  System.Classes,
  FireDAC.Phys.FB, 
  FireDAC.Phys.FBDef,
  Conn4D.Core,
  Conn4D.Adapter.FireDAC.Providers,
  Conn4D.Adapter.FireDAC.VendorLib;

var
  GLink: TFDPhysFBDriverLink;

initialization
  GLink := TFDPhysFBDriverLink.Create(nil);
  TFDProviders.Register('FB',
    procedure(const ACfg: IConnConfig)
    var
      Lib: string;
    begin
      Lib := ResolveVendorLib(ACfg, 'fbclient.dll');
      if Lib <> '' then
        GLink.VendorLib := Lib;
    end);

finalization
  GLink.Free;

end.
