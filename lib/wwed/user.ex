defmodule Wwed.User do
  require Logger
  defstruct [:name, #name of user
    :state,          #connected or not
    :connection,     #any data needed to use channel
    :score,          #current score
  ]
  
end