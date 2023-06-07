defmodule ExDocMkdocs do
  @moduledoc """
  Documentation for `ExDocMkdocs`.

  TEST III

  Our best function is `hello/0`!



  """

  @type world :: :world
  @type helloed :: world() | binary()

  @doc """
  Hello world.

  ## Examples

      iex> ExDocMkdocs.hello()
      :world


  ```javascript
  console.log('coucou')
  console.log('hello')
  ```
  """
  @spec hello() :: helloed()
  def hello do
    :world
  end

  @deprecated "use hello/0 instead"
  def bonjour do
    hello()
  end

  defmacro testmacro(do: block) do
    quote do
      case unquote(block) do
        {:ok, v} -> v
        {:error, reason} -> raise "error: #{inspect(reason)}"
      end
    end
  end

  def fetch_config do
    fetch_config(Mix.Project.get())
  end

  def fetch_config(mixmod) do
    project = mixmod.project()

    case Keyword.fetch(project, :mkdocs) do
      :error ->
        raise """
        no :mkdocs key in configuration returned from #{inspect(mixmod)}.project()

        Please provide a configuration for mkdocs in mix.exs

        defmodule #{inspect(mixmod)} do
          def project do
            [
              # ...
              mkdocs: mkdocs()
            ]
          end

          # ...

          defp mkdocs do
            [
              site_name: "My App",
              repo_url: "https://github.com/my-name/my-app/",
              theme: "material"
            ]
          end
        end
        """

      {:ok, mkdocs_config} ->
        if not Keyword.keyword?(mkdocs_config) do
          raise "invalid :mkdocs configuration returned from #{inspect(mixmod)}.project() in mix.exs, expected a Keyword list or a Map, got: #{inspect(mkdocs_config)}"
        end

        normalize_config(mkdocs_config)
    end
  end

  defp normalize_config(config) when is_list(config) do
    normalize_config(Map.new(config))
  end

  defp normalize_config(config) when is_map(config) do
    expected_keys = [:site_name]
    allowed_keys = [:repo_url, :theme]

    Enum.each(expected_keys, &expect_config_key(&1, config))

    config = Map.take(config, expected_keys ++ allowed_keys)

    Map.new(config, fn {k, v} ->
      case transform_config(k, v) do
        {:ok, value} -> {k, value}
        {:error, reason} -> raise "invalid mkdocs config, key #{inspect(k)}, #{reason}"
      end
    end)
  end

  defp expect_config_key(key, config) when not is_map_key(config, key) do
    raise "invalid mkdocs config, expected key #{inspect(key)} to be defined"
  end

  defp expect_config_key(_key, config) do
    config
  end

  defp transform_config(key, name) when key in [:site_name, :repo_url] do
    if is_binary(name),
      do: {:ok, name},
      else: {:error, "expected a binary, got: #{inspect(name)}"}
  end

  defp transform_config(:theme, name: theme) when is_binary(theme) do
    {:ok, %{name: theme}}
  end

  defp transform_config(:theme, theme) when is_binary(theme) do
    {:ok, %{name: theme}}
  end

  defp transform_config(:theme, theme) do
    {:error, "expected a binary, got: #{inspect(theme)}"}
  end
end
