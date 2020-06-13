import Config

config :wwed, WwedWeb.Endpoint,
  server: true,
  http: [port: {:system, "PORT"}],
  url: [host: "wwed.gigalixir.com", port: 443]