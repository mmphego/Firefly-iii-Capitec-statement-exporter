.ONESHELL:

SHELL := /bin/bash
DATE_ID := $(shell date +"%y.%m.%d")
# Get package name from pwd
PACKAGE_NAME := $(shell basename $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST)))))

.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys

try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef

define PRINT_HELP_PYSCRIPT
import re, sys
print("Please use `make <target>` where <target> is one of\n")
for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		if not target.startswith('--'):
			print(f"{target:20} - {help}")
endef

export BROWSER_PYSCRIPT
export PRINT_HELP_PYSCRIPT
# See: https://docs.python.org/3/using/cmdline.html#envvar-PYTHONWARNINGS
export PYTHONWARNINGS=ignore

PYTHON := python3
BROWSER := $(PYTHON) -c "$$BROWSER_PYSCRIPT"

help:
	$(PYTHON) -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)

# -------------------------------- Builds and Installations -----------------------------

.PHONY: bootstrap
bootstrap: clean install-hooks dev docs ## Installs development packages, hooks and generate docs for development

dev: clean ## Install the package in development mode including all dependencies
	$(PYTHON) -m pip install .[dev]

dev-venv: venv ## Install the package in development mode including all dependencies inside a virtualenv (container).
	$(PYTHON) -m pip install .[dev];
	echo -e "\n--------------------------------------------------------------------"
	echo -e "Usage:\nPlease run:\n\tsource .$(PACKAGE_NAME)_venv/bin/activate;"
	echo -e "\t$(PYTHON) -m pip install .[dev];"
	echo -e "Start developing..."

install: clean ## Check if package exist, if not install the package
	$(PYTHON) -c "import $(PACKAGE_NAME)" >/dev/null 2>&1 || $(PYTHON) -m pip install .;

venv: clean ## Create virtualenv environment on local directory.
	@if ! command -v virtualenv >/dev/null 2>&1; then \
		$(PYTHON) -m pip install virtualenv;\
	fi;\
	$(PYTHON) -m virtualenv ".$(PACKAGE_NAME)_venv" -p $(PYTHON) -q;

# -------------------------------------- Project Execution -------------------------------

run:  # Run example
	$(PYTHON) main.py

# -------------------------------------- Clean Up  --------------------------------------
.PHONY: clean
clean: clean-build clean-docs clean-pyc clean-test ## Remove all build, test, coverage and Python artefacts

clean-build: ## Remove build artefacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -fr {} +
	find . -name '*.xml' -exec rm -fr {} +

clean-docs: ## Remove docs/_build artefacts, except PDF and singlehtml
	# Do not delete <module>.pdf and singlehtml files ever, but can be overwritten.
	find docs/compiled_docs ! -name "$(PACKAGE_NAME).pdf" ! -name 'index.html' -type f -exec rm -rf {} +
	rm -rf docs/compiled_docs/doctrees
	rm -rf docs/compiled_docs/html
	rm -rf docs/src/modules.rst
	rm -rf docs/src/$(PACKAGE_NAME)*.rst
	rm -rf docs/src/README.md

clean-pyc: ## Remove Python file artefacts
	find . -name '*.pyc' -exec rm -rf {} +
	find . -name '*.pyo' -exec rm -rf {} +
	find . -name '*~' -exec rm -rf {} +
	find . -name '__pycache__' -exec rm -fr {} +

clean-test: ## Remove test and coverage artefacts
	rm -fr .$(PACKAGE_NAME)_venv
	rm -fr .tox/
	rm -fr .pytest_cache
	rm -fr .mypy_cache
	rm -fr .coverage
	rm -fr htmlcov/
	rm -fr .pytest_cache


# -------------------------------------- Code Style  -------------------------------------

lint: ## Check style with `flake8` and `mypy`
	$(PYTHON) -m flake8 --max-line-length 90 $(PACKAGE_NAME)
	# find . -name "*.py" | xargs pre-commit run -c .configs/.pre-commit-config.yaml flake8 --files
# 	$(PYTHON) -m mypy

formatter: ## Format style with `black` and sort imports with `isort`
	isort -rc .
	black -l 90 .
	# find . -name "*.py" | xargs pre-commit run -c .configs/.pre-commit-config.yaml isort --files
