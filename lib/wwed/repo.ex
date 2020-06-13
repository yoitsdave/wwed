defmodule Wwed.Repo do
  use Ecto.Repo,
    otp_app: :wwed,
    adapter: Ecto.Adapters.Postgres
end
