defmodule Eqlabs.Cache.ItemsSupervisor do
  @moduledoc """
  Supervises cache items.
  """
  use DynamicSupervisor

  alias Eqlabs.Cache.Item

  @doc """
  Starts a supervisor.
  """
  @spec start_link(any) :: {:error, any} | {:ok, pid}
  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Starts cache item.
  """
  @spec start_child(map()) :: {:error, any} | {:ok, pid}
  def start_child(
        %{
          key: _key,
          function: _function,
          ttl: _ttl,
          refresh_interval: _refresh_interval
        } = opts
      ) do
    child_specification = {Item, opts}

    DynamicSupervisor.start_child(__MODULE__, child_specification)
  end

  @impl DynamicSupervisor
  @spec init(any) ::
          {:ok,
           %{
             extra_arguments: list,
             intensity: non_neg_integer,
             max_children: :infinity | non_neg_integer,
             period: pos_integer,
             strategy: :one_for_one
           }}
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
