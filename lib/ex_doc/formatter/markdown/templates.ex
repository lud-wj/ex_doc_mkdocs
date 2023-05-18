defmodule ExDoc.Formatter.MARKDOWN.Templates do
  require EEx

  def module_page(module_node, nodes_map, config) do
    # summary = module_summary(module_node)
    module_template(config, module_node, _summary = [], nodes_map)
  end

  templates = [
    module_template: [:config, :module, :summary, :nodes_map]

    # Templates existing in the original ExDoc.Formatter.HTML.Templates
    # detail_template: [:node, :module],
    # footer_template: [:config, :node],
    # head_template: [:config, :page],
    # not_found_template: [:config, :nodes_map],
    # api_reference_entry_template: [:module_node],
    # api_reference_template: [:nodes_map],
    # extra_template: [:config, :node, :type, :nodes_map, :refs],
    # search_template: [:config, :nodes_map],
    # sidebar_template: [:config, :nodes_map],
    # summary_template: [:name, :nodes],
    # redirect_template: [:config, :redirect_to],
    # settings_button_template: []
  ]

  Enum.each(templates, fn {name, args} ->
    filename = Path.expand("templates/#{name}.eex", __DIR__)
    @doc false
    EEx.function_from_file(:def, name, filename, args, trim: true)
  end)
end
