defmodule Cachettl.ManagerTest do
  @moduledoc """
  Set `async: true` and start Cachettl.Manager to allow the Cachettl API
  test in CachettlTest to work.

  Private helper functions in Cachettl.Manager and Cachettl.Worker
  does not have the complexity to be reorganized in seperate
  modules that warrant isolated testing. Use Cachettl.MockWeather to monitor
  the performance of both modules and their private functions instead.
  See the Cachettl.MockWeather documentation.

  """

  use ExUnit.Case, async: true

  alias Cachettl.Manager

  setup %{} do
    pid =
      case start_supervised(Manager) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    [pid: pid]
  end
end
