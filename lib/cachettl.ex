defmodule Cachettl do
  @moduledoc """
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

  """

  alias Cachettl.{Manager, Storage}

  @value 3
  @status 5

  @type get_returns ::
          {:busy, String.t()}
          | {:error, String.t()}
          | {:ok, any}

  @spec store(atom | number | binary, any, number) :: :ok | {:error, any}
  @doc """
    Add new or update existing `value` with its `ttl` in the cache under `key`.

    `ttl` value is expected to be greater than the
    `refresh_interval` (see `Cachettl.Manager` configuration).
    It is recommended that `ttl` value is divisible by the `refresh_interval`.
    if `ttl` is not given, it defaults to `36_000` seconds(1 hour).

    `ttl` should be specified in seconds, either in `integer` or `decimal`.
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
    #=> Storage.sec_to_ms(3_600)
    #=> 3_600_000

    ```
  """

  def store(key, value, ttl \\ 3_600) when is_number(ttl) and ttl > 0 do
    refresh = Storage.get_refresh_interval()
    ttl_sec = Storage.sec_to_ms(ttl)

    case {refresh, ttl_sec} do
      {refresh, ttl_sec} when refresh >= ttl_sec ->
        {:error, "TTL too low. Should be greater than refresh_interval: #{refresh}ms"}

      _ ->
        GenServer.call(Manager, {:store, {key, value, ttl_sec}})
    end
  end

  @spec get(atom | number | binary) :: get_returns()
  @doc """
  `get/1`
  Retrieve the value for a specified key from the cache.

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
  """
  def get(key) do
    case :ets.member(Storage.table(), key) do
      true ->
        case :ets.lookup_element(Storage.table(), key, @status) do
          :busy ->
            {:busy, "data is not ready"}

          _ ->
            {:ok, :ets.lookup_element(Storage.table(), key, @value)}
        end

      false ->
        {:error, "data with the given key #{key} is not yet available"}
    end
  end
end
