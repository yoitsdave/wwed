defmodule Wwed.GameRegistry do
  use GenServer
  require Logger
  
  #client
  
  #there should only ever be one of these globally
  def start_link(_default) do
    Logger.debug("Game Registry Started")
    GenServer.start_link(__MODULE__, nil, [{:name, {:global, GameRegistry}}])
  end
  
  #returns :undefined if there is no such room
  def whereis_name(name) do
    GenServer.call({:global, GameRegistry}, {:get, name})
  end
  
  #returns :ok on success, {:error, which} on failure
  #possible errors:
  #  {:already_registered, pid}, when a room with the same name already exists
  def register_name(name, pid) do
    Logger.debug("registered name #{name}")
    case whereis_name(name) do
      :undefined -> 
        GenServer.call({:global, GameRegistry}, {:new, name, pid})
        :yes
      _pid ->
        :no
    end
  end
  
  def unregister_name(name) do
    GenServer.call({:global, GameRegistry}, {:del, name})
  end
  
  def send(pid, msg) do
    Kernel.send(pid |> whereis_name(), msg)
  end
  
  #server
  @impl true
  def init(_init_arg) do
    {:ok, Map.new()}
  end
  
  @impl true
  def handle_call({:new, name, pid}, _from, state) do
    {:reply, nil, Map.put(state, name, pid)}
  end

  @impl true
  def handle_call({:get, name}, _from, state) do
    {:reply, Map.get(state, name, :undefined), state}
  end

  @impl true
  def handle_call({:del, name}, _from, state) do
    {:reply, nil, Map.delete(state, name)}
  end
  
end