defmodule Cachettl.StorageTest do
  @moduledoc """
  Test for Cachettl.Storage which contains storage definitions for:
  1. Persistent Term
  2. Counters
  3. ETS

  Note: ExUnit would not accept :named_table option for ETS instantiation.
  Use the dynamic method instead.
  """

  use ExUnit.Case

  doctest Cachettl.Storage

  alias Cachettl.Storage

  setup %{} do
    interval = 10
    :ok = Storage.set_refresh_interval(interval)
    refresh = Storage.get_refresh_interval()

    :ok = Storage.ets()
    table = Storage.table()

    [refresh: refresh, table: table]
  end

  ## PERSISTENT_TERMS

  test "check persistent term. get refresh_interval value.", %{refresh: refresh} do
    # "check if the value is integer"
    assert is_integer(refresh) == true

    # seconds to milliseconds(value * 1_000) is expected
    refute refresh == 10
    assert refresh == 10_000
  end

  test "ETS table", %{table: table} do
    assert is_reference(table) == true
    assert :ets.lookup(table, "HAL") |> is_list() == true
  end

  ## HELPER

  test "convert seconds to milliseconds" do
    assert 1 |> Storage.sec_to_ms() == 1_000

    # covert seconds in float to milliseconds
    assert 1.5 |> Storage.sec_to_ms() == 1_500

    # covert seconds in float to milliseconds test-2
    assert 0.05 |> Storage.sec_to_ms() == 50

    # round to zero if second is less than a millisecond
    assert 0.00015 |> Storage.sec_to_ms() == 0
  end
end
