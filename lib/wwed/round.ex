defmodule Wwed.Round do
  require Logger
  defstruct [:number, #round number
    :state,           #start, prompt, answers, done (maybe votes in between answers and done)
    :prompt,           #prompt for players to respond to
    :setter,          #user responsible for setting prompt
    :paradigm,        #how voters should judge the round e.g. "everyone imitate ethan"
    :responses,       #what players submitted as answers
    :votes,           #which answer each player voted for
    :winners,          #which players answer won!
  ]
  
  def new_round(number, setter, paradigm) do
    %Wwed.Round{number: number,
      state: :start,
      prompt: nil,
      setter: setter,
      paradigm: paradigm,
      responses: [],
      votes: [],
      winners: nil
    }
  end
  
end