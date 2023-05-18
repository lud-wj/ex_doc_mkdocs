docs:
  mix docs --formatter markdown

debug-html:
  rm -rf _build/dev/lib/ex_doc && mix docs --formatter html

run:
  # rm -rf doc
  mkdir -p doc
  just docs
  # python -m pip install mkdocs-techdocs-core
  cd doc/ && techdocs-cli generate --no-docker --verbose
  find doc/site
  find doc/markdown
