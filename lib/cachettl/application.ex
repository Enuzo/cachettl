defmodule Cachettl.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {Cachettl.Manager, name: Cachettl.Manager},
      {Task.Supervisor, name: Cachettl.TaskSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Cachettl.MasterVisor},
      {Registry, keys: :unique, name: Cachettl.WorkerRegistry}
    ]

    opts = [strategy: :one_for_one, name: Cachettl.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
