defmodule Eqlabs.CacheTest do
  use ExUnit.Case

  alias Eqlabs.Cache

  setup %{module: module, test: test} do
    %{key: "#{module}#{test}"}
  end

  describe "register_function/4" do
    test "returns :ok if cache is registered", %{key: key} do
      result = Cache.register_function(fn -> {:ok, "result"} end, key, 100, 10)

      assert :ok == result
    end

    test "returns error when key is already registered", %{key: key} do
      _result = Cache.register_function(fn -> {:ok, "result"} end, key, 100, 10)
      result = Cache.register_function(fn -> {:ok, "result"} end, key, 100, 10)

      assert {:error, :already_registered} == result
    end
  end

  describe "get/3" do
    test "returns cached value", %{key: key} do
      :ok = Cache.register_function(fn -> {:ok, "result"} end, key, 1000, 100)

      result = Cache.get(key, 500)

      assert {:ok, "result"} == result
    end

    test "returns error if key is not associated with any function", %{key: key} do
      :ok = Cache.register_function(fn -> {:ok, "result"} end, key, 100, 10)

      result = Cache.get("not_existing")

      assert {:error, :not_registered} == result
    end

    test "returns error when value is not computed in given timeout", %{key: key} do
      :ok =
        Cache.register_function(
          fn ->
            Process.sleep(200)
            {:ok, "result"}
          end,
          key,
          1000,
          100
        )

      result = Cache.get(key, 150)

      assert {:error, :timeout} == result
    end

    test "dispose cache item if it expires", %{key: key} do
      :ok =
        Cache.register_function(
          fn ->
            Process.sleep(200)
            {:ok, "result"}
          end,
          key,
          100,
          10
        )

      result = Cache.get(key, 150)

      assert {:error, :not_registered} == result
    end

    test "dispose cache item if it cannot be computed", %{key: key} do
      :ok =
        Cache.register_function(
          fn ->
            Process.sleep(10)
            {:error, "error"}
          end,
          key,
          100,
          10
        )

      Process.sleep(200)

      result = Cache.get(key, 200)

      assert {:error, :not_registered} == result
    end
  end
end
