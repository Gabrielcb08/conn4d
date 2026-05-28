unit Conn4D.Application.PoolRegistry;

interface

uses
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Conn4D.Domain.PoolConfig,
  Conn4D.Application.Contracts.IProvider,
  Conn4D.Application.Contracts.IPool;

type
  TConn4DPoolRegistry = class
  private
    FPools     : TDictionary<string, IConn4DPool>;
    FProviders : TList<IConn4DProvider>;
    FLock      : TObject;
    FSweeper   : TThread;

    class var FInstance : TConn4DPoolRegistry;
    class var FInstLock : TCriticalSection;

    function NormalizeKey(const AName : string) : string;
    function ResolveProvider(const ADriverID : string) : IConn4DProvider;
    procedure StartSweeperIfNeeded;

    class constructor ClassSetup;
    class destructor ClassTeardown;

    constructor Create;
  public
    destructor Destroy; override;
    class function Instance : TConn4DPoolRegistry;

    // Registers a new pool using the provider that matches AConfig.DriverID.
    // Raises EConn4DConfigException if a pool with that name is already registered.
    procedure RegisterPool(const AConfig : TConn4DPoolConfig);

    function GetPool(const AName : string) : IConn4DPool;
    function PoolExists(const AName : string) : Boolean;

    // Unregisters and destroys the pool. Returns False if not found.
    function UnregisterPool(const AName : string) : Boolean;

    // Destroys all pools and stops the sweeper. Used in tests and shutdown.
    procedure Clear;

    // Registers an additional provider (e.g. a second DB engine).
    // The first registered provider is the default for all DriverIDs it claims.
    procedure RegisterProvider(const AProvider : IConn4DProvider);

    // Sweeps all registered pools that are due.
    function SweepAll : Integer;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Domain.Exceptions,
  Conn4D.Application.Pool;

{ TConn4DPoolRegistry }

class constructor TConn4DPoolRegistry.ClassSetup;
begin
  FInstLock := TCriticalSection.Create;
end;

class destructor TConn4DPoolRegistry.ClassTeardown;
begin
  FreeAndNil(FInstance);
  FreeAndNil(FInstLock);
end;

class function TConn4DPoolRegistry.Instance : TConn4DPoolRegistry;
begin
  if not Assigned(FInstance) then
  begin
    FInstLock.Acquire;
    try
      if not Assigned(FInstance) then
        FInstance := TConn4DPoolRegistry.Create;
    finally
      FInstLock.Release;
    end;
  end;
  Result := FInstance;
end;

constructor TConn4DPoolRegistry.Create;
begin
  inherited;
  FPools     := TDictionary<string, IConn4DPool>.Create;
  FProviders := TList<IConn4DProvider>.Create;
  FLock      := TObject.Create;
end;

destructor TConn4DPoolRegistry.Destroy;
begin
  Clear;
  FProviders.Free;
  FPools.Free;
  FLock.Free;
  inherited;
end;

function TConn4DPoolRegistry.NormalizeKey(const AName : string) : string;
begin
  Result := LowerCase(Trim(AName));
end;

function TConn4DPoolRegistry.ResolveProvider(const ADriverID : string) : IConn4DProvider;
var
  P : IConn4DProvider;
begin
  TMonitor.Enter(FLock);
  try
    for P in FProviders do
      if P.Supports(ADriverID) then
        Exit(P);
  finally
    TMonitor.Exit(FLock);
  end;

  raise EConn4DConfigException.CreateFmt('No provider registered for DriverID "%s". ' + 'Call TConn4D.RegisterProvider before registering pools.', [ADriverID]);
end;

procedure TConn4DPoolRegistry.RegisterPool(const AConfig : TConn4DPoolConfig);
var
  Key      : string;
  Provider : IConn4DProvider;
  Pool     : IConn4DPool;
begin
  Key      := NormalizeKey(AConfig.PoolName);
  Provider := ResolveProvider(AConfig.DriverID);
  Pool     := TConn4DPool.Create(AConfig, Provider);

  TMonitor.Enter(FLock);
  try
    if FPools.ContainsKey(Key) then
      raise EConn4DConfigException.CreateFmt('Pool "%s" is already registered.', [AConfig.PoolName]);
    FPools.Add(Key, Pool);
  finally
    TMonitor.Exit(FLock);
  end;

  StartSweeperIfNeeded;
end;

function TConn4DPoolRegistry.GetPool(const AName : string) : IConn4DPool;
var
  Key : string;
begin
  Key := NormalizeKey(AName);
  TMonitor.Enter(FLock);
  try
    if not FPools.TryGetValue(Key, Result) then
      raise EConn4DPoolNotFoundException.CreateFmt('Pool "%s" is not registered.', [AName]);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TConn4DPoolRegistry.PoolExists(const AName : string) : Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FPools.ContainsKey(NormalizeKey(AName));
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TConn4DPoolRegistry.UnregisterPool(const AName : string) : Boolean;
var
  Key : string;
begin
  Key := NormalizeKey(AName);
  TMonitor.Enter(FLock);
  try
    Result := FPools.ContainsKey(Key);
    if Result then
      FPools.Remove(Key);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TConn4DPoolRegistry.Clear;
begin
  if Assigned(FSweeper) then
  begin
    FSweeper.Terminate;
    FSweeper.WaitFor;
    FreeAndNil(FSweeper);
  end;

  TMonitor.Enter(FLock);
  try
    FPools.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TConn4DPoolRegistry.RegisterProvider(const AProvider : IConn4DProvider);
begin
  TMonitor.Enter(FLock);
  try
    FProviders.Add(AProvider);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TConn4DPoolRegistry.SweepAll : Integer;
var
  Pools : TArray<IConn4DPool>;
  P     : IConn4DPool;
begin
  TMonitor.Enter(FLock);
  try
    Pools := FPools.Values.ToArray;
  finally
    TMonitor.Exit(FLock);
  end;

  Result := 0;
  for P in Pools do
    Inc(Result, P.SweepIfDue);
end;

procedure TConn4DPoolRegistry.StartSweeperIfNeeded;
begin
  TMonitor.Enter(FLock);
  try
    if Assigned(FSweeper) then
      Exit;

    FSweeper := TThread.CreateAnonymousThread(
      procedure
      begin
        while not TThread.CurrentThread.CheckTerminated do
        begin
          Sleep(250);
          if TThread.CurrentThread.CheckTerminated then
            Break;
          try
            SweepAll;
          except
          end;
        end;
      end);
    FSweeper.FreeOnTerminate := False;
    FSweeper.Start;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
