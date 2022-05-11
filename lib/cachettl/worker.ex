defmodule Cachettl.Worker do
  @moduledoc false

  # Cachettl.Worker defines a supervised process that computes a
  # given 0-arity function then stores the resulting value in the
  # ETS at a set interval. The worker keeps running in a compute/store
  # cycle, as long as a new 0-arity function is updated with fresh data.
  # Otherwise, a TTL timeframe is reached - causing the periodic loop to
  # exit, stale data object is cleared from the ETS table, and the worker
  # process terminates with a clean shutdown.

  # TTL is expected to be a multiple of the Refresh Interval. That is, if:
  # refresh_interval = 600_000
  # ttl = 3_600_000
  # div(ttl, refresh_interval ) == 6
  # then TTL check will occur after 6 refresh interval cycles. This timing
  # strategy enables the process to use only a single counter for both the
  # Refresh Interval and the TTL.

  # ## Functionality:
  # handle_continue({:setup, config}) one-time configuration that sets
  # up the initial timestamp for the TTL and Refresh Interval. The
  # Cachettl.Worker detects new updates by comparing timestamps at certain
  # intervals.

  # handle_continue(:timer, config) runs the timer for the refresh interval.
  # The timer is set to the refresh_interval value stored in a global
  # :pesistent_term. All worker processes created use the same internal value.

  # handle_info(:compute, config) computes the 0-arity function and stores
  # its value in the ETS. This callback also performs data update checks and TTL
  # checks. If no new data is available and the TTL check returns false, no
  # computation is done, instead, the process is routed to
  # handle_continue(:timer, config) for another run. If TTL returns true,
  # the stale data object is deleted from the ETS and a shutdown signal is sent
  # to 'Cachettl.Manager' to terminate the expired process from a DynamicSupervisor.



  use GenServer, restart: :transient

  require Logger

  alias Cachettl.Storage

  # @key 1
  @fun 2
  @value 3
  @timestamp 4
  @status 5

  @spec start_link(map) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: worker_name(config.key))
  end

  @impl true
  def init(config) do
    Process.flag(:trap_exit, true)
    {:ok, config, {:continue, :setup}}
  end

  ## FIRST_RUN
  @impl true
  def handle_continue(:setup, config) do
    Logger.info("Worker-#{inspect(config.key)}is online\n")
    timestamp = :ets.lookup_element(Storage.table(), config.key, @timestamp)

    {
      :noreply,
      %{config | ttl_stamp: timestamp, refresh_stamp: timestamp},
      {:continue, :timer}
    }
  end

  def handle_continue(:timer, config) do
    Logger.info("Worker-#{inspect(config.key)} ::TIMER\n")
    Process.send_after(self(), :compute, Storage.get_refresh_interval())

    {:noreply, config}
  end

  ## COMPUTE
  @impl true
  def handle_info(:compute, config) do
    Logger.info("Worker-#{inspect(config.key)} ::COMPUTE?\n")
    ref_interval = Storage.get_refresh_interval()

    with true <- parity?(ref_interval, config.counter, config),
         {true, _timestamp} <- ttl_expired?(config),
         true <- :ets.delete(Storage.table(), config.key) do
      Logger.info("Worker-#{inspect(config.key)} ::TIME_TO_GO\n")
      send(Cachettl.Manager, {:terminate, config.supervisor_pid})

      {:stop, :normal, config}
    else
      false ->
        Logger.info("Worker-#{inspect(config.key)} ::PARITY_FALSE -> COMPUTE\n")
        {_status, timestamp} = compute_function(config)

        {
          :noreply,
          %{config | refresh_stamp: timestamp, counter: config.counter + 1},
          {:continue, :timer}
        }

      {false, _timestamp} ->
        Logger.info("Worker-#{inspect(config.key)} ::TTL_FALSE -> COMPUTE\n")
        {_status, timestamp} = compute_function(config)

        {
          :noreply,
          %{config | ttl_stamp: timestamp, refresh_stamp: timestamp, counter: 0},
          {:continue, :timer}
        }
    end
  end

  ## TERMINATE
  @impl true
  def terminate(reason, config) do
    case reason do
      :normal ->
        Logger.warning(
          "Worker-#{config.key} Terminated. Reason: TTL has expired. Status: #{inspect(reason)}\n"
        )

      :shutdown ->
        Logger.warning("Worker-#{config.key} Terminated. Reason: - #{inspect(reason)}\n")

      _ ->
        Logger.warning("Worker-#{config.key} Terminated. Reason: #{inspect(reason)}\n")
    end

    # send(Cachettl.Manager, {:terminate, config.supervisor_pid})
  end

  ## Helpers

  # Check if the number of refresh intervals coresponds to TTL.
  # If  mulitiple value of refresh interval is not used for TTL, precision is
  # not guaranteed as refresh interval counter might return an accumulated
  # value slighter higher than the TTL by a few miiiseconds. This is not a problem.
  defp parity?(refresh_interval, refresh_count, config) do
    steps =
      if refresh_count === 0,
        do: refresh_interval,
        else: refresh_interval * refresh_count

    if steps >= config.ttl, do: true, else: false
  end

  # Compare timestamps to determine if the last computed data has become
  # obsolete due to lack of timely update.
  defp ttl_expired?(config) do
    timestamp = :ets.lookup_element(Storage.table(), config.key, @timestamp)

    if timestamp == config.ttl_stamp,
      do: {true, timestamp},
      else: {false, timestamp}
  end

  # Compute the expensive 0-arity function only if new data is available. If
  # new data is available, processed data is saved in ETS only if
  # the computation is successful, otherwise if :error is returned, nothing is saved.
  defp compute_function(config) do
    status =
      config
      |> refresh_timestamp_equal?()
      |> compute_function(config)

    {status, :ets.lookup_element(Storage.table(), config.key, @timestamp)}
  end

  defp compute_function(true, _config) do
    :noop
  end

  defp compute_function(false, config) do
    function_0_arity = :ets.lookup_element(Storage.table(), config.key, @fun)

    case function_0_arity.() do
      {:ok, value} ->
        :ets.update_element(Storage.table(), config.key, [{@value, value}, {@status, :ready}])
        :ok

      {:error, _reason} ->
        :error
    end
  end

  # Compare timestamps. This helps determine if new data is available
  # for processing or not.
  defp refresh_timestamp_equal?(config) do
    timestamp = :ets.lookup_element(Storage.table(), config.key, @timestamp)

    timestamp === config.refresh_stamp
  end

  # Register a unique name for each spawned Process.
  defp worker_name(key) do
    {:via, Registry, {Cachettl.WorkerRegistry, to_string(key) <> "-worker", :fun_0_arity_processor}}
  end
end
