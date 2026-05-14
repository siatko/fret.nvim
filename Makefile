.PHONY: test

test:
	nvim --headless \
	  --cmd "set rtp+=." \
	  --cmd "set rtp+=~/.local/share/nvim/lazy/plenary.nvim" \
	  -c "lua require('plenary.test_harness').test_directory('tests/', {minimal_init='tests/minimal_init.lua'})" \
	  -c "qa!"
