defmodule ExDocMkdocs.DocAST do
  defmodule Ctx do
    @enforce_keys [:indent]
    defstruct @enforce_keys
  end

  def to_iolist(ast) do
    to_iolist(ast, %Ctx{indent: 0})
  end

  def to_iolist(bin, ctx) when is_binary(bin) do
    reindent(bin, ctx)
  end

  def to_iolist(ast, ctx) when is_list(ast) do
    Enum.map(ast, &to_iolist(&1, ctx))
  end

  def to_iolist({:p, _, content, _meta}, ctx) do
    [indentation(ctx), to_iolist(content, ctx), "\n\n"]
  end

  def to_iolist({tag, _, content, _meta}, ctx) when tag in [:h1, :h2, :h3, :h4, :h5, :h6] do
    [tag_prefix(tag), to_iolist(content, ctx), "\n\n"]
  end

  def to_iolist({:a, attrs, content, _meta}, ctx) do
    href = Keyword.fetch!(attrs, :href)
    ["[", to_iolist(content, ctx), "](", href, ")"]
  end

  def to_iolist({:code, attrs, content, _meta}, ctx) do
    case attrs[:class] do
      "inline" ->
        ["`", to_iolist(content, ctx), "`"]

      _ ->
        to_iolist(content, ctx)
    end
  end

  def to_iolist({:pre, attrs, content, _meta}, %{indent: 0} = ctx) do
    language =
      Enum.find_value(content, fn
        {:code, attrs, _, _} -> Keyword.get(attrs, :class)
        _ -> "elixir"
      end)

    ["```", language || "", "\n", to_iolist(content, ctx), "\n```\n\n"]
  end

  def to_iolist({:ul, _, content, _meta}, ctx) do
    ws = indentation(ctx)

    lis =
      Enum.map_intersperse(content, "\n", fn li ->
        [ws, "- ", to_iolist(li, ctx)]
      end)

    ["\n" | lis]
  end

  def to_iolist({:li, _, content, _meta}, ctx) do
    to_iolist(content, indent(ctx, 2))
  end

  def to_iolist({:em, _, content, _meta}, ctx) do
    ["_", to_iolist(content, ctx), "_"]
  end

  def to_iolist({:strong, _, content, _meta}, ctx) do
    ["**", to_iolist(content, ctx), "**"]
  end

  def to_iolist(ast, _ctx) do
    raise ArgumentError, "unsupported AST: #{inspect(ast)}"
  end

  defp tag_prefix(tag) do
    case tag do
      :h1 -> "# "
      :h2 -> "## "
      :h3 -> "### "
      :h4 -> "#### "
      :h5 -> "##### "
      :h6 -> "###### "
    end
  end

  defp indentation(ctx) do
    String.duplicate(" ", ctx.indent)
  end

  defp reindent(bin, ctx) when is_binary(bin) do
    ws = indentation(ctx)

    bin
    |> String.split("\n")
    |> Enum.intersperse(["\n", ws])
  end

  defp indent(%Ctx{indent: base} = ctx, n) do
    %Ctx{ctx | indent: base + n}
  end
end
