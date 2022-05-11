defmodule Cachettl.MockWeather do
  @moduledoc """
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
  """

  require Logger

  alias __MODULE__

  data = fn ->
    %{
      "temp" => (-24..100 |> Enum.random()) + Enum.random(101..900) / 100,
      "pressure" => Enum.random(100..10_000),
      "humidity" => Enum.random(1..400),
      "visibility" => Enum.random(1000..10_000),
      "date" => DateTime.now!("Etc/UTC")
    }
  end

  defstruct weather: [
              %{"id" => "TIA", "city" => "Tirana", "main" => data.()},
              %{"id" => "EVN", "city" => "Yerevan", "main" => data.()},
              %{"id" => "VIE", "city" => "Vienna", "main" => data.()},
              %{"id" => "BAK", "city" => "Baku", "main" => data.()},
              %{"id" => "MSQ", "city" => "Minsk", "main" => data.()},
              %{"id" => "BRU", "city" => "Brussels", "main" => data.()},
              %{"id" => "SJJ", "city" => "Sarajevo", "main" => data.()},
              %{"id" => "SOF", "city" => "Sofia", "main" => data.()},
              %{"id" => "ZAG", "city" => "Zagreb", "main" => data.()},
              %{"id" => "NIC", "city" => "Nicosia", "main" => data.()},
              %{"id" => "PRG", "city" => "Prague", "main" => data.()},
              %{"id" => "CPH", "city" => "Copenhagen", "main" => data.()},
              %{"id" => "TLL", "city" => "Tallinn", "main" => data.()},
              %{"id" => "HEL", "city" => "Helsinki", "main" => data.()},
              %{"id" => "PAR", "city" => "Paris", "main" => data.()},
              %{"id" => "BER", "city" => "Berlin", "main" => data.()},
              %{"id" => "TBS", "city" => "Tbilisi", "main" => data.()},
              %{"id" => "ATH", "city" => "Athens", "main" => data.()},
              %{"id" => "BUD", "city" => "Budapest", "main" => data.()},
              %{"id" => "REK", "city" => "Reykjavik", "main" => data.()},
              %{"id" => "DUB", "city" => "Dublin", "main" => data.()},
              %{"id" => "ROM", "city" => "Rome", "main" => data.()},
              %{"id" => "RIX", "city" => "Riga", "main" => data.()},
              %{"id" => "VNO", "city" => "Vilnius", "main" => data.()},
              %{"id" => "LUX", "city" => "Luxembourg", "main" => data.()},
              %{"id" => "MLA", "city" => "Malta", "main" => data.()},
              %{"id" => "KIV", "city" => "Chisinau", "main" => data.()},
              %{"id" => "TGD", "city" => "Podgorica", "main" => data.()},
              %{"id" => "AMS", "city" => "Amsterdam", "main" => data.()},
              %{"id" => "OSL", "city" => "Oslo", "main" => data.()},
              %{"id" => "WAW", "city" => "Warsaw", "main" => data.()},
              %{"id" => "LIS", "city" => "Lisbon", "main" => data.()},
              %{"id" => "BUH", "city" => "Bucharest", "main" => data.()},
              %{"id" => "MOW", "city" => "Moscow", "main" => data.()},
              %{"id" => "LJU", "city" => "Ljubljana", "main" => data.()},
              %{"id" => "BTS", "city" => "Bratislava", "main" => data.()},
              %{"id" => "MAD", "city" => "Madrid", "main" => data.()},
              %{"id" => "STO", "city" => "Stockholm", "main" => data.()},
              %{"id" => "BRN", "city" => "Bern", "main" => data.()},
              %{"id" => "ANK", "city" => "Ankara", "main" => data.()},
              %{"id" => "IEV", "city" => "Kiev", "main" => data.()},
              %{"id" => "LON", "city" => "London", "main" => data.()},
              %{"id" => "BEG", "city" => "Belgrade", "main" => data.()}
            ]

  @spec loop_store() :: no_return
  @doc """
  `loop_store/0` calls `Cachettl.store/3` in a recursive
  loop that mimics periodic fast data queries. It runs every second,
  takes random keys/value that represents mock-weather
  data by cities, and generated TTL in the range of 30 - 60 seconds
  as arguments on every call.
  """
  def loop_store() do
    Process.sleep(1000)

    wmap = %MockWeather{}

    map =
      0..(Enum.count(wmap.weather) - 1)
      |> Enum.random()
      |> then(fn index -> Enum.at(wmap.weather, index) end)

    Cachettl.store(Map.get(map, "id"), map, rand_ttl())

    loop_store()
  end

  @spec single_loop_store() :: no_return
  @doc """
  `loop_store_single/0` same as `loop_store/0`
  but takes a single key/value as argument on every call.
  """
  def single_loop_store() do
    Process.sleep(1000)

    case Cachettl.store(
           "HEL",
           %{
             "id" => "HEL",
             "city" => "Helsinki",
             "main" => %{
               "temp" => (-24..100 |> Enum.random()) + Enum.random(101..900) / 100,
               "pressure" => Enum.random(100..10_000),
               "humidity" => Enum.random(1..400),
               "visibility" => Enum.random(1000..10_000)
             }
           },
           rand_ttl()
         ) do
      {:error, reason} ->
        Logger.warning("Problem caching data. Reason: #{reason}\n")

      _ ->
        :ok
    end

    single_loop_store()
  end

  @spec loop_get() :: no_return
  @doc """
  `loop_get/0` calls `Cachettl.get/1` in a recursive loop
  that mimics infrequent data retrieval. It runs every 6 seconds and
  takes a random key as an argument on every call.

  """
  def loop_get() do
    Process.sleep(6_000)
    wmap = %MockWeather{}

    map =
      0..(Enum.count(wmap.weather) - 1)
      |> Enum.random()
      |> then(fn index -> Enum.at(wmap.weather, index) end)

    IO.puts("DATA IS: #{inspect(Cachettl.get(Map.get(map, "id")))}\n")

    loop_get()
  end

  @spec loop_get_single :: no_return
  @doc """
  `loop_get_single/0` same as `loop_get/0`
  but takes the same key as argument on every call.
  """
  def loop_get_single() do
    Process.sleep(6_000)

    IO.puts("DATA IS: #{inspect(Cachettl.get("HEL"))}\n")

    loop_get_single()
  end

  defp rand_ttl, do: Enum.random(30..60)

  @spec generate_0_arity_fun(any) :: (() -> {:error, binary} | {:ok, any})
  @doc """
    `generate_0_arity_fun/1` generates a 0-arity function that embeds
    `value` which is to be computed at a later time. The 0-arity mimics
    an expensive data processing that takes a range of 2 - 4 seconds to complete.
    Result is designed to return `{:ok, data}` or `{:error, reason}`,
    or `raise/1` as part of the test.

    Note:
    You are not expected to call this function directly.
  """
  def generate_0_arity_fun(value) do
    fn ->
      2_000..4_000 |> Enum.random() |> Process.sleep()

      case Enum.random(0..4) do
        4 ->
          {:ok, value}

        3 ->
          {:ok, value}

        2 ->
          {:ok, value}

        1 ->
          {:error, "error computing value"}

        0 ->
          raise("faking an exception")
      end
    end
  end
end
