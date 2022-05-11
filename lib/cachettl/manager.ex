defmodule Cachettl.Manager do
  @moduledoc false

  # This module defines a supervised GenServer process that coordinates
  # inbound data to the cache and manages its child-processes lifecycle.

  # Functionality:

  # handle_continue(:setup, config) to set up ETS storage.

  # handle_call({:store, args}, from, config) spawn one or several
  # Task.Supervisor processes. Each of these processes wraps a given inbound
  # data object in a 0-arity function. The number of spawned processes is
  # equivalent to the number of unique data objects. If a stale version of a
  # data object already exists in the  ETS table, the table is updated with the
  # new 0-arity function.

  # handle_info({ref, result}, config) receive the unprocessed data embedded
  # in 0-arity functions, then dynamically spawn supervised worker processes to
  # handle the computation cycles and storage of each unique data object embedded
  # in the 0-arity functions.

  # handle_info({ref, result}, config) receives the results of
  # handle_call({:store, args}, from, config). If an update occurred, :ok message
  # is returned to the caller, otherwise, new supervised worker processes are
  # dynamically created to handle the computation/storage cycles of each unique data
  # object embedded in the 0-arity functions.

  # handle_info({:DOWN, _ , _ , _ , reason}, config) receives error result if it
  # occurs in any Task process spawned by handle_call({:store, args}, from, config).
  # Error message is sent to the caller.

  # handle_info({:terminate, supervisor_pid}, config) shuts down worker processes
  # with obsolete data, after TTL expiration.

  # All processes created by the Cachettl.Manager are linked only to the main
  # Application Supervisor, not to the Cachettl.Manager.

  use GenServer

  require Logger

  alias Cachettl.{Storage, MockWeather}
  @fun 2
  @timestamp 4

  defstruct caller: nil,
            key: nil,
            supervisor_pid: nil,
            ttl: nil,
            counter: 0,
            interval: 4,
            ttl_stamp: {},
            refresh_stamp: {}

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}

  def start_link(_) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @impl true
  def init(config), do: {:ok, config, {:continue, :setup}}

  @impl true
  def handle_continue(:setup, config) do
    :ok = Storage.set_refresh_interval(config.interval)
    :ok = Storage.ets()

    {:noreply, config}
  end

  @impl true
  def handle_call({:store, {key, value, ttl}}, from, config) do
    value
    |> MockWeather.generate_0_arity_fun()
    |> update_or_create_async(key, ttl, from)

    {:noreply, %{config | key: key, caller: from}}
  end

  # Cleanly shutdown a worker process when it's TTL expires.
  def handle_info({:terminate, work_visor_pid}, config) do
    terminate_worker_async(work_visor_pid)

    {:noreply, config}
  end

  # Collect result If the :store task succeeds in updating or creating a new ETS object.
  @impl true
  def handle_info({ref, result}, config) do
    # Stop the monitoring the completed task and clear the DOWN message.
    Process.demonitor(ref, [:flush])

    case result do
      {:updated, key, from} ->
        GenServer.reply(from, :ok)
        Logger.info("UPDATED : #{key}\n")

      {:new, key, ttl, from} ->
        GenServer.reply(from, :ok)
        Logger.info("NEW : #{key}\n")

        DynamicSupervisor.start_child(Cachettl.MasterVisor, {
          Cachettl.WorkerVisor,
          %{config | key: key, ttl: ttl}
        })
    end

    {:noreply, config}
  end

  # Send error message to the caller if the :store async job fails.
  def handle_info({:DOWN, _ref, _proc, _pid2, reason}, config) do
    GenServer.reply(config.caller, {:error, reason})

    {:noreply, config}
  end

  ## Helpers

  defp update_or_create_async(fun, key, ttl, caller) do
    Task.Supervisor.async_nolink(
      Cachettl.TaskSupervisor,
      fn ->
        update_fun =
          :ets.update_element(Storage.table(), key, [
            {@fun, fun},
            {@timestamp, :erlang.timestamp()}
          ])

        case update_fun do
          true ->
            {:updated, key, caller}

          false ->
            :ets.insert(
              Storage.table(),
              {key, fun, nil, :erlang.timestamp(), :busy}
            )

            {:new, key, ttl, caller}
        end
      end
    )
  end

  defp terminate_worker_async(sup_pid) do
    Task.Supervisor.start_child(
      Cachettl.TaskSupervisor,
      fn ->
        # :ets.delete(Storage.table(), key)
        DynamicSupervisor.stop(sup_pid, :normal)
      end
    )
  end

  # For debug puroses. Get the PID of the a specific Worker process.
  @spec worker_pid(any) :: pid
  def worker_pid(key) do
    [{pid, _value}] = Registry.lookup(Cachettl.WorkerRegistry, to_string(key) <> "-worker")
    pid
  end
end
