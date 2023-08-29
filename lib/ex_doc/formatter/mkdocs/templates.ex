defmodule ExDoc.Formatter.MKDOCS.Templates do
  require EEx
  import ExDoc.Utils

  alias ExDoc.Formatter.HTML

  import ExDoc.Formatter.HTML.Templates,
    only: [get_defaults: 1, pretty_type: 1, get_specs: 1, format_spec_attribute: 2]

  def module_page(module_node, nodes_map, config) do
    summary = module_summary(module_node)
    module_template(config, module_node, summary, nodes_map)
  end

  def module_summary(module_node) do
    entries =
      [Types: module_node.typespecs] ++
        docs_groups(module_node.docs_groups, module_node.docs)

    Enum.reject(entries, fn {_type, nodes} -> nodes == [] end)
  end

  defp docs_groups(groups, docs) do
    for group <- groups, do: {group, Enum.filter(docs, &(&1.group == group))}
  end

  defp enc(binary), do: URI.encode(binary)

  defp indent(binary, amount, skip_first \\ false) when is_binary(binary) do
    indent = String.duplicate(" ", amount)

    indented =
      binary
      |> String.split("\n")
      |> Enum.intersperse(indent)

    if skip_first,
      do: indented,
      else: [indent | indented]
  end

  def synopsis(nil), do: nil

  def synopsis(doc) when is_binary(doc) do
    case :binary.split(doc, "\n\n") do
      [left, _] -> String.trim_trailing(left, ":")
      [all] -> all
    end
  end

  templates = [
    module_template: [:config, :module, :summary, :nodes_map],
    summary_template: [:name, :nodes],
    detail_template: [:node, :module],
    extra_template: [:node]

    # Templates existing in the original ExDoc.Formatter.HTML.Templates
    # footer_template: [:config, :node],
    # head_template: [:config, :page],
    # not_found_template: [:config, :nodes_map],
    # api_reference_entry_template: [:module_node],
    # api_reference_template: [:nodes_map],
    # search_template: [:config, :nodes_map],
    # sidebar_template: [:config, :nodes_map],
    # redirect_template: [:config, :redirect_to],
    # settings_button_template: []
  ]

  Enum.each(templates, fn {name, args} ->
    filename = Path.expand("templates/#{name}.eex", __DIR__)
    @doc false
    EEx.function_from_file(:def, name, filename, args, trim: true)
  end)
end
