# ExDocMkdocs

This library implements a formatter for
[`ex_doc`](https://hex.pm/packages/ex_doc) that generates an
[MkDocs](https://www.mkdocs.org/) static site from the documentation.


## Installation

The library is not available in Hex but can be pulled from Github:

```elixir
def deps do
  [
    {:ex_doc_mkdocs, github: "lud-wj/ex_doc_mkdocs", only: [:dev], runtime: false},
  ]
end
```


## Configuration

First, MkDocs needs some configuration to generate the site correctly:

* `:site_name` - Defines the main title of the generated site.
* `:repo_url` - Links the documentation to the source code repository.

The easiest way to configure this is to add the following function in your `mix.exs` file:

```elixir
defp mkdocs do
  [
    site_name: "Mkdocs formatter for ex_doc",
    repo_url: "https://github.com/lud-wj/ex_doc_mkdocs/"
  ]
end
```

And then export this data from the `project` function:

```elixir
def project do
  [
    # ...
    mkdocs: mkdocs(),
    # ...
  ]
end
```


## Generate the docs

To use this formatter, run `mix docs --formatter mkdocs`. The generated site will be available in the `doc` directory by default. It will contain:

* `mkdocs.yml` - The configuration file for MkDocs.
* `markdown` - The generated Markdown files.


## Using MkDocs locally

To preview the documentation you may use MkDocs to serve the markdown files.

First, install MkDocs, for instance with Python Pip:

```bash
pip install mkdocs
```

Then, run it:

```bash
(cd doc && mkdocs serve)
```

Note that `mkdocs serve` executes in watch mode by default, so the preview will
be reloaded whenever you call `mix docs --formatter mkdocs` again (which can be
trigerred automatically from your changes in the docs by `fswatch` for
instance).


## Generating the static site

To build the documentation, you can generate the static site with MkDocs:

```bash
(cd doc && mkdocs build)
```


## Publishing the docs to Backstage from Github Actions

To push the documentation to [Backstage](https://backstage.io/), the following
action can be used.

Note that we do not describe here how to initialize the Backstage workspace or
the link to S3.

```yaml
name: Publish docs to S3

on:
  push:
    branches: [main]

jobs:
  publish-ex_doc-site:
    runs-on: ubuntu-latest

    env:
      BACKSTAGE_S3_BUCKET: "my-bucket"
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_DEFAULT_REGION: eu-west-1 # tweak at your convenience
      AWS_REGION: eu-west-1         # tweak at your convenience
      ENTITY_NAMESPACE: "default"
      ENTITY_KIND: "Component"
      ENTITY_NAME: "my-library"

    steps:
      - uses: actions/checkout@v2

      - uses: actions/setup-node@v2

      - uses: erlef/setup-beam@v1
        with:
          otp-version: '25'
          elixir-version: '1.14.4'

      - name: Get mix deps
        run: mix deps.get --only dev

      - name: Generate mkdocs source
        run: mix docs --formatter mkdocs

      - name: Install techdocs-cli
        run: sudo npm install -g @techdocs/cli

      - name: Install mkdocs and mkdocs plugins
        run: python -m pip install mkdocs-techdocs-core

      - name: Generate techdocs from mkdocs sources
        working-directory: doc
        run: techdocs-cli generate --no-docker --verbose

      - name: Publish docs site
        working-directory: doc
        run: techdocs-cli publish --publisher-type awsS3 --storage-name $BACKSTAGE_S3_BUCKET --entity $ENTITY_NAMESPACE/$ENTITY_KIND/$ENTITY_NAME
```