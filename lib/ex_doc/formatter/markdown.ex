defmodule ExDoc.Formatter.MARKDOWN do
  alias ExDoc.Formatter.HTML
  alias __MODULE__.Templates

  @main "api-reference"

  def run(project_nodes, config) do
    config = prepare_config(config)
    buildfile = Path.join(config.output, ".build")
    # cleanup_build(buildfile, config)

    File.mkdir_p!(markdown_dir(config))

    project_nodes = render_all(project_nodes, config)

    nodes_map = %{
      modules: HTML.filter_list(:module, project_nodes),
      tasks: HTML.filter_list(:task, project_nodes)
    }

    all_files =
      generate_list(nodes_map.modules, nodes_map, config) ++
        generate_list(nodes_map.tasks, nodes_map, config) ++
        generate_mkdocs_yml(nodes_map, config)

    # generate_index(config)

    generate_buildfile(Enum.sort(all_files), buildfile)

    # project_nodes |> Enum.map(&IO.inspect/1)
    config.output |> Path.join("index.md") |> Path.relative_to_cwd()
  end

  defp markdown_dir(config) do
    Path.join(config.output, "markdown")
  end

  defp prepare_config(config) do
    config
    |> Map.update!(:output, &Path.expand/1)
    |> ensure_index()
  end

  defp ensure_index(%{main: "index"}) do
    raise ArgumentError,
      message: ~S("main" cannot be set to "index", otherwise it will recursively link to itself)
  end

  defp ensure_index(%{main: main} = config) do
    %{config | main: main || @main}
  end

  defp cleanup_build(build, config) do
    if File.exists?(build) do
      build
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Path.join(config.output, &1))
      |> Enum.each(fn file ->
        IO.puts("cleanup #{file}")
        File.rm(file)
      end)

      File.rm(build)
    else
      # raise "no build at #{build}"
      File.rm_rf!(config.output)
      File.mkdir_p!(config.output)
    end
  end

  defp render_all(project_nodes, config) do
    autolink_opts = [
      apps: config.apps,
      deps: config.deps,
      ext: ".md",
      skip_undefined_reference_warnings_on: config.skip_undefined_reference_warnings_on
    ]

    project_nodes
    |> Task.async_stream(&render_module_node(&1, config, autolink_opts), timeout: :infinity)
    |> Enum.map(&elem(&1, 1))
  end

  defp render_module_node(node, config, autolink_opts) do
    autolink_opts =
      [
        current_module: node.module,
        file: node.source_path,
        line: node.doc_line,
        module_id: node.id
      ] ++ autolink_opts

    language = node.language

    docs =
      for child_node <- node.docs do
        id = id(node, child_node)
        autolink_opts = autolink_opts ++ [id: id, line: child_node.doc_line]
        specs = Enum.map(child_node.specs, &language.autolink_spec(&1, autolink_opts))
        child_node = %{child_node | specs: specs}
        render_doc(child_node, language, autolink_opts, downgrade_headers: 2)
      end

    typespecs =
      for child_node <- node.typespecs do
        id = id(node, child_node)
        autolink_opts = autolink_opts ++ [id: id, line: child_node.doc_line]

        child_node = %{
          child_node
          | spec:
              language.autolink_spec(child_node.spec, autolink_opts)
              |> IO.inspect(label: ~S/auto/)
        }

        render_doc(child_node, language, autolink_opts, downgrade_headers: 2)
      end

    %{
      render_doc(node, language, [{:id, node.id} | autolink_opts], [])
      | docs: docs,
        typespecs: typespecs
    }
  end

  defp render_doc(%{doc: nil} = node, _language, _autolink_opts, _opts),
    do: node

  defp render_doc(%{doc: doc} = node, language, autolink_opts, opts) do
    doc =
      case opts[:downgrade_headers] do
        nil -> doc
        n -> downgrade_headers(doc, n)
      end

    rendered = autolink_and_render(doc, language, autolink_opts)
    %{node | rendered_doc: :erlang.iolist_to_binary(rendered)}
  end

  defp id(%{id: mod_id}, %{id: "c:" <> id}) do
    "c:" <> mod_id <> "." <> id
  end

  defp id(%{id: mod_id}, %{id: "t:" <> id}) do
    "t:" <> mod_id <> "." <> id
  end

  defp id(%{id: mod_id}, %{id: id}) do
    mod_id <> "." <> id
  end

  defp autolink_and_render(doc, language, autolink_opts) do
    doc
    |> language.autolink_doc(autolink_opts)
    |> dbg()
    |> ExDocMkdocs.DocAST.to_iolist()
    |> tap(&IO.puts/1)
  end

  defp generate_list(nodes, nodes_map, config) do
    nodes
    |> Task.async_stream(&generate_module_page(&1, nodes_map, config), timeout: :infinity)
    |> Enum.map(&elem(&1, 1))
  end

  defp generate_buildfile(files, buildfile) do
    entries = Enum.map(files, &[&1, "\n"])
    File.write!(buildfile, entries)
  end

  defp generate_module_page(module_node, nodes_map, config) do
    path = module_path(module_node, config)
    content = Templates.module_page(module_node, nodes_map, config)
    File.write!(path, content)
    [Path.relative_to(path, config.output)]
  end

  defp module_filename(module_node) do
    "#{module_node.id}.md"
  end

  defp module_path(filename, config) when is_binary(filename) do
    Path.join(markdown_dir(config), filename)
  end

  defp module_path(module_node, config) do
    module_path(module_filename(module_node), config)
  end

  defp generate_mkdocs_yml(nodes_map, config) do
    filename = "mkdocs.yml"

    mkdocs_config =
      ExDocMkdocs.fetch_config()
      |> Map.new()
      |> Map.put_new(:theme, "material")

    nav = [
      %{"Modules" => modules_nav(nodes_map.modules, config)}
    ]

    yaml_data =
      mkdocs_config
      |> Map.put(:nav, nav)
      |> Map.put(:docs_dir, Path.relative_to(markdown_dir(config), config.output))

    yaml = Jason.encode!(yaml_data)
    IO.puts(yaml)
    File.write!(Path.join(config.output, filename), yaml)
    [filename]
  end

  defp modules_nav(nodes, config) do
    Enum.map(
      nodes,
      &%{&1.title => Path.relative_to(module_path(&1, config), markdown_dir(config))}
    )
  end

  defp downgrade_headers(term, 0), do: term
  defp downgrade_headers(doc, n) when is_list(doc), do: Enum.map(doc, &downgrade_headers(&1, n))
  defp downgrade_headers(doc, _n) when is_binary(doc), do: doc

  defp downgrade_headers({tag, attrs, content, meta} = el, n)
       when tag in [:h1, :h2, :h3, :h4, :h5, :h6] do
    tag = downgrade_headers(tag, n)
    content = downgrade_headers(content, n)
    {tag, attrs, content, meta}
  end

  defp downgrade_headers({tag, attrs, content, meta} = el, n) do
    content = downgrade_headers(content, n)
    {tag, attrs, content, meta}
  end

  defp downgrade_headers(:h1, n), do: downgrade_headers(:h2, n - 1)
  defp downgrade_headers(:h2, n), do: downgrade_headers(:h3, n - 1)
  defp downgrade_headers(:h3, n), do: downgrade_headers(:h4, n - 1)
  defp downgrade_headers(:h4, n), do: downgrade_headers(:h5, n - 1)
  defp downgrade_headers(:h5, n), do: downgrade_headers(:h6, n - 1)
  defp downgrade_headers(:h6, _), do: :h6
end
