unit Conn4D.Shared.Config;

{
  Conn4D — Shared / Config

  Sub-records de dados (pool e GC). A configuração completa virou uma INTERFACE
  (IConnConfig, em Conn4D.Core) implementada por TConnConfig (em
  Conn4D.Core.Config) — para programar contra abstração, não contra classe.
  Aqui ficam só os holders de dados puros, sem dependência de engine.
}

interface

type
  /// <summary>Configuração do pool de conexões (holder de dados).</summary>
  TConnPoolConfig = record
    MinSize:        Integer;   // default 1
    MaxSize:        Integer;   // default 10
    AcquireTimeout: Cardinal;  // ms — default 5000
    MaxLeaseTime:   Cardinal;  // ms — default 60000 (limite p/ virar zombie)
    IdleTimeout:    Cardinal;  // ms — default 120000 (limite p/ virar idle)
  end;

  /// <summary>Configuração do garbage collector de conexões (holder de dados).</summary>
  TConnGCConfig = record
    Enabled:  Boolean;   // default True
    Interval: Cardinal;  // ms — default 30000
  end;

implementation

end.
