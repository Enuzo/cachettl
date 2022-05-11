defmodule Cachettl.Storage do
  @moduledoc false

  # Helpers for:
  # * Creating ETS storage, retrieving the reference for the table.
  # * Setting and fetching the Refresh Interval.

  # The ETS table reference and the Refresh Interval value are both written in a global
  # [':persistent_term](https://www.erlang.org/doc/man/persistent_term.html) for faster read-access
  # for all the cache processes.

  # Data object shape:
  # {key, zero_arity_function, computed_value, timestamp, status}

  ## PERSISTENT TERM
  @spec set_refresh_interval(non_neg_integer()) :: :ok

  # Convert the value of refresh interval from seconds to milliseconds
  # and save in :persistent_term.
  def set_refresh_interval(interval_sec) when is_number(interval_sec) do
    {__MODULE__, :refresh_global}
    |> :persistent_term.put(sec_to_ms(interval_sec))
  end

  @spec get_refresh_interval :: non_neg_integer

  # Get refresh interval fro the :persistent_term.
  def get_refresh_interval() do
    {__MODULE__, :refresh_global}
    |> :persistent_term.get()
  end

  @spec ets :: :ok

  # Create ETS table and save the table reference in :persistent_term
  def ets() do
    tid =
      :ets.new(__MODULE__, [
        :set,
        :public,
        write_concurrency: true,
        read_concurrency: true
      ])

    :persistent_term.put({__MODULE__, :ets_global}, tid)
  end

  @spec table :: any

  #  Get ETS table refrence.
  def table() do
    :persistent_term.get({__MODULE__, :ets_global})
  end

  @spec sec_to_ms(number) :: integer

  # Convert seconds to milliseconds. Argument could be in decimal:
  # sec_to_ms(12.52) == 12520
  def sec_to_ms(seconds) do
    trunc(seconds * 1000)
  end
end
