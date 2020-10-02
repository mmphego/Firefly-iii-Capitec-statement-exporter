.ONESHELL:

SHELL := /bin/bash
DATE_ID := $(shell date +"%y.%m.%d")
# Get package name from pwd
PACKAGE_NAME := $(shell basename $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST)))))
DOCKER_IMAGE = "$(USER)/$(shell basename $(CURDIR))"

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

build-image:  ## Build docker image from local Dockerfile.
	docker build --no-cache -t $(DOCKER_IMAGE) .

build-cached-image:  ## Build cached docker image from local Dockerfile.
	docker build -t $(DOCKER_IMAGE) .

.PHONY: bootstrap
bootstrap: clean install-hooks dev docs ## Installs development packages, hooks and generate docs for development

.PHONY: dist
dist: clean ## Builds source and wheel package
	$(PYTHON) setup.py sdist
	$(PYTHON) setup.py bdist_wheel
	ls -l dist

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
run-in-docker:  ## Run example in a docker container
	docker run --rm -ti --volume "$(CURDIR)":/app $(DOCKER_IMAGE) \
	bash -c "python main.py"

run:  # Run example
	$(PYTHON) main.py

# -------------------------------------- Clean Up  --------------------------------------
.PHONY: clean
clean: clean-build clean-docs clean-pyc clean-test clean-docker ## Remove all build, test, coverage and Python artefacts

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

clean-docker:  ## Remove docker image
	docker rmi $(DOCKER_IMAGE) || true

# -------------------------------------- Code Style  -------------------------------------

lint: ## Check style with `flake8` and `mypy`
	$(PYTHON) -m flake8 --max-line-length 90 $(PACKAGE_NAME)
	# find . -name "*.py" | xargs pre-commit run -c .configs/.pre-commit-config.yaml flake8 --files
	$(PYTHON) -m mypy

checkmake:  ## Check Makefile style with `checkmake`
	docker run --rm -v $(CURDIR):/data cytopia/checkmake Makefile

formatter: ## Format style with `black` and sort imports with `isort`
	isort -rc .
	black -l 90 .
	# find . -name "*.py" | xargs pre-commit run -c .configs/.pre-commit-config.yaml isort --files

#  -------------------------------------- Hooks ------------------------------------------

install-hooks: ## Install `pre-commit-hooks` on local directory [see: https://pre-commit.com]
	$(PYTHON) -m pip install pre-commit
	pre-commit install --install-hooks -c .configs/.pre-commit-config.yaml

pre-commit: ## Run `pre-commit` on all files
	pre-commit run --all-files -c .configs/.pre-commit-config.yaml

# ---------------------------------------- Tests -----------------------------------------

coverage: ## Check code coverage quickly with pytest
	coverage run --source=$(PACKAGE_NAME) -m pytest -s .
	coverage xml
	coverage report -m
	coverage html

coveralls: ## Upload coverage report to coveralls.io
	coveralls --coveralls_yaml .coveralls.yml || true

.PHONY: test
test: ## Run tests quickly with pytest
	pytest -sv

view-coverage: ## View code coverage
	$(BROWSER) htmlcov/index.html

# ---------------------------- Generate Documentation and Changelog ----------------------

changelog: ## Generate changelog for current repo
	docker run -it --rm -v "$(CURDIR)":/usr/local/src/your-app mmphego/git-changelog-generator

complete-docs: --docs-depencencies ## Generate a complete Sphinx HTML documentation, including API docs.
	$(MAKE) -C docs/src html
	@echo "\n\nNote: Documentation located at: ";\
	echo "${PWD}/docs/compiled_docs/html/index.html";\

docs: --docs-depencencies ## Generate a single Sphinx HTML documentation, with limited API docs.
	$(MAKE) -C docs/src singlehtml;
	mv docs/compiled_docs/singlehtml/index.html docs/compiled_docs/;
	rm -rf docs/compiled_docs/singlehtml;
	rm -rf docs/compiled_docs/doctrees;
	@echo "\n\nNote: Documentation located at: ";\
	echo "${PWD}/docs/compiled_docs/index.html";\

.PHONY: --docs-depencencies
--docs-depencencies: clean-docs ## Check if sphinx is installed, then generate Sphinx HTML documentation dependencies.
	@if ! command -v sphinx-apidoc >/dev/null 2>&1; then $(MAKE) dev; fi
	sphinx-apidoc -o docs/src $(PACKAGE_NAME)
	sphinx-autogen docs/src/*.rst
	cp README.md docs/src
	cp docs/CONTRIBUTING.md docs/src
	sed -i 's/docs\///g' docs/src/README.md

pdf-doc: --docs-depencencies ## Generate a Sphinx PDF documentation, with limited including API docs. (Optional)
	@if command -v latexmk >/dev/null 2>&1; then \
		$(MAKE) -C docs/src latex; \
		if [ -d "docs/compiled_docs/latex" ]; then \
			$(MAKE) -C docs/compiled_docs/latex all-pdf LATEXMKOPTS=-quiet; \
			mv docs/compiled_docs/latex/$(PACKAGE_NAME).pdf docs; \
			rm -rf docs/compiled_docs/latex; \
			rm -rf docs/compiled_docs/doctrees; \
		fi; \
		echo "\n\nNote: Documentation located at: "; \
		echo "${PWD}/docs/$(PACKAGE_NAME).pdf"; \
	else \
		echo "Note: Untested on WSL/MAC";\
		echo "  Please install the following packages in order to generate a PDF documentation.\n";\
		echo "  On Debian run:"; \
		echo "    sudo apt install texlive-latex-recommended texlive-fonts-recommended texlive-latex-extra latexmk";\
		exit 1; \
	fi \
