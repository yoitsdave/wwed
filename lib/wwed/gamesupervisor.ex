defmodule Wwed.GameSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, [{:name, {:global, :game_supervisor}}])
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_game(name, pwd) do
    child_spec = %{
      id: name,
      start: {Wwed.Game, :start_link, [[name, pwd]]},
      restart: :transient
    }
    DynamicSupervisor.start_child({:global, :game_supervisor}, child_spec)
  end
  
  def all_games() do
    DynamicSupervisor.which_children({:global, :game_supervisor})
  end
end