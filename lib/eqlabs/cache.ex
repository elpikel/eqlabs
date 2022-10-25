defmodule Eqlabs.Cache do
  @moduledoc """
  Periodic Self-Rehydrating Cache.

  Stores cached data. For each cache entry new GenServer is dynamically created.
  Which then tries to keep data up  to date. If cache expires it is removed from registry.
  """
  use GenServer

  @type result ::
          {:ok, any()}
          | {:error, :timeout}
          | {:error, :not_registered}

  alias Eqlabs.Cache.Item
  alias Eqlabs.Cache.ItemsSupervisor
  alias Eqlabs.Cache.Registry, as: CacheRegistry

  @doc """
  Starts cache.
  """
  @spec start_link(any) :: {:error, any} | {:ok, pid}
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc ~s"""
  Registers a function that will be computed periodically to update the cache.

  Arguments:
    - `fun`: a 0-arity function that computes the value and returns either
      `{:ok, value}` or `{:error, reason}`.
    - `key`: associated with the function and is used to retrieve the stored
    value.
    - `ttl` ("time to live"): how long (in milliseconds) the value is stored
      before it is discarded if the value is not refreshed.
    - `refresh_interval`: how often (in milliseconds) the function is
      recomputed and the new value stored. `refresh_interval` must be strictly
      smaller than `ttl`. After the value is refreshed, the `ttl` counter is
      restarted.

  The value is stored only if `{:ok, value}` is returned by `fun`. If `{:error,
  reason}` is returned, the value is not stored and `fun` must be retried on
  the next run.
  """
  @spec register_function(
          fun :: (() -> {:ok, any()} | {:error, any()}),
          key :: any,
          ttl :: non_neg_integer(),
          refresh_interval :: non_neg_integer()
        ) :: :ok | {:error, :already_registered}
  def register_function(fun, key, ttl, refresh_interval)
      when is_function(fun, 0) and is_integer(ttl) and ttl > 0 and
             is_integer(refresh_interval) and
             refresh_interval < ttl do
    GenServer.call(__MODULE__, {:register_function, fun, key, ttl, refresh_interval})
  end

  @doc ~s"""
  Get the value associated with `key`.

  Details:
    - If the value for `key` is stored in the cache, the value is returned
      immediately.
    - If a recomputation of the function is in progress, the last stored value
      is returned.
    - If the value for `key` is not stored in the cache but a computation of
      the function associated with this `key` is in progress, wait up to
      `timeout` milliseconds. If the value is computed within this interval,
      the value is returned. If the computation does not finish in this
      interval, `{:error, :timeout}` is returned.
    - If `key` is not associated with any function, return `{:error,
      :not_registered}`
  """
  @spec get(any(), non_neg_integer(), Keyword.t()) :: result
  def get(key, timeout \\ 30_000, _opts \\ []) when is_integer(timeout) and timeout > 0 do
    GenServer.call(__MODULE__, {:get, key, timeout}, :infinity)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:register_function, fun, key, ttl, refresh_interval}, _from, cache_items) do
    if CacheRegistry.registered?(key) do
      {:reply, {:error, :already_registered}, cache_items}
    else
      {:ok, pid} =
        ItemsSupervisor.start_child(%{
          key: key,
          function: fun,
          ttl: ttl,
          refresh_interval: refresh_interval
        })

      {:reply, :ok, Map.put(cache_items, key, pid)}
    end
  end

  @impl GenServer
  def handle_call({:get, key, timeout}, _from, cache_items) do
    if CacheRegistry.registered?(key) do
      case do_get(key, timeout) do
        {:error, :expired} ->
          cache_items = unregister(cache_items, key)
          {:reply, {:error, :not_registered}, cache_items}

        result ->
          {:reply, result, cache_items}
      end
    else
      {:reply, {:error, :not_registered}, cache_items}
    end
  end

  defp do_get(key, timeout) do
    {time_in_microseconds, result} = :timer.tc(fn -> run(key, timeout) end)
    time_in_miliseconds = time_in_microseconds * 000.1

    case result do
      {:error, :timeout} ->
        if time_in_miliseconds >= timeout do
          {:error, :timeout}
        else
          timeout = round(timeout - time_in_miliseconds)

          if timeout > 0 do
            Process.sleep(timeout)
          end

          run(key, 1000)
        end

      result ->
        result
    end
  end

  defp run(key, timeout) do
    try do
      case Item.get(key, timeout) do
        :computing ->
          {:error, :timeout}

        result ->
          result
      end
    catch
      :exit, {:timeout, _} ->
        {:error, :timeout}
    end
  end

  defp unregister(cache_items, key) do
    CacheRegistry.unregister(key)

    Map.delete(cache_items, key)
  end
end
