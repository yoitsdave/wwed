defmodule Wwed.Game do
  use GenServer
  require Logger
  defstruct [:state, #awaiting_start, in_round, done
    :name,           #name of room
    :pwd,            #password of room - not at all secure, dont put real passwords!
    :rounds,         #list of all completed rounds
    :cur_round,      #current round
    :users,          #list of all users
    :ethan,          #person to emulate! (ideally someone named ethan)
  ]
  
  #client 

  def start_link([name, pwd]) do
    addr = {:via, Wwed.GameRegistry, name}
    Logger.debug("New game in room #{inspect addr }")
    GenServer.start_link(__MODULE__, [name, pwd], name: addr)
  end 

  #boolean, whether rooom registered with that name has the same name and password
  def match(name, pwd) do
    GenServer.call({:via, Wwed.GameRegistry, name}, {:match, name, pwd})
  end

  def set_ethan(name, user) do
    case exists_user(name, user) do
      true ->
        GenServer.call({:via, Wwed.GameRegistry, name}, {:set_ethan, user})
      false ->
        {:error, :user_not_found}
    end
  end

  def get_ethan(name) do
    GenServer.call({:via, Wwed.GameRegistry, name}, :get_ethan)
  end

  def list_users(name) do
    GenServer.call({:via, Wwed.GameRegistry, name}, :list_users)
  end
    
  def add_user(name, user) do
    case exists_user(name, user) do
      false ->
        GenServer.call({:via, Wwed.GameRegistry, name}, {:add_user, user})
      true ->
        {:error, :already_added}
      end
  end
  
  def score(name, user) do
    case exists_user(name, user) do
      true ->
        (list_users(name) |> Enum.filter(fn x -> x.name == user end) |> hd).score
      false ->
        nil
    end
  end
  
  def start_round(name) do
    GenServer.call({:via, Wwed.GameRegistry, name}, {:start_round})
  end

  def get_setter(name) do
    GenServer.call({:via, Wwed.GameRegistry, name}, :get_setter)
  end

  def prompt_round(name, user, prompt) do
    GenServer.call({:via, Wwed.GameRegistry, name}, {:prompt_round, user, prompt})
  end
  
  def response(name, user, answer) do
    case exists_user(name, user) do
      true -> GenServer.call({:via, Wwed.GameRegistry, name}, {:response, user, answer})
      false -> {:error, :user_not_found}
    end
  end
  
  def vote(name, user, vote) do
    case exists_user(name, user) do
      true -> GenServer.call({:via, Wwed.GameRegistry, name}, {:vote, user, vote})
      false -> {:error, :user_not_found}
    end
  end

  def drop_user(name, user) do
    case exists_user(name, user) do
      true -> 
        case length list_users(name) do
          1 -> end_game(name)
          _other -> GenServer.call({:via, Wwed.GameRegistry, name}, {:drop_user, user})
        end
      false -> {:error, :user_not_found}
    end
  end

  def end_game(name) do
    GenServer.stop({:via, Wwed.GameRegistry, name}, {:shutdown, :game_over})
  end

  def accepting_new(name, user) do
    Wwed.GameRegistry.whereis_name(name) == :undefined or
    length(list_users(name)) <= 19 and exists_user(name, user) == false
  end

  #helpers
  def next_setter(state) do
    case state.rounds do
      [] -> Enum.random(state.users)
      lst -> case who_is(state, Enum.random(hd(lst).winners)) do
              nil -> Enum.random(state.users)
              out -> out
            end
    end
  end
  
  def next_paradigm(state) do
    "What would #{state.ethan} say?"
  end
  
  def who_is(state, user) do
    case Enum.filter(state.users, fn x -> x.name == user end) do
      [out] -> out
      [] -> nil
      [_h | _t] -> Logger.error("multiple users named #{user} in room #{state.name}")
    end
  end
  
  def exists_user(name, user) do
    Wwed.GameRegistry.whereis_name(name) != :undefined and
    Enum.filter(list_users(name), fn x -> x.name == user end) |> length == 1
  end
  
  def answered_or_voted(user, answers_or_votes) do
    Enum.filter(answers_or_votes, fn {name, _other} -> name == user end) |> length == 1
  end
  
  def valid_vote(user, responses, vote) do
    (Enum.filter(responses, fn {name, other} -> name != user and vote == other end)
      |> length) > 0
  end
  
  def finalize_round(state, round, from) do
    winners = get_winners(round)
    users = incr_score(state.users, winners)
    state = %Wwed.Game{state | users: users}

    round = %Wwed.Round{round | state: :done}
    round = %Wwed.Round{round | winners: winners}
    state = %Wwed.Game{state | cur_round: nil}
    state = %Wwed.Game{state | state: :awaiting_start}
    state = %Wwed.Game{state | rounds: [round | state.rounds]}
    
    send(from, {"cli_users", state.users})
    Logger.debug("round #{round.number} won by #{inspect winners}")
    
    state
  end

  def get_winners(round) do
    counts = round.votes |>
      Enum.reduce(%{}, fn {_user, vote}, acc -> Map.update(acc, vote, 1, &(&1 + 1)) end)
    counts = Enum.sort(Map.to_list(counts), fn {_a1, v1}, {_a2, v2} -> v1 >= v2 end)
    {_val, max} = (hd counts)
    counts |> Enum.filter(fn {_val, count} -> count == max end) 
           |> Enum.map(fn {val, _count} -> who_said(round, val) end)
           |> List.flatten()
  end
  
  def incr_score(user_list, winners) do
    Enum.reduce(winners, user_list,
      fn loc_winner, acc ->
        winner_struct = 
          Enum.filter(acc, fn user -> user.name == loc_winner end) |> hd
        others = Enum.filter(acc, fn user -> user.name != loc_winner end)
        [%Wwed.User{winner_struct | score: winner_struct.score+1} | others]
      end)
  end
  
  def who_said(round, val) do
    Enum.filter(round.responses, fn {_user, response} -> response == val end) |>
      Enum.map(fn {who, _what} -> who end)
  end
  
  def kill_round(state) do
    state = %Wwed.Game{state | cur_round: nil}
    %Wwed.Game{state | state: :awaiting_start}
  end
  
  #server
  @impl true
  def init([name, pwd]) do
    {:ok, 
      %Wwed.Game{state: :awaiting_start, 
        name: name, 
        pwd: pwd,
        rounds: [],
        cur_round: nil, 
        users: [],
        ethan: nil,
      }
    }
  end

  @impl true
  def handle_call({:set_ethan, user}, {from, _reg}, state) do
    send(from, {"cli_ethan", user})
    {:reply, :ok, %Wwed.Game{state | ethan: user}}
  end

  @impl true
  def handle_call(:get_ethan, _from, state) do
    {:reply, state.ethan, state}
  end

  @impl true
  def handle_call({:match, name, pwd}, _from, state) do
    {:reply, name == state.name and pwd == state.pwd, state}
  end
  
  @impl true
  def handle_call(:list_users, _from, state) do
    {:reply, state.users, state}
  end

  @impl true
  def handle_call({:add_user, username}, {from, _reg}, state) do
    case state.state do
      :awaiting_start ->
        user = %Wwed.User{name: username, state: :connected, connection: nil, score: 0}
        state = %Wwed.Game{state | users: [user | state.users]}
        send(from, {"cli_users", state.users})
        {:reply, :ok, state}
      :in_round ->
        {:reply, {:error, :in_round}, state}
    end
  end

  @impl true
  def handle_call({:start_round}, {from, _ref}, state) do
    Logger.debug("attempting to start round with #{length state.users} users")
    case state.state do
      :awaiting_start ->
        case state.ethan do
          nil ->
            {:reply, {:error, :no_ethan}, state}
          _ethan ->
            case length(state.users) do
              x when x < 3 -> {:reply, {:error, :not_enough_players}, state}
              _x ->
                setter = next_setter(state)
                paradigm = next_paradigm(state)
                num = length(state.rounds) + 1
                new_round = Wwed.Round.new_round(num, setter, paradigm)
                state = %Wwed.Game{state | state: :in_round}
                
                send(from, {"cli_setter", setter.name})
                send(from, {"cli_paradigm", paradigm})
                send(from, {"cli_ethan", state.ethan})

                {:reply, :ok, %Wwed.Game{state | cur_round: new_round}}
            end
        end
      _other -> {:reply, {:error, :already_started}, state}
    end
  end

  @impl true
  def handle_call(:get_setter, _from, state) do
    case state.state do
      :awaiting_start ->
        {:reply, {:error, :awaiting_start}, state}
      :in_round ->
        {:reply, state.cur_round.setter, state}
    end
  end

  @impl true
  def handle_call({:prompt_round, user, prompt}, {from, _reg}, state) do
    case state.state do
      :awaiting_start ->
        {:reply, {:error, :round_not_started}, state}
      :in_round -> 
        case state.cur_round.state do
          :start -> 
            to_pin = state.cur_round.setter.name
            case user do
              nil -> 
                round = %Wwed.Round{state.cur_round | state: :prompt}
                round = %Wwed.Round{round | prompt: prompt}
                
                {:reply, :ok, %Wwed.Game{state | cur_round: round}}
              ^to_pin -> 
                round = %Wwed.Round{state.cur_round | state: :prompt}
                round = %Wwed.Round{round | prompt: prompt}
                
                send(from, {"cli_prompt", prompt})
                
                {:reply, :ok, %Wwed.Game{state | cur_round: round}}
              _other ->
                {:reply, {:error, :wrong_user}, state}
            end
          :prompt -> {:reply, {:error, :already_prompted}, state}
          :answers -> {:reply, {:error, :already_prompted}, state}
          :done -> {:reply, {:error, :already_prompted}, state}
        end
    end
  end

  @impl true
  def handle_call({:response, user, answer}, {from, _reg}, state) do
    case state.state do
      :awaiting_start ->
        {:reply, {:error, :round_not_started}, state}
      :in_round -> 
        case state.cur_round.state do
          :start -> {:reply, {:error, :round_not_prompted}, state}
          :prompt -> 
            case answered_or_voted(user, state.cur_round.responses) do
              true -> {:reply, {:error, :already_responded}, state}
              false ->
                responses = [{user, answer} | state.cur_round.responses]
                round = %Wwed.Round{state.cur_round | responses: responses}
                round = case length(responses) == length(state.users) do
                  true -> 
                    send(from, {"cli_responses", responses})
                    %Wwed.Round{round | state: :answers}
                  false -> round
                end
                {:reply, :ok, %Wwed.Game{state | cur_round: round}}
            end
          :answers -> {:reply, {:error, :already_responded}, state}
          :done -> {:reply, {:error, :already_responded}, state}
        end
    end
  end

  @impl true
  def handle_call({:vote, user, vote}, {from, _reg}, state) do
    case state.state do
      :awaiting_start ->
        {:reply, {:error, :round_not_started}, state}
      :in_round -> 
        case state.cur_round.state do
          :start -> {:reply, {:error, :round_not_prompted}, state}
          :prompt -> {:reply, {:error, :responses_not_done}, state}
          :answers -> 
            case answered_or_voted(user, state.cur_round.votes) do
              true -> {:reply, {:error, :already_voted}, state}
              false ->
                case valid_vote(user, state.cur_round.responses, vote) do
                  false -> {:reply, {:error, :invalid_vote}, state}
                  true ->
                    votes = [{user, vote} | state.cur_round.votes]
                    round = %Wwed.Round{state.cur_round | votes: votes}
                    state = case length(votes) == length(state.users) do
                      true -> 
                        ethan_response = Enum.filter(
                          round.responses,
                          fn {user, _resp} -> user == state.ethan end
                          ) |> Enum.map(fn {_user, resp} -> resp end) |> hd
                        send(from, {"cli_votes", {votes, ethan_response}})
                        finalize_round(state, round, from)
                      false -> %Wwed.Game{state | cur_round: round}
                    end
                    {:reply, :ok, state}
                end
            end
          :done -> {:reply, {:error, :already_responded}, state}
        end
    end
  end
  
  @impl true
  def handle_call({:drop_user, user}, {_from, _reg}, state) do
    new_users = state.users |>
            Enum.filter(fn %Wwed.User{name: name} -> name != user end)
    new_ethan = case state.ethan do
      ^user -> nil
      other -> other
    end
    state = %Wwed.Game{state | ethan: new_ethan}
    case state.state do
      :awaiting_start ->
        {:reply, :ok, %Wwed.Game{state | users: new_users}}
      :in_round -> 
        case length(state.users) do
          x when x < 4 ->{:reply, :ok, %Wwed.Game{kill_round(state) | users: new_users}}
          _x ->
            case state.cur_round.state do
              :start -> 
                round = case state.cur_round.setter.name do
                          ^user -> %Wwed.Round{state.cur_round | setter: next_setter(state)}
                          _other -> state.cur_round
                        end
                state = %Wwed.Game{state | cur_round: round}
                {:reply, :ok, %Wwed.Game{state | users: new_users}}
              :prompt -> 
                responses = state.cur_round.responses |>
                            Enum.filter(fn {name, _resp} -> user != name end)
                round = %Wwed.Round{state.cur_round | responses: responses}
                state = %Wwed.Game{state | cur_round: round}
                {:reply, :ok, %Wwed.Game{state | users: new_users}}
              :answers ->
                responses = state.cur_round.responses |>
                            Enum.filter(fn {name, _resp} -> user != name end)
                round = %Wwed.Round{state.cur_round | responses: responses}
                votes = state.cur_round.votes |>
                            Enum.filter(fn {name, _resp} -> user != name end)
                round = %Wwed.Round{round | votes: votes}
                state = %Wwed.Game{state | cur_round: round}
                {:reply, :ok, %Wwed.Game{state | users: new_users}}
              :done -> 
                {:reply, :ok, %Wwed.Game{state | users: new_users}}
            end
        end
    end
  end
  
  @impl true
  def terminate(reason, state) do
    Wwed.GameRegistry.unregister_name(state.name)
    Logger.warn("Room #{state.name} closed due to #{inspect reason}")
    :ok
  end
end