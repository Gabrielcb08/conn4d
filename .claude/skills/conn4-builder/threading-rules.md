# Conn4D — Regras de concorrência e prevenção de deadlock

Leia este arquivo antes de escrever qualquer código que toque estado compartilhado (pool, contexto por thread, GC).

## Modelo geral

Estado mutável é centralizado num único componente, `TConnPoolStore`. Quanto menos lugares mutam estado, menos superfícies de corrida existem. Nada fora do `TConnPoolStore` altera as listas de conexão diretamente.

Componentes de sincronização:

| Componente | Papel | Primitiva |
|---|---|---|
| `TConnSemaphore` | Limita threads simultâneas a `poolSize` | `CreateSemaphore` (Win) / `sem_t` (Posix) |
| `TConnPoolStore` | Guarda `AvailableList` + `InUseMap` | `TCriticalSection` |
| `TConnThreadSafeQueue<T>` | Fila FIFO de espera, sem busy-wait | `TCriticalSection` + `TEvent` |
| `TConnThreadContextStore` | Isola contexto por TID | `TMonitor` / `TSpinLock` (leituras curtas) |

## Ordem fixa de aquisição de locks

Esta é a garantia estrutural contra deadlock. Deadlock só ocorre quando há ciclo de espera entre locks adquiridos em ordens diferentes por threads diferentes. Fixando uma única ordem global, o ciclo é impossível.

Ordem obrigatória, sempre:

```
1. FSemaphore.Wait
2. FPoolLock.Enter      // TCriticalSection do TConnPoolStore
3. FContextLock.Enter   // TConnThreadContextStore
```

Regras derivadas:
- Nunca adquira `FPoolLock` antes do semáforo.
- Nunca adquira `FContextLock` antes de `FPoolLock`.
- Nunca segure dois locks fora desta ordem.
- Libere na ordem inversa da aquisição (`FContextLock.Leave` → `FPoolLock.Leave` → `FSemaphore.Release`), sempre em `try..finally`.

Exemplo de aquisição correta:

```pascal
function TConnPoolManager.Acquire(const ATimeoutMs: Cardinal): TObject;
begin
  if not FSemaphore.WaitFor(ATimeoutMs) then
    raise EConn4DTimeoutException.CreateFmt(
      'Acquire timeout after %d ms (pool exhausted)', [ATimeoutMs]);
  try
    FPoolLock.Enter;
    try
      Result := FStore.TakeAvailableOrCreate;   // muta AvailableList/InUseMap
    finally
      FPoolLock.Leave;
    end;
    FContextLock.Enter;
    try
      FContext.Bind(TThread.CurrentThread.ThreadID, Result);
    finally
      FContextLock.Leave;
    end;
  except
    FSemaphore.Release;   // devolve permissão se algo falhou após o Wait
    raise;
  end;
end;
```

## GC nunca disputa lock com thread de negócio

O `TConnGarbageCollector` roda numa `TThread` própria. Para não travar quem está trabalhando:

1. Adquire `FPoolLock` por tempo curtíssimo só para **capturar snapshot** (cópia das referências e timestamps).
2. Libera o lock imediatamente.
3. Avalia o snapshot **sem lock** (decide quem é idle/zombie).
4. Reentra com `FPoolLock` só para **remover** os marcados.
5. Chama `IConnEngine.DestroyNative` **fora** de qualquer lock — fechar socket pode bloquear e jamais deve acontecer com lock segurado.

```pascal
procedure TConnGarbageCollector.RunOnce;
var
  Snapshot: TArray<TConnEntry>;
  Victim:   TConnEntry;
  ToKill:   TList<TObject>;
begin
  ToKill := TList<TObject>.Create;
  try
    FPoolLock.Enter;
    try
      Snapshot := FStore.SnapshotAll;          // cópia rápida
    finally
      FPoolLock.Leave;                          // lock curto
    end;

    for Victim in Snapshot do                   // avaliação SEM lock
      if IsIdle(Victim) or IsZombie(Victim) then
        ToKill.Add(Victim.Native);

    FPoolLock.Enter;
    try
      FStore.RemoveMany(ToKill);                // remoção sob lock curto
    finally
      FPoolLock.Leave;
    end;

    for var Native in ToKill do                 // destruição FORA do lock
      FEngine.DestroyNative(Native);
  finally
    ToKill.Free;
  end;
end;
```

## Relógio injetável para testes determinísticos

Nunca use `Now`/`GetTickCount` diretamente dentro da lógica de idle/zombie. Injete `IConnClock`. Em produção, a implementação retorna o relógio real; em testes, um mock avança o tempo manualmente — assim os testes de GC rodam sem `Sleep` e sem flakiness.

```pascal
IConnClock = interface
  function NowMs: Int64;
end;

// Teste:
FClock.Advance(70000);   // simula 70s
FGC.RunOnce;
Assert.AreEqual(0, FPool.IdleCount);
```

## Checklist antes de finalizar código concorrente

- Toda escrita no pool está sob `TCriticalSection`? 
- A ordem de locks da seção 2 foi respeitada?
- Há `try..finally` garantindo liberação de cada lock e do semáforo?
- O GC fecha conexões fora do lock?
- A lógica de tempo usa `IConnClock`, não `Now` direto?
- `Acquire` respeita `AcquireTimeout` e lança em vez de travar?
- Existe teste de stress com N > poolSize threads validando as invariantes?
