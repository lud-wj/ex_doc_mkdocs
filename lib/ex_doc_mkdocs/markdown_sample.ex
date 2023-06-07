defmodule ExDocMkdocs.MarkdownSample do
  @moduledoc """

  # This is a sample module to show the rendering of all markdown features.

  ## Headings

  ### Heading 3

  #### Heading 4

  ##### Heading 5

  ###### Heading 6


  ## Inline features

  Words can be displayed in **bold** or in *italics*. The Elixir documentation
  accepts both __asterisks__ and _underscores_.

  Single new lines should not
  generate new paragraphs.

  We can also display `code`.

  A paragraph can contain a [link](https://www.example.com).

  [Pragraph links should be ok too.](https://www.example.com)

  ## Code blocks

  ```markdown
  # Fenced code blocks work and accept a language!
  ```

      As well as indented code blocks.

  ## Lists

  * This list
  * is unordered.

  1. But this one
  1. is!

  Lists can be nested:

  * A top list item
    1. with a nested item
      that spans multiple lines
    2. and another nested item
      that spans multiple lines
    3. and a badly indented
       that spans multiple lines
       - super nested
         wooohooo
  * back to root

  ## Images


  Markdown also supports images:

  ![elixir logo](https://upload.wikimedia.org/wikipedia/en/a/a4/Elixir_programming_language_logo.png).

  The same image, inline, without alt test ![elixir logo](https://upload.wikimedia.org/wikipedia/en/a/a4/Elixir_programming_language_logo.png) should also work.


  """
end
