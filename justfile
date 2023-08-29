clean:
  rm -rvf doc

docs:
  mix docs --formatter mkdocs

debug-html:
  rm -rf _build/dev/lib/ex_doc && mix docs --formatter html

watch-code:
  just run
  fswatch -o -m poll_monitor --event Updated --recursive lib | xargs  -I {} just run

run:
  # rm -rf doc/site/*
  mkdir -p doc
  just docs
  # python -m pip install mkdocs-techdocs-core
  cd doc/ && techdocs-cli generate --no-docker --verbose

serve: clean docs
  tree doc
  cd doc && mkdocs serve