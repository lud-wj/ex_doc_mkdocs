defmodule ExDoc.Formatter.MKDOCS do
  alias ExDoc.Utils
  alias ExDoc.GroupMatcher
  alias ExDoc.Markdown
  alias ExDoc.Formatter.HTML
  alias __MODULE__.Templates

  @main "api-reference"

  def run(project_nodes, config) do
    config = prepare_config(config)
    buildfile = Path.join(config.output, ".build")
    cleanup_build(buildfile, config)

    File.mkdir_p!(markdown_dir(config))

    project_nodes = render_all(project_nodes, config)

    extras = build_extras(config)

    nodes_map = %{
      modules: HTML.filter_list(:module, project_nodes),
      tasks: HTML.filter_list(:task, project_nodes)
    }

    all_files =
      generate_list(nodes_map.modules, nodes_map, config) ++
        generate_list(nodes_map.tasks, nodes_map, config) ++
        generate_extras(nodes_map, extras, config) ++
        generate_mkdocs_yml(nodes_map, extras, config) ++ generate_index(config)

    generate_buildfile(all_files, buildfile)

    markdown_dir(config) |> Path.join("index.md") |> Path.relative_to_cwd()
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

  defp render_module_node(node, _config, autolink_opts) do
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
        child_node = %{child_node | spec: language.autolink_spec(child_node.spec, autolink_opts)}
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

  defp build_extras(config) do
    groups = config.groups_for_extras

    language =
      case config.proglang do
        :erlang -> ExDoc.Language.Erlang
        _ -> ExDoc.Language.Elixir
      end

    source_url_pattern = config.source_url_pattern

    autolink_opts = [
      apps: config.apps,
      deps: config.deps,
      ext: ".md",
      extras: extra_paths(config),
      skip_undefined_reference_warnings_on: config.skip_undefined_reference_warnings_on
    ]

    config.extras
    |> Task.async_stream(
      &build_extra(&1, groups, language, autolink_opts, source_url_pattern),
      timeout: :infinity
    )
    |> Enum.map(&elem(&1, 1))
    |> Enum.sort_by(fn extra -> GroupMatcher.group_index(groups, extra.group) end)
  end

  defp build_extra({input, options}, groups, language, autolink_opts, source_url_pattern) do
    input = to_string(input)
    id = options[:filename] || input |> HTML.filename_to_title() |> HTML.text_to_id()
    build_extra(input, id, options[:title], groups, language, autolink_opts, source_url_pattern)
  end

  defp build_extra(input, groups, language, autolink_opts, source_url_pattern) do
    id = input |> HTML.filename_to_title() |> HTML.text_to_id()
    build_extra(input, id, nil, groups, language, autolink_opts, source_url_pattern)
  end

  defp build_extra(input, id, title, groups, language, autolink_opts, source_url_pattern) do
    opts = [file: input, line: 1]

    ast =
      case extension_name(input) do
        extension when extension in ["", ".txt"] ->
          [{:pre, [], "\n" <> File.read!(input), %{}}]

        extension when extension in [".md", ".livemd", ".cheatmd"] ->
          input
          |> File.read!()
          |> Markdown.to_ast(opts)

        _ ->
          raise ArgumentError,
                "file extension not recognized, allowed extension is either .cheatmd, .livemd, .md, .txt or no extension"
      end

    {title_ast, ast} =
      case ExDoc.DocAST.extract_title(ast) do
        {:ok, title_ast, ast} -> {title_ast, ast}
        :error -> {nil, ast}
      end

    title_text = title_ast && ExDoc.DocAST.text_from_ast(title_ast)

    content = autolink_and_render(ast, language, [file: input] ++ autolink_opts)

    group = GroupMatcher.match_extra(groups, input)
    title = title || title_text || HTML.filename_to_title(input)

    source_path = input |> Path.relative_to(File.cwd!()) |> String.replace_leading("./", "")

    source_url = Utils.source_url_pattern(source_url_pattern, source_path, 1)

    %{
      content: content,
      group: group,
      id: id,
      source_path: source_path,
      source_url: source_url,
      title: title
    }
  end

  defp extra_paths(config) do
    Map.new(config.extras, fn
      path when is_binary(path) ->
        base = Path.basename(path)
        {base, HTML.text_to_id(Path.rootname(base))}

      {path, opts} ->
        base = path |> Atom.to_string() |> Path.basename()
        {base, opts[:filename] || HTML.text_to_id(Path.rootname(base))}
    end)
  end

  defp autolink_and_render(doc, language, autolink_opts) do
    doc
    |> language.autolink_doc(autolink_opts)
    |> ExDocMkdocs.DocAST.to_iolist()
  end

  defp generate_list(nodes, nodes_map, config) do
    nodes
    |> Task.async_stream(&generate_module_page(&1, nodes_map, config), timeout: :infinity)
    |> Enum.map(&elem(&1, 1))
  end

  defp generate_buildfile(files, buildfile) do
    entries = files |> Enum.sort() |> Enum.map(&[&1, "\n"])
    File.write!(buildfile, entries)
  end

  defp generate_index(config) do
    filename = "index.md"
    path = Path.join(markdown_dir(config), filename)

    File.write!(path, """
    # Documentation

    This documentation is not ready to be read.
    """)

    [filename]
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

  defp generate_extras(_nodes_map, extras, config) do
    generated_extras =
      extras
      |> with_prev_next()
      |> Enum.map(fn {node, prev, next} ->
        filename = "#{node.id}.md"
        output = extra_path(node, config)

        # refs = %{
        #   prev: prev && %{path: "#{prev.id}.html", title: prev.title},
        #   next: next && %{path: "#{next.id}.html", title: next.title}
        # }

        # extension = node.source_path && Path.extname(node.source_path)
        # md = Templates.extra_template(config, node, extra_type(extension), refs)
        md = Templates.extra_template(node)

        if File.regular?(output) do
          IO.puts(:stderr, "warning: file #{Path.relative_to_cwd(output)} already exists")
        end

        File.write!(output, md)
        filename
      end)

    generated_extras
    # support livemd ?
    # ++ copy_extras(config, extras)
  end

  defp extra_filename(extra_node) do
    "#{extra_node.id}.md"
  end

  defp extra_path(module_node, config) do
    module_path(extra_filename(module_node), config)
  end

  defp with_prev_next([]), do: []

  defp with_prev_next([head | tail]) do
    Enum.zip([[head | tail], [nil, head | tail], tail ++ [nil]])
  end

  # defp extra_type(".cheatmd"), do: :cheatmd
  # defp extra_type(".livemd"), do: :livemd
  # defp extra_type(_), do: :extra

  defp generate_mkdocs_yml(nodes_map, extras, config) do
    filename = "mkdocs.yml"

    mkdocs_config =
      ExDocMkdocs.fetch_config()
      |> Map.new()
      |> Map.put_new(:theme, "material")

    nav = [
      %{"Home" => "index.md"},
      %{"Modules" => modules_nav(nodes_map.modules, config)},
      %{(config.extra_section || "Pages") => extras_nav(extras, config)}
    ]

    yaml_data =
      mkdocs_config
      |> Map.put(:nav, nav)
      |> Map.put(:docs_dir, Path.relative_to(markdown_dir(config), config.output))

    yaml = Jason.encode!(yaml_data, pretty: true)
    File.write!(Path.join(config.output, filename), yaml)
    [filename]
  end

  defp modules_nav(nodes, config) do
    nodes
    |> Enum.sort_by(& &1.module)
    |> Enum.group_by(& &1.nested_context)
    |> Enum.sort_by(fn
      {nil, _} -> {0, nil}
      {tag, _} -> {1, tag}
    end)
    |> Enum.map(fn
      {nil, subnodes} ->
        Enum.map(
          subnodes,
          &%{&1.title => Path.relative_to(module_path(&1, config), markdown_dir(config))}
        )

      {prefix, subnodes} ->
        %{
          prefix =>
            Enum.map(
              subnodes,
              fn sub ->
                title = deprefix(sub.title, prefix)
                %{title => Path.relative_to(module_path(sub, config), markdown_dir(config))}
              end
            )
        }
    end)
    |> :lists.flatten()
  end

  defp deprefix(string, prefix) do
    String.replace(string, ~r/^#{prefix}/, "")
  end

  defp extras_nav(nodes, config) do
    Enum.map(
      nodes,
      &%{&1.title => Path.relative_to(extra_path(&1, config), markdown_dir(config))}
    )
  end

  defp downgrade_headers(term, 0), do: term
  defp downgrade_headers(doc, n) when is_list(doc), do: Enum.map(doc, &downgrade_headers(&1, n))
  defp downgrade_headers(doc, _n) when is_binary(doc), do: doc

  defp downgrade_headers({tag, attrs, content, meta}, n)
       when tag in [:h1, :h2, :h3, :h4, :h5, :h6] do
    tag = downgrade_headers(tag, n)
    content = downgrade_headers(content, n)
    {tag, attrs, content, meta}
  end

  defp downgrade_headers({tag, attrs, content, meta}, n) do
    content = downgrade_headers(content, n)
    {tag, attrs, content, meta}
  end

  defp downgrade_headers(:h1, n), do: downgrade_headers(:h2, n - 1)
  defp downgrade_headers(:h2, n), do: downgrade_headers(:h3, n - 1)
  defp downgrade_headers(:h3, n), do: downgrade_headers(:h4, n - 1)
  defp downgrade_headers(:h4, n), do: downgrade_headers(:h5, n - 1)
  defp downgrade_headers(:h5, n), do: downgrade_headers(:h6, n - 1)
  defp downgrade_headers(:h6, _), do: :h6

  defp extension_name(input) do
    input
    |> Path.extname()
    |> String.downcase()
  end
end
