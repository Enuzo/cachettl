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

  ## Test-Run Utility
   `Cachettl.MockWeather` provides utility functions that are available
  for emulating the cache operation as part of the test coverage.

  ## Example
  Open two terminals. Lets call them Terminal-1 and Terminal-2
  Run the following lines in the cache project directory:

  ```elixir
  # Terminal-1
  /cache$ iex  --sname server@localhost -S mix
  #=> Erlang/OTP...

  # Terminal-2
  /cache$ iex --sname client@localhost -S mix
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

