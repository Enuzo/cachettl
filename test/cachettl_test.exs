defmodule CachettlTest do
  @moduledoc """

  Use Cachettl.MockWeather to monitor
  the performance of both modules and their private functions instead.
  See the Cachettl.MockWeather documentation.

  """

  use ExUnit.Case, async: true
  doctest Cachettl

  @value 3
  @status 5

  setup %{} do
    data = fn ->
      %{
        "temp" => (-24..100 |> Enum.random()) + Enum.random(101..900) / 100,
        "pressure" => Enum.random(100..10_000),
        "humidity" => Enum.random(1..400),
        "visibility" => Enum.random(1000..10_000),
        "date" => DateTime.now!("Etc/UTC")
      }
    end

    weather_data = [
      %{"id" => "HEL", "city" => "Helsinki", "main" => data.()}
    ]

    %{key: key, value: value} =
      0..(Enum.count(weather_data) - 1)
      |> Enum.random()
      |> then(fn index -> Enum.at(weather_data, index) end)
      |> then(fn map -> %{key: Map.get(map, "id"), value: map} end)

    [key: key, value: value, table: Cachettl.Storage.table()]
  end

  describe "store/3" do
    test "returns :ok if test is successful", %{key: key, value: value} do
      assert Cachettl.store(key, value, 12) == :ok
    end

    test "seconds in decimal is automatically converted to milliseconds in integer", %{
      key: key,
      value: value
    } do
      assert Cachettl.store(key, value, 12.00) == :ok
    end

    test "returns error if TTL is less than Refresh Interval", %{key: key, value: value} do
      assert Cachettl.store(key, value, 3.99) ==
               {:error, "TTL too low. Should be greater than refresh_interval: 4000ms"}
    end

    test "with 2 arguments, TTL defaults to 1hr(360_000ms)", %{key: key, value: value} do
      assert Cachettl.store(key, value) == :ok
    end
  end

   describe "get/1" do
    test "checking table returns", %{key: key, value: value, table: table} do
      # After the first-run, get/1 should also be able to return {:ok, data}
      :ets.update_element(table, key, [{@value, value}, {@status, :ready}])

      response = Cachettl.get(key)

      assert match?({:ok, _data}, response) == true or
               assert(
                 match?({:busy, _reason}, response) == true or
                   assert(match?({:error, _reason}, response) == true)
               )
    end
  end
end
