defmodule Cachettl.WorkerVisor do
  @moduledoc false

  use Supervisor, restart: :transient

  @spec start_link(map) :: :ignore | {:error, any} | {:ok, pid}

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config)
  end

  @impl true
  def init(config) do
    # Register the supervisor's PID. This will help the parent supervisor
    # identify it for a clean shutdown.
    children = [
      {Cachettl.Worker, %{config | supervisor_pid: self()}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
