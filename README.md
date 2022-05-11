  `Cachettl` is an implementation of a periodic self-rehydrating TTL cache that resiliently
  handles expensive data-processing ahead of time for fast access.

  The cache mechanism generates 0-arity functions that embed inbound
  data from `store/3`. Each function is registered under a unique key
  along with a TTL("time to live").
  Child processes are assigned to compute the functions at set intervals
  and store the results. The cache is expected to provide the most recently
  computed value whenever `get/1` is called.

  ## Feature
  - Critical tasks are executed concurrently ensuring quality performance
    without race conditions.
  - Child processes are free from their parent. Instead, they are linked to a
    chain of supervisors to the main application-- ensuring application-wide
    stability with data-processing workers resilient to runtime exceptions.
  - Storage is optimized for concurrent read/write.

  ## Use Case
  - Input data is high-frequency fast-changing queries.
  - Data requires processing that is expensive to compute,
    therefore, data processing must start and be completed
    before it is needed, not when it is being requested for.
  - Data is not frequently accessed, but fast access is guaranteed when needed.

  ## Test-Run Utility
  See `Cachettl.MockWeather`

