unit Conn4D.Adapter.FireDAC.VCL;

{
  Conn4D — Adapter / FireDAC / Bootstrap VCL (auto-link)

  Unit de "baterias inclusas" para aplicações VCL. Ao ser linkada, registra de
  uma vez TODA a infraestrutura FireDAC que um app precisa em runtime:

    1. WAIT-CURSOR (GUIx) para VCL — sem isso, abrir conexão dispara
       [FireDAC][UI]-101.
    2. Infra de conexão (Stan.* / DApt) usada por TFDConnection/TFDQuery.
    3. Os DRIVERS por provider (FireDAC.Phys.*), via as provider units do Conn4D,
       que ainda resolvem o VendorLib (fbclient.dll/libpq.dll/...) por plataforma.

  Não há símbolos a usar — o efeito é puramente de LINK (as units abaixo se
  auto-registram nas suas initialization).

  Como é linkada: o adapter (Conn4D.Adapter.FireDAC) inclui esta unit na sua
  implementation, a menos que o símbolo CONN4D_NOAUTOLINK esteja definido (usado
  no build do pacote runtime e dos testes, que devem ficar agnósticos de UI/driver).
  Assim, um app que faz `uses Conn4D.Adapter.FireDAC;` (ou `uses Conn4D;`) recebe
  tudo automaticamente, sem precisar listar drivers nem wait-cursor.

  Para outros frameworks, troque o provedor de wait abaixo:
     - Console: FireDAC.ConsoleUI.Wait
     - FMX:     FireDAC.FMXUI.Wait
}

interface

implementation

uses
  // --- Infra de conexão + wait-cursor (VCL) ---
  FireDAC.UI.Intf,        // contrato do provedor de UI
  FireDAC.VCLUI.Wait,     // provedor de wait-cursor (GUIx) para VCL
  FireDAC.Comp.UI,        // TFDGUIxWaitCursor (link da UI)
  FireDAC.Stan.Def,       // definições de driver/conexão
  FireDAC.Stan.Async,     // execução assíncrona/timeout
  FireDAC.DApt,           // data adapter (necessário p/ TFDQuery buscar dados)
  // --- Drivers por provider (cada um linka seu FireDAC.Phys.* e resolve o VendorLib) ---
  Conn4D.Adapter.FireDAC.Provider.Firebird,
  Conn4D.Adapter.FireDAC.Provider.SQLite,
  Conn4D.Adapter.FireDAC.Provider.PostgreSQL,
  Conn4D.Adapter.FireDAC.Provider.MySQL,
  Conn4D.Adapter.FireDAC.Provider.MSSQL;

end.
