.PHONY: check

check:
	./tests/test_shell.sh
	python -m pytest -q
	git diff --check
