defmodule ExDocMkdocs.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_doc_mkdocs,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      mkdocs: mkdocs(),
      modkit: modkit()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.29.0", runtime: false},
      {:jason, "~> 1.4", runtime: false},

      # Dev
      {:credo, "~> 1.7", only: [:dev], runtime: false}
    ]
  end

  def modkit do
    [
      mount: [
        {ExDocMkdocs, "lib/ex_doc_mkdocs"},
        {ExDoc, "lib/ex_doc"}
      ]
    ]
  end

  defp mkdocs do
    [
      site_name: "Sample app",
      repo_url: "https://github.com/lud-wj/ex_doc_mkdocs/",
      theme: "material"
    ]
  end

  defp docs do
    [
      extras: [
        "guides/how-to-use.md"
      ],
      extra_section: "Guides",
      nest_modules_by_prefix: [ExDoc, ExDoc.Formatter, ExDocMkdocs]
    ]
  end
end
