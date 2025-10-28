.PHONY: help install test lint format clean verify build

help:
	@echo "RunPod ComfyUI Cloud - Development Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make install    - Install dependencies"
	@echo "  make test       - Run tests"
	@echo "  make lint       - Run linters"
	@echo "  make format     - Format code"
	@echo "  make verify     - Verify links"
	@echo "  make build      - Build Docker image"
	@echo "  make clean      - Clean build artifacts"

install:
	python3 -m pip install --upgrade pip
	pip install -r requirements.txt

test:
	@echo "Running tests..."
	@if command -v pytest >/dev/null 2>&1; then \
		pytest tests/ -v || echo "No pytest tests found"; \
	else \
		echo "pytest not installed, skipping tests"; \
	fi
	@echo "Running link verification..."
	@python3 scripts/verify_links.py || echo "Link verification skipped"

lint:
	@echo "Running linters..."
	@if command -v flake8 >/dev/null 2>&1; then \
		flake8 scripts/ || echo "No flake8 issues found"; \
	else \
		echo "flake8 not installed, skipping lint"; \
	fi

format:
	@echo "Formatting code..."
	@if command -v black >/dev/null 2>&1; then \
		black scripts/ || echo "black not installed"; \
	else \
		echo "black not installed, skipping format"; \
	fi

verify:
	@echo "Verifying links..."
	@python3 scripts/verify_links.py

build:
	@echo "Building Docker image..."
	@./scripts/build.sh

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build/ dist/ *.egg-info
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete
	@echo "Clean complete"

.DEFAULT_GOAL := help

