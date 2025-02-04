defmodule Terrestrial.MixProject do
  use Mix.Project

  @version "0.2.0"
  @url "https://github.com/schwarz/terrestrial"

  def project do
    [
      app: :terrestrial,
      version: @version,
      elixir: "~> 1.17",
      deps: deps(),
      description: "SVG charting library.",
      package: package(),
      source_url: @url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:ex_doc, "~> 0.36", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["BSD-3-Clause"],
      links: %{"GitHub" => @url}
    ]
  end
end
