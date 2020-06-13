import Config

config :wwed, WwedWeb.Endpoint,
  server: true,
  http: [port: {:system, "PORT"}],
  url: [host: nil, port: 443]