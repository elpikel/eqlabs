defmodule Eqlabs.Cache.Item do
  @moduledoc """
  Represents cache item. Holds cached data associated with key.

  It uses passed `function` to refresh cache data.
  It refreshes data based on passes `refresh_interval`.
  It tried to refresh data up to the point when cache is expired.
  """
  use GenServer, restart: :temporary

  alias Eqlabs.Cache.Registry, as: CacheRegistry

  @doc """
  Starts cache item.
  """
  @spec start_link(%{
          :fun => (() -> {:ok, any()} | {:error, any()}),
          :key => any,
          :ttl => non_neg_integer(),
          :refresh_interval => non_neg_integer()
        }) :: {:ok, pid} | {:error, any}
  def start_link(%{key: key} = opts) do
    GenServer.start_link(__MODULE__, opts, name: CacheRegistry.via_tuple(key))
  end

  @doc """
  Gets cached data.

  If value is not yet cached (computation is in progress), :computing is returned.
  If cache is expired (because computation takes too long or computation fails) {:error, :expired} is returned.
  If value is cached and not expired {:ok, value} is returned.
  """
  @spec get(atom, :infinity | non_neg_integer) :: {:ok, any()} | :computing | {:error, :expired}
  def get(key, timeout \\ 5000) do
    key |> CacheRegistry.via_tuple() |> GenServer.call(:get, timeout)
  end

  @impl GenServer
  def init(%{key: key, function: function, ttl: ttl, refresh_interval: refresh_interval}) do
    {:ok,
     %{
       key: key,
       function: function,
       ttl: ttl,
       expires_at: current_time() + ttl,
       refresh_interval: refresh_interval,
       last_result: nil,
       is_computing: false,
       task: nil
     }, {:continue, :compute}}
  end

  @impl GenServer
  def handle_continue(:compute, state) do
    compute(state)
  end

  @impl GenServer
  def handle_call(
        :get,
        _from,
        %{last_result: last_result, expires_at: expires_at} = state
      ) do
    cond do
      expired?(expires_at) ->
        {:reply, {:error, :expired}, state}

      last_result == nil ->
        {:reply, :computing, state}

      true ->
        {:reply, last_result, state}
    end
  end

  @impl GenServer
  def handle_info(:compute, state) do
    compute(state)
  end

  @impl GenServer
  def handle_info({ref, result}, %{ttl: ttl} = state) do
    Process.demonitor(ref, [:flush])

    state =
      case result do
        {:ok, _value} = result ->
          state
          |> update_expiration(ttl)
          |> update_last_result(result)

        {:error, _reason} ->
          update_last_result(state, nil)
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, _, _, _}, state) do
    {:noreply, update_last_result(state, nil)}
  end

  defp compute(
         %{
           function: function,
           refresh_interval: refresh_interval,
           is_computing: is_computing,
           expires_at: expires_at
         } = state
       ) do
    if expired?(expires_at) do
      {:noreply, state}
    else
      Process.send_after(self(), :compute, refresh_interval)

      if is_computing do
        {:noreply, state}
      else
        task = Task.Supervisor.async_nolink(Eqlabs.TaskSupervisor, fn -> function.() end)

        state = %{state | task: task, is_computing: true}

        {:noreply, state}
      end
    end
  end

  defp current_time() do
    :os.system_time(:millisecond)
  end

  defp update_last_result(%{expires_at: expires_at} = state, nil) do
    if expired?(expires_at) do
      %{state | last_result: %{error: :expired}, is_computing: false, task: nil}
    else
      %{state | last_result: nil, is_computing: false, task: nil}
    end
  end

  defp update_last_result(state, value) do
    %{state | last_result: value, is_computing: false, task: nil}
  end

  defp update_expiration(state, ttl) do
    %{state | expires_at: current_time() + ttl}
  end

  defp expired?(expires_at) do
    current_time() > expires_at
  end
end
