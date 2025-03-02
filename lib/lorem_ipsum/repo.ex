defmodule LoremIpsum.Repo do
  use Ecto.Repo,
    otp_app: :lorem_ipsum,
    adapter: Ecto.Adapters.Postgres
end
