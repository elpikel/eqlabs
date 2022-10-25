defmodule Eqlabs.Cache.ItemTest do
  use ExUnit.Case

  alias Eqlabs.Cache.Item
  alias Eqlabs.Cache.ItemsSupervisor

  setup %{module: module, test: test} do
    %{key: "#{module}#{test}"}
  end

  test "returns calculated value", %{key: key} do
    {:ok, _item} =
      ItemsSupervisor.start_child(%{
        key: key,
        function: fn ->
          {:ok, "result"}
        end,
        ttl: 100,
        refresh_interval: 10
      })

    Process.sleep(10)

    result = Item.get(key)

    assert {:ok, "result"} == result
  end

  test "returns expired when calculation took more than ttl", %{key: key} do
    {:ok, _item} =
      ItemsSupervisor.start_child(%{
        key: key,
        function: fn ->
          Process.sleep(200)
          {:ok, "result1"}
        end,
        ttl: 100,
        refresh_interval: 10
      })

    Process.sleep(150)

    result = Item.get(key)

    assert {:error, :expired} == result
  end

  test "returns expired when calculation returns error and we waited longer than ttl", %{key: key} do
    {:ok, _item} =
      ItemsSupervisor.start_child(%{
        key: key,
        function: fn ->
          {:error, :error}
        end,
        ttl: 100,
        refresh_interval: 10
      })

    Process.sleep(150)

    result = Item.get(key)

    assert {:error, :expired} == result
  end

  test "returns :computing when could not calculate task but cache is not expired", %{key: key} do
    {:ok, _item} =
      ItemsSupervisor.start_child(%{
        key: key,
        function: fn ->
          {:error, :error}
        end,
        ttl: 100,
        refresh_interval: 10
      })

    Process.sleep(20)

    result = Item.get(key)

    assert :computing == result
  end

  test "returns :computing when calculation raises exception but cache is not expired", %{
    key: key
  } do
    {:ok, _item} =
      ItemsSupervisor.start_child(%{
        key: key,
        function: fn -> raise "error" end,
        ttl: 100,
        refresh_interval: 10
      })

    Process.sleep(10)

    result = Item.get(key)

    assert :computing == result

    Process.sleep(100)
  end
end
