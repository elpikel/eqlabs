defmodule Eqlabs.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Eqlabs.TaskSupervisor},
      {Registry, [keys: :unique, name: Eqlabs.Cache.Registry.name()]},
      {Eqlabs.Cache.ItemsSupervisor, []},
      {Eqlabs.Cache, []}
    ]

    opts = [strategy: :one_for_one, name: Eqlabs.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
