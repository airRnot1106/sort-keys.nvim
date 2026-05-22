.PHONY: test lint fmt fmt-check clean

PLENARY_DIR ?= /tmp/sort-keys.nvim/plenary.nvim

test:
	@nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

fmt:
	stylua lua/ plugin/ tests/

fmt-check:
	stylua --check lua/ plugin/ tests/

lint:
	selene lua/ plugin/

clean:
	rm -rf $(PLENARY_DIR) doc/tags
