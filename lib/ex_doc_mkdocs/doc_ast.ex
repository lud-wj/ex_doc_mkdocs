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

  def to_iolist({:p, _, content, _}, ctx) do
    [indentation(ctx), to_iolist(content, ctx), "\n\n"]
  end

  def to_iolist({tag, _, content, _}, ctx) when tag in [:h1, :h2, :h3, :h4, :h5, :h6] do
    [tag_prefix(tag), to_iolist(content, ctx), "\n\n"]
  end

  def to_iolist({:a, attrs, content, _}, ctx) do
    href = Keyword.fetch!(attrs, :href)
    ["[", to_iolist(content, ctx), "](", href, ")"]
  end

  def to_iolist({:code, attrs, content, _}, ctx) do
    case attrs[:class] do
      "inline" ->
        ["`", to_iolist(content, ctx), "`"]

      _ ->
        to_iolist(content, ctx)
    end
  end

  def to_iolist({:pre, _attrs, content, _}, %{indent: 0} = ctx) do
    language =
      Enum.find_value(content, fn
        {:code, attrs, _, _} -> Keyword.get(attrs, :class)
        _ -> nil
      end) || "elixir"

    ["```", language || "", "\n", to_iolist(content, ctx), "\n```\n\n"]
  end

  def to_iolist({:ul, _, content, meta}, ctx) do
    format_list("- ", content, ctx)
  end

  def to_iolist({:ol, _, content, meta}, ctx) do
    format_list("1. ", content, ctx)
  end

  def to_iolist({:li, _, content, _}, ctx) do
    to_iolist(content, indent(ctx, 2))
  end

  def to_iolist({:em, _, content, _}, ctx) do
    ["_", to_iolist(content, ctx), "_"]
  end

  def to_iolist({:strong, _, content, _}, ctx) do
    ["**", to_iolist(content, ctx), "**"]
  end

  def to_iolist({:img, attrs, _, _}, _ctx) do
    src = Keyword.fetch!(attrs, :src)

    case Keyword.fetch(attrs, :alt) do
      {:ok, alt} -> ["![", alt, "](", src, ")"]
      :error -> ["![](", src, ")"]
    end
  end

  def to_iolist({tag, _attrs, content, _meta} = ast, _ctx) do
    IO.warn("unsupported AST with tag #{inspect(tag)}: #{inspect(ast)}")
    to_iolist(content)
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

  defp format_list(item_prefix, content, ctx) do
    ws = indentation(ctx)

    subs =
      Enum.map_intersperse(content, "\n", fn li ->
        [ws, item_prefix, to_iolist(li, ctx)]
      end)

    newlines =
      case ctx.indent do
        0 -> "\n\n"
        _ -> "\n"
      end

    [newlines | subs]
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
