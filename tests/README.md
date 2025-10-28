# Tests

This directory contains tests for the runpod-comfyui-cloud project.

## Running Tests

### Using pytest (recommended)
```bash
# Install dependencies first
pip install -r requirements.txt

# Run all tests
pytest

# Run with verbose output
pytest -v

# Run specific test file
pytest tests/test_basic.py
```

### Using Makefile
```bash
# Run tests via Makefile
make test
```

### Direct execution
```bash
# Run basic tests directly
python3 tests/test_basic.py
```

## Test Structure

- `test_basic.py` - Basic project structure and imports
- `__init__.py` - Test package initialization

## Writing New Tests

1. Create test files following the naming convention `test_*.py`
2. Use pytest fixtures and assertions
3. Add appropriate markers (`@pytest.mark.unit`, `@pytest.mark.integration`, etc.)

## Test Coverage

Currently, tests cover:
- ✅ Project structure validation
- ✅ Essential file existence
- ✅ Script availability
- ✅ Basic imports

Future tests should cover:
- Model download functionality
- Link verification
- Docker build process
- Setup script execution

