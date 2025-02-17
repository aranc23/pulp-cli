LANGUAGES=de
PLUGINS=$(notdir $(wildcard pulpcore/cli/*))

info:
	@echo Pulp CLI
	@echo plugins: $(PLUGINS)

black:
	isort .
	black .

lint:
	find . -name '*.sh' -print0 | xargs -0 shellcheck -x
	black --diff --check .
	isort -c --diff .
	flake8
	mypy
	@echo "🙊 Code 🙈 LGTM 🙉 !"

tests/cli.toml:
	cp $@.example $@
	@echo "In order to configure the tests to talk to your test server, you might need to edit $@ ."

test: | tests/cli.toml
	pytest -v tests

servedocs:
	mkdocs serve

site:
	mkdocs build

pulpcore/cli/%/locale/messages.pot: pulpcore/cli/%/*.py
	xgettext -d $* -o $@ pulpcore/cli/$*/*.py
	sed -i 's/charset=CHARSET/charset=UTF-8/g' $@

extract_messages: $(foreach PLUGIN,$(PLUGINS),pulpcore/cli/$(PLUGIN)/locale/messages.pot)

$(foreach LANGUAGE,$(LANGUAGES),pulpcore/cli/%/locale/$(LANGUAGE)/LC_MESSAGES/messages.po): pulpcore/cli/%/locale/messages.pot
	[ -e $(@D) ] || mkdir -p $(@D)
	[ ! -e $@ ] || msgmerge --update $@ $<
	[ -e $@ ] || cp $< $@

%.mo: %.po
	msgfmt -o $@ $<

compile_messages: $(foreach LANGUAGE,$(LANGUAGES),$(foreach PLUGIN,$(PLUGINS),pulpcore/cli/$(PLUGIN)/locale/$(LANGUAGE)/LC_MESSAGES/messages.mo))

.PHONY: info black lint test servedocs
.PRECIOUS: $(foreach LANGUAGE,$(LANGUAGES),$(foreach PLUGIN,$(PLUGINS),pulpcore/cli/$(PLUGIN)/locale/$(LANGUAGE)/LC_MESSAGES/messages.po))
