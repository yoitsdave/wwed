defmodule WwedWeb.GameTest do
  use Wwed.DataCase
  require Logger

  test "game registry" do
    assert Wwed.GameRegistry.register_name("hi", 10) == :yes
    assert Wwed.GameRegistry.register_name("hi", 43) == :no  
  end 

  test "game match" do
    {:ok, p1} = Wwed.GameSupervisor.start_game("hello", "uwu")
    {:ok, _p2} = Wwed.GameSupervisor.start_game("goodbye", "owo")
    {:error, {:already_started, ^p1}} = Wwed.GameSupervisor.start_game("hello", "owo")
        
    assert Wwed.Game.match("hello", "uwu")
    assert Wwed.Game.match("goodbye", "owo")
    refute Wwed.Game.match("hello", "owo")
  end
  
  test "game users" do
    {:ok, _p1} = Wwed.GameSupervisor.start_game("users", "pwd")
    assert Wwed.Game.match("users", "pwd")
    
    :ok = Wwed.Game.add_user("users", "ethan")
    :ok = Wwed.Game.add_user("users", "josh")
    :ok = Wwed.Game.add_user("users", "judah")
    {:error, :already_added } = Wwed.Game.add_user("users", "ethan")
    {:error, :already_added } = Wwed.Game.add_user("users", "josh")

    assert length(Wwed.Game.list_users("users")) == 3
  end
  
  test "full round no dc" do
    {:ok, _p1} = Wwed.GameSupervisor.start_game("full", "pwd")
    assert Wwed.Game.match("full", "pwd")

    assert :ok == Wwed.Game.add_user("full", "ethan")
    assert :ok == Wwed.Game.add_user("full", "josh")
    assert :ok == Wwed.Game.add_user("full", "judah")
    assert :ok == Wwed.Game.set_ethan("full", "ethan")

    assert Wwed.Game.score("full", "ethan") == 0
    assert Wwed.Game.score("full", "josh") == 0
    assert Wwed.Game.score("full", "judah") == 0
    
    
    assert {:error, :round_not_started} == Wwed.Game.vote("full", "judah", "hats")
    assert {:error, :round_not_started} = Wwed.Game.response("full", "ethan", "dick")
    assert {:error, :round_not_started} = Wwed.Game.prompt_round("full", nil, "any crap")
    assert :ok == Wwed.Game.start_round("full")
    assert {:error, :already_started} == Wwed.Game.start_round("full")
    
    assert {:error, :round_not_prompted} == Wwed.Game.vote("full", "judah", "hats")
    assert {:error, :round_not_prompted} == Wwed.Game.response("full", "ethan", "dick")
    assert :ok == Wwed.Game.prompt_round("full", nil, "What do I wear to bed?")
    assert {:error, :already_started} == Wwed.Game.start_round("full")
    assert {:error, :already_prompted} == Wwed.Game.prompt_round("full", nil, "any crap")

    assert {:error, :responses_not_done} == Wwed.Game.vote("full", "judah", "hats")
    assert :ok == Wwed.Game.response("full", "ethan", "socks")
    assert {:error, :user_not_found} == Wwed.Game.response("full", "eunisa", "dick")
    assert {:error, :already_responded} == Wwed.Game.response("full", "ethan", "dick")
    assert {:error, :already_started} == Wwed.Game.start_round("full")
    assert {:error, :already_prompted} == Wwed.Game.prompt_round("full", nil, "any crap")
    assert :ok == Wwed.Game.response("full", "josh", "hats")
    assert {:error, :already_responded} == Wwed.Game.response("full", "ethan", "dick")
    assert {:error, :already_responded} == Wwed.Game.response("full", "josh", "dick")
    assert {:error, :already_started} == Wwed.Game.start_round("full")
    assert {:error, :already_prompted} == Wwed.Game.prompt_round("full", nil, "any crap")
    assert :ok == Wwed.Game.response("full", "judah", "cats")
    assert {:error, :already_responded} == Wwed.Game.response("full", "ethan", "dick")
    assert {:error, :already_responded} == Wwed.Game.response("full", "josh", "dick")
    assert {:error, :already_responded} == Wwed.Game.response("full", "judah", "dick")
    assert {:error, :user_not_found} == Wwed.Game.response("full", "bob", "dick")
    assert {:error, :already_started} == Wwed.Game.start_round("full")
    assert {:error, :already_prompted} == Wwed.Game.prompt_round("full", nil, "any crap")
    

    assert :ok == Wwed.Game.vote("full", "judah", "socks")
    assert {:error, :already_voted} == Wwed.Game.vote("full", "judah", "hats")
    assert {:error, :already_responded} == Wwed.Game.response("full", "ethan", "dick")
    assert {:error, :already_started} == Wwed.Game.start_round("full")
    assert {:error, :already_prompted} == Wwed.Game.prompt_round("full", nil, "any crap")
    assert {:error, :invalid_vote} == Wwed.Game.vote("full", "ethan", "socks")
    assert {:error, :invalid_vote} == Wwed.Game.vote("full", "ethan", "socks")
    assert {:error, :user_not_found} == Wwed.Game.vote("full", "bob", "dick")
    assert :ok == Wwed.Game.vote("full", "ethan", "hats")
    assert {:error, :already_voted} == Wwed.Game.vote("full", "ethan", "hats")
    assert {:error, :already_responded} == Wwed.Game.response("full", "ethan", "dick")
    assert {:error, :already_started} == Wwed.Game.start_round("full")
    assert {:error, :invalid_vote} == Wwed.Game.vote("full", "josh", "animals")
    assert {:error, :user_not_found} == Wwed.Game.vote("full", "eunisa", "dick")
    assert {:error, :already_prompted} == Wwed.Game.prompt_round("full", nil, "any crap")
    assert :ok == Wwed.Game.vote("full", "josh", "cats")
    
    assert Wwed.Game.score("full", "ethan") == 1
    assert Wwed.Game.score("full", "josh") == 1
    assert Wwed.Game.score("full", "judah") == 1
    assert Wwed.Game.score("full", "andrew") == nil
  end
  
  test "full round dc after start" do     
    {:ok, _p1} = Wwed.GameSupervisor.start_game("as", "pwd")
    assert Wwed.Game.match("as", "pwd")

    assert :ok == Wwed.Game.add_user("as", "ethan")
    assert :ok == Wwed.Game.add_user("as", "josh")
    assert :ok == Wwed.Game.add_user("as", "judah")
    assert :ok == Wwed.Game.set_ethan("as", "ethan")

    assert :ok == Wwed.Game.start_round("as")

    assert :ok == Wwed.Game.prompt_round("as", nil, "Why am I angry?")

    assert :ok == Wwed.Game.response("as", "judah", "dogs")
    assert :ok == Wwed.Game.response("as", "ethan", "dogs")
    assert :ok == Wwed.Game.response("as", "josh", "cheezits")

    assert :ok == Wwed.Game.vote("as", "judah", "dogs")
    assert :ok == Wwed.Game.vote("as", "ethan", "dogs")
    assert :ok == Wwed.Game.vote("as", "josh", "dogs")

    assert Wwed.Game.score("as", "ethan") == 1
    assert Wwed.Game.score("as", "josh") == 0
    assert Wwed.Game.score("as", "judah") == 1
    
    #R1 done  

    assert :ok == Wwed.Game.add_user("as", "eunisa") #shes a flake
    
    assert :ok == Wwed.Game.start_round("as")
    
    assert :ok == Wwed.Game.drop_user("as", "eunisa") #she flaked :(
    
    assert :ok == Wwed.Game.prompt_round("as", nil, "Why am I angry?")

    assert :ok == Wwed.Game.response("as", "judah", "dogs")
    assert :ok == Wwed.Game.response("as", "ethan", "cats")
    assert :ok == Wwed.Game.response("as", "josh", "cheezits")

    assert :ok == Wwed.Game.vote("as", "judah", "cats")
    assert :ok == Wwed.Game.vote("as", "ethan", "dogs")
    assert :ok == Wwed.Game.vote("as", "josh", "dogs")

    assert Wwed.Game.score("as", "ethan") == 1
    assert Wwed.Game.score("as", "josh") == 0
    assert Wwed.Game.score("as", "judah") == 2
    
  end
    
  test "full round dc after prompt" do 
    {:ok, _p1} = Wwed.GameSupervisor.start_game("ap", "pwd")
    assert Wwed.Game.match("ap", "pwd")

    assert :ok == Wwed.Game.add_user("ap", "ethan")
    assert :ok == Wwed.Game.add_user("ap", "josh")
    assert :ok == Wwed.Game.add_user("ap", "judah")
    assert :ok == Wwed.Game.set_ethan("ap", "ethan")

    assert :ok == Wwed.Game.start_round("ap")

    assert :ok == Wwed.Game.prompt_round("ap", nil, "Why am I angry?")

    assert :ok == Wwed.Game.response("ap", "judah", "dogs")
    assert :ok == Wwed.Game.response("ap", "ethan", "dogs")
    assert :ok == Wwed.Game.response("ap", "josh", "cheezits")

    assert :ok == Wwed.Game.vote("ap", "judah", "dogs")
    assert :ok == Wwed.Game.vote("ap", "ethan", "dogs")
    assert :ok == Wwed.Game.vote("ap", "josh", "dogs")

    assert Wwed.Game.score("ap", "ethan") == 1
    assert Wwed.Game.score("ap", "josh") == 0
    assert Wwed.Game.score("ap", "judah") == 1
    
    #R1 done  

    assert :ok == Wwed.Game.add_user("ap", "eunisa") #shes a flake
        
    assert :ok == Wwed.Game.start_round("ap")

    assert :ok == Wwed.Game.prompt_round("ap", nil, "Why am I angry?")

    assert :ok == Wwed.Game.drop_user("ap", "eunisa") #she flaked agAIn
    
    assert :ok == Wwed.Game.response("ap", "judah", "dogs")
    assert :ok == Wwed.Game.response("ap", "ethan", "cats")
    assert :ok == Wwed.Game.response("ap", "josh", "cheezits")

    assert :ok == Wwed.Game.vote("ap", "judah", "cats")
    assert :ok == Wwed.Game.vote("ap", "ethan", "dogs")
    assert :ok == Wwed.Game.vote("ap", "josh", "dogs")

    assert Wwed.Game.score("ap", "ethan") == 1
    assert Wwed.Game.score("ap", "josh") == 0
    assert Wwed.Game.score("ap", "judah") == 2
    
  end
  
  test "full round dc after answers" do
    {:ok, _p1} = Wwed.GameSupervisor.start_game("aa", "pwd")
    assert Wwed.Game.match("aa", "pwd")

    assert :ok == Wwed.Game.add_user("aa", "ethan")
    assert :ok == Wwed.Game.add_user("aa", "josh")
    assert :ok == Wwed.Game.add_user("aa", "judah")
    assert :ok == Wwed.Game.set_ethan("aa", "ethan")

    assert :ok == Wwed.Game.start_round("aa")

    assert :ok == Wwed.Game.prompt_round("aa", nil, "Why am I angry?")

    assert :ok == Wwed.Game.response("aa", "judah", "dogs")
    assert :ok == Wwed.Game.response("aa", "ethan", "dogs")
    assert :ok == Wwed.Game.response("aa", "josh", "cheezits")

    assert :ok == Wwed.Game.vote("aa", "judah", "dogs")
    assert :ok == Wwed.Game.vote("aa", "ethan", "dogs")
    assert :ok == Wwed.Game.vote("aa", "josh", "dogs")

    assert Wwed.Game.score("aa", "ethan") == 1
    assert Wwed.Game.score("aa", "josh") == 0
    assert Wwed.Game.score("aa", "judah") == 1
    
    #R1 done  

    assert :ok == Wwed.Game.add_user("aa", "eunisa") #shes a flake
        
    assert :ok == Wwed.Game.start_round("aa")

    assert :ok == Wwed.Game.prompt_round("aa", nil, "Why am I angry?")
    
    assert :ok == Wwed.Game.response("aa", "judah", "dogs")
    assert :ok == Wwed.Game.response("aa", "ethan", "cats")
    assert :ok == Wwed.Game.response("aa", "josh", "cheezits")
    assert :ok == Wwed.Game.response("aa", "eunisa", "salt")

    assert :ok == Wwed.Game.drop_user("aa", "eunisa") #she flaked FOR THE LAST TIME

    assert :ok == Wwed.Game.vote("aa", "judah", "cats")
    assert :ok == Wwed.Game.vote("aa", "ethan", "dogs")
    assert :ok == Wwed.Game.vote("aa", "josh", "dogs")

    assert Wwed.Game.score("aa", "ethan") == 1
    assert Wwed.Game.score("aa", "josh") == 0
    assert Wwed.Game.score("aa", "judah") == 2
  end

  test "round ended by dc" do
    {:ok, _p1} = Wwed.GameSupervisor.start_game("dead", "pwd")
    assert Wwed.Game.match("dead", "pwd")

    assert :ok == Wwed.Game.add_user("dead", "ethan")
    assert :ok == Wwed.Game.add_user("dead", "josh")
    assert :ok == Wwed.Game.add_user("dead", "judah")
    assert :ok == Wwed.Game.set_ethan("dead", "ethan")

    assert :ok == Wwed.Game.start_round("dead")

    assert :ok == Wwed.Game.prompt_round("dead", nil, "Why am I angry?")

    assert :ok == Wwed.Game.response("dead", "judah", "dogs")
    assert :ok == Wwed.Game.drop_user("dead", "josh")

    assert {:error, :round_not_started} == Wwed.Game.response("dead", "ethan", "cheezits")

    assert Wwed.Game.score("dead", "ethan") == 0
    assert Wwed.Game.score("dead", "josh") == nil
    assert Wwed.Game.score("dead", "judah") == 0
    
      end
  
  test "closes succesfully" do 
    {:ok, _p1} = Wwed.GameSupervisor.start_game("twice", "pwd")
    assert Wwed.Game.match("twice", "pwd")

    assert :ok == Wwed.Game.add_user("twice", "ethan")
    assert :ok == Wwed.Game.add_user("twice", "josh")
    assert :ok == Wwed.Game.add_user("twice", "judah")
    assert :ok == Wwed.Game.set_ethan("twice", "ethan")

    assert :ok == Wwed.Game.start_round("twice")

    assert :ok == Wwed.Game.prompt_round("twice", nil, "Why am I angry?")

    assert :ok == Wwed.Game.response("twice", "judah", "dogs")
    assert :ok == Wwed.Game.response("twice", "ethan", "dogs")
    assert :ok == Wwed.Game.response("twice", "josh", "cheezits")

    assert :ok == Wwed.Game.vote("twice", "judah", "dogs")
    assert :ok == Wwed.Game.vote("twice", "ethan", "dogs")
    assert :ok == Wwed.Game.vote("twice", "josh", "dogs")

    assert Wwed.Game.score("twice", "ethan") == 1
    assert Wwed.Game.score("twice", "josh") == 0
    assert Wwed.Game.score("twice", "judah") == 1

    #R1 done  

    assert :ok == Wwed.Game.add_user("twice", "eunisa") #shes a flake
        
    assert :ok == Wwed.Game.start_round("twice")

    assert :ok == Wwed.Game.prompt_round("twice", nil, "Why am I angry?")

    assert :ok == Wwed.Game.response("twice", "judah", "dogs")
    assert :ok == Wwed.Game.response("twice", "ethan", "cats")
    assert :ok == Wwed.Game.response("twice", "josh", "cheezits")
    assert :ok == Wwed.Game.response("twice", "eunisa", "salt")

    assert :ok == Wwed.Game.drop_user("twice", "eunisa") #she flaked FOR THE LAST TIME

    assert :ok == Wwed.Game.vote("twice", "judah", "cats")
    assert :ok == Wwed.Game.vote("twice", "ethan", "dogs")
    assert :ok == Wwed.Game.vote("twice", "josh", "dogs")

    assert Wwed.Game.score("twice", "ethan") == 1
    assert Wwed.Game.score("twice", "josh") == 0
    assert Wwed.Game.score("twice", "judah") == 2
    
    Wwed.Game.end_game("twice")
  end
end
