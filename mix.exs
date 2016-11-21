defmodule MessagePack.RPC.Mixfile do
  use Mix.Project

  def project do
    [app: :msgpack_rpc,
     version: "0.1.2",
     elixir: "~> 1.3",
     preferred_cli_env: [espec: :test],
     consolidate_protocols: Mix.env != :test,
     package: package(),
     deps: deps(),
     description: "Tiny STDIO port wrapper for Msgpax RPC"]
  end

  def application do
    [applications: [:logger]]
  end

  defp package do
    [name: :msgpack_rpc,
     files: ["lib", "mix.exs", "README*"],
     licenses: ["Apache 2.0"],
     maintainers: ["Dmitry Dedov"],
     links: %{"GitHub" => "https://github.com/dm1try/msgpack_rpc"}]
  end

  defp deps do
    [{:msgpax, "~> 0.8.2"},
     {:espec, "~> 1.1.2", only: [:test]},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end
end
