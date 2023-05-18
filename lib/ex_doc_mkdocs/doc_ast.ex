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

  def to_iolist({:a, attrs, content, _meta}, ctx) do
    href = Keyword.fetch!(attrs, :href)
    ["[", to_iolist(content, ctx), "](", href, ")"]
  end

  def to_iolist({:code, attrs, content, _meta}, %{indent: 0}) do
    case attrs[:class] do
      "inline" -> ["`", content, "`"]
    end
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

  def to_iolist(ast, _ctx) do
    raise ArgumentError, "unsupported AST: #{inspect(ast)}"
  end

  defp indentation(ctx) do
    String.duplicate(" ", ctx.indent)
  end

  defp reindent(bin, ctx) do
    ws = indentation(ctx)
    binding() |> IO.inspect(label: ~S/binding()/)

    bin
    |> String.split("\n")
    |> Enum.intersperse(["\n", ws])
    |> dbg()
  end

  defp indent(%Ctx{indent: base} = ctx, n) do
    %Ctx{ctx | indent: base + n}
  end
end
