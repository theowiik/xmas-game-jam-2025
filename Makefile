.PHONY: format check

help:
	@echo "Available targets:"
	@echo "  format  - Format all gdscript files"
	@echo "  check   - Check formatting of all gdscript files"

format:
	nix-shell -p gdtoolkit_4 --run "gdformat ."

check:
	nix-shell -p gdtoolkit_4 --run "gdformat . --check"
