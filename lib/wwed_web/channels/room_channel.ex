defmodule WwedWeb.RoomChannel do
  use Phoenix.Channel
  require Logger
  
  @impl true
  def join("room:" <> name, %{"pwd" => pwd, "user" => user}, socket) do
    case user != nil and valid_user(user) and Wwed.Game.accepting_new(name, user) do
      true ->
        assigns = %{"user" => user, "name" => name}
            
        case Wwed.GameRegistry.whereis_name(name) do
          :undefined ->
            Wwed.GameSupervisor.start_game(name, pwd)
            Wwed.Game.add_user(name, user)
            {
              :ok, 
              [clean(Wwed.Game.list_users(name)),  Wwed.Game.get_ethan(name)],
              %Phoenix.Socket{socket | assigns: assigns}
            }
          _pid ->
            case Wwed.Game.match(name, pwd) do
              true ->
                case Wwed.Game.add_user(name, user) do
                  :ok -> 
                    {
                      :ok, 
                      [clean(Wwed.Game.list_users(name)),  Wwed.Game.get_ethan(name)],
                      %Phoenix.Socket{socket | assigns: assigns}
                    }
                  {:error, reason} -> 
                    {:error, reason}
                end
              false ->
                {:error, :wrong_password}
            end
        end
      false ->
        {:error, :invalid_user}
    end
  end

  #trying to broadcast user drop was a major source of bugs - remember that any
  #messages sent to this prcess are likely to never be read because its about to
  #terminate!
  @impl true
  def terminate(_reason, socket) do
    user = socket.assigns["user"]
    name = socket.assigns["name"]
    
    Logger.debug("Dropping user #{user} from #{name} in process #{inspect self()}")
    Wwed.Game.drop_user(name, user)
    case Wwed.GameRegistry.whereis_name(name) do
      :undefined -> nil
      _other -> broadcast!(socket, "cli_users", clean Wwed.Game.list_users(name))
    end
    socket
  end
  
  @impl true
  def handle_in(event, payload, socket) do
    user = socket.assigns["user"]
    name = socket.assigns["name"]
    
    
    reply = case event do
      "ser_start" -> Wwed.Game.start_round(name) 
      "ser_prompt" -> 
        case payload == nil do
          true -> {:error, :nil_payload}
          false ->
            case valid_prompt(payload) do
              true -> Wwed.Game.prompt_round(name, user, payload)
              false -> {:error, :invalid_prompt}
            end
        end
      "ser_response" -> 
        case payload == nil do
          true -> {:error, :nil_payload}
          false ->
            case valid_response(payload) do
              true -> Wwed.Game.response(name, user, payload)
              false -> {:error, :invalid_response}
            end
        end
      "ser_vote" -> 
        case payload == nil do
          true -> {:error, :nil_payload}
          false ->
            case valid_response(payload) do
              true -> Wwed.Game.vote(name, user, payload)
              false -> {:error, :invalid_vote}
            end
        end
      "ser_ethan" ->
        case payload == nil do
          true -> {:error, :nil_payload}
          false ->
            case valid_user(payload) do
              true -> Wwed.Game.set_ethan(name, payload)
              false -> {:error, :invalid_ethan}
            end
        end
      _other -> 
        {:error, :invalid_command}
    end
    
    Logger.info("replying to #{event} with #{inspect clean reply}")
    {:reply, {:ok, clean reply}, socket}
  end
  
  @impl true
  def handle_info({event, payload}, socket) do
    Logger.debug("broadcast!(socket, #{inspect event}, #{inspect clean payload})")
    broadcast!(socket, event, clean payload)
    {:noreply, socket}
  end
  
  #validity helpers
  def valid_user(user) do
    String.match?(user, ~r/^[[:alnum:]]{1,32}$/)
  end
  
  def valid_prompt(prompt) do
    String.match?(prompt, ~r/^[[:print:]]{1,140}$/)
  end
  
  def valid_response(response) do
    String.match?(response, ~r/^[[:print:]]{1,64}$/)
  end
  
  def is_full(name) do
    (Wwed.Game.list_users(name) |> length) >= 16
  end
  
  # clean votes and responses by converting them to json-able types 
  def clean(payload) when is_list(payload) do
    case payload do
      [] -> %{payload: []}
      [{_k, _v} | _t] -> 
          %{ payload: Enum.reduce(payload, [], 
              fn {_name, resp}, acc -> [resp | acc] end
          )}
      [%Wwed.User{name: _name} | _t] ->
        %{ payload: Enum.reduce(payload, %{}, 
            fn %Wwed.User{name: name, score: score}, acc -> Map.put(acc, name, score) end
        )}
      end
  end
  
  def clean({:error, error_info}) when is_atom(error_info) do
    %{
      error: Atom.to_string(error_info)
    }
  end
  
  def clean ({votes, ethan_vote}) do
    %{payload: cleaned} = clean(votes) 
    %{payload: [cleaned, ethan_vote]}
  end
  
  def clean(payload) when is_bitstring(payload) do
    %{payload: payload}
  end
  
  def clean(payload) when is_atom(payload) do
    %{payload: Atom.to_string(payload)}
  end
  
  def clean other do
    Logger.error("I don't know how to clean #{other}, just inspecting")
    %{payload: inspect other}
  end
end