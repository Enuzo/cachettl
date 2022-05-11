  # Cachettl
  `Cachettl` is an implementation of a periodic self-rehydrating TTL cache that resiliently
  handles expensive data-processing ahead of time for fast access.

  The cache mechanism generates 0-arity functions that embed inbound
  data from `store/3`. Each function is registered under a unique key
  along with a TTL("time to live").
  Child processes are assigned to compute the functions at set intervals
  and store the results. The cache is expected to provide the most recently
  computed value whenever `get/1` is called.
  
  ![ttl_cache drawio](https://user-images.githubusercontent.com/35094917/167915091-0b74a38b-5127-4e9d-a6c5-0bfda29453ed.png)

  ## Feature
  - Critical tasks are executed concurrently ensuring quality performance
    without race conditions.
  - Child processes are free from their parent. Instead, they are linked to a
    chain of supervisors on the main application-- ensuring application-wide
    stability and resilience to runtime exceptions.
  - Storage is optimized for concurrent read/write.

  ## Use Case
  - Input data is high-frequency fast-changing queries.
  - Data requires processing that is expensive to compute,
    therefore, data processing must start and be completed
    before it is needed, not when it is being requested for.
  - Data is not frequently accessed, but fast access is guaranteed when needed.
  
  ## Cachettl API
  `Cachettl.get(key)`
  Retrieve the value associated with the specified key.

  If `key` exists in the cache and initial data associated with
  `key` is available, `{:ok, data}` is returned. If data-prccessing
  is in progress on first-run hence the data associated with `key`
  has not been stored, then `{:busy, reason}` is returned.
  If `key` is not present in the cache, `{:error, reason}` is returned.

  Note: Client application calling `Cachettl.get(key)` should be
  responsible for implementing a polling function with a timeout
  mechanism. While this may be rarely needed, it should be
  available in cases where the requested data does not yet exist
  in the cache on initial run.
  
  ###Cachettl.store(key, vaue, ttl // 3_600)
  Add or update existing `value` with its `ttl` in the cache under `key`.
  `ttl` value is expected to be greater than the 
  `refresh_interval` (see `Cachettl.Manager` configuration).
  It is recommended that `ttl` value is divisible by the `refresh_interval`.
  if `ttl` is not given, it defaults to `36_000` seconds(1 hour).

  Note: `ttl` should be specified in seconds, either in `integer` or `decimal`.
  The provided value will convert to milliseconds internally.
  ```elixir
    Cachettl.store("HEL", %{}, 10)
    # internal conversion
    #=> Storage.sec_to_ms(10) == 10_000
    #=> true

    Cachettl.store("HEL", %{}, 10.50)
    # internal conversion
    #=> Storage.sec_to_ms(10.50) == 10_500
    #=> true

    # when ttl is not specified...
    Cachettl.store("HEL", %{})
    # internal conversion
    #=> Storage.sec_to_ms(36_000)
    #=> 36000
  ```
  ## Test-Run Utility
  Launch two terminals(Terminal-1 and Terminal-2).
  Run the following lines in the cachettl project directory:

  ```elixir
  # Terminal-1
  /cachettl$ iex  --sname server@localhost -S mix
  #=> Erlang/OTP...

  # Terminal-2
  /cachettl$ iex --sname client@localhost -S mix
  #=> Erlang/OTP...

  # Treminal-2: connect to :server@localhost
  iex(client@localhost)1> Node.connect(:server@localhost)
  #=> true

  # Terminal-1: verify connection
  iex(server@localhost)1> Node.list()
  #=> [:client@localhost]

  # Terminal-2: verify connection
  iex(client@localhost)2> Node.list()
  #=> [:server@localhost]

  # Terminal-1: use Observer to view performance and structures of running processes
  iex(server@localhost)2> :observer.start()
  #=> ...
  #=> :ok

  # Terminal-1
  iex(server@localhost)3> Cachettl.MockWeather.loop_store()

  # Terminal-2
  iex(client@localhost)3> Node.spawn(:server@localhost, Cachettl.MockWeather, :loop_get, [])

  ```
  Expect to also get exceptions like this:
  ```elixir
  ...[warning] Worker-LUX Terminated. Reason: {%RuntimeError{message: "faking an exception"}...

  ...[error] GenServer {Cachettl.WorkerRegistry, "LUX-worker", :fun_0_arity_processor} terminating
  ** (RuntimeError) faking an exception

  ```
  It is a deliberate part of the test to verify how the `Supervisor`
  handles child-process failure.

