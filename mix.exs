defmodule OpenstexAdaptersOvh.Mixfile do
  use Mix.Project
  @version "0.3.0"
  @elixir_versions "~> 1.4 or ~> 1.5"

  def project do
    [
     app: :openstex_adapters_ovh,
     version: @version,
     elixir: @elixir_versions,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()
    ]
  end


  def application do
    [
      applications: [:logger]
    ]
  end


  defp deps do
    [
      {:httpipe_adapters_hackney, ">= 0.10.0"},
      {:ex_ovh, "~> 0.3"},
      {:openstex, "~> 0.3"}
    ]
  end
end
