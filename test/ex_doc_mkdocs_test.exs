defmodule ExDocMkdocsTest do
  use ExUnit.Case
  doctest ExDocMkdocs

  test "greets the world" do
    assert ExDocMkdocs.hello() == :world
  end
end
