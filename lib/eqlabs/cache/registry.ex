defmodule Eqlabs.Cache.Registry do
  @moduledoc """
  Holds information about registered cache items.
  """
  @registry :cache_registry

  @doc """
  Registry cache name.
  """
  @spec name() :: atom()
  def name do
    @registry
  end

  @doc """
  Defines how registry cache items should be resolved.
  """
  @spec via_tuple(atom()) :: {:via, module(), {atom(), atom()}}
  def via_tuple(key) do
    {:via, Registry, {@registry, key}}
  end

  @doc """
  Checks if cache item with given `key` is registered.
  """
  @spec registered?(atom()) :: boolean()
  def registered?(key) do
    case Registry.lookup(@registry, key) do
      [{_pid, _}] ->
        true

      _ ->
        false
    end
  end

  @doc """
  Unregisteres cache item.
  """
  @spec unregister(atom()) :: :ok
  def unregister(key) do
    Registry.unregister(@registry, key)
  end
end
