unit Conn4D.Core.Clock;

{
  Conn4D — Core / Abstractions / Clock

  IConnClock: relógio injetável (ver references/threading-rules.md). A lógica de
  idle/zombie NUNCA chama Now/GetTickCount direto — sempre IConnClock.NowMs.
  Em produção, retorna o relógio real; em testes, um mock avança o tempo
  manualmente, tornando os testes de GC determinísticos e sem Sleep.
}

interface

type
  /// <summary>Fonte de tempo monotônica em milissegundos, injetável.</summary>
  IConnClock = interface
    ['{D1A4F0E1-0000-0000-0000-000000000009}']
    /// <summary>Tempo atual em ms. Base arbitrária; só diferenças importam.</summary>
    function NowMs: Int64;
  end;

implementation

end.
