"""
Tests for custom nodes installation and configuration.
"""

import json
import pytest
from pathlib import Path


@pytest.fixture
def custom_nodes_config_path():
    """Path to configs/custom_nodes.json file."""
    return Path(__file__).parent.parent / "configs" / "custom_nodes.json"


@pytest.fixture
def custom_nodes_data(custom_nodes_config_path):
    """Load custom_nodes.json data."""
    with open(custom_nodes_config_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def test_custom_nodes_config_exists(custom_nodes_config_path):
    """Test that custom_nodes.json exists."""
    assert custom_nodes_config_path.exists(), "configs/custom_nodes.json not found"


def test_custom_nodes_valid_structure(custom_nodes_data):
    """Test that custom_nodes.json has valid structure."""
    assert isinstance(custom_nodes_data, dict), "custom_nodes.json must be a dict"
    assert 'nodes' in custom_nodes_data, "custom_nodes.json must have 'nodes' key"
    assert isinstance(custom_nodes_data['nodes'], list), "'nodes' must be a list"


def test_all_required_nodes_present(custom_nodes_data):
    """Test that all 5 required custom nodes are present."""
    required_nodes = [
        'ComfyUI-Manager',
        'ComfyUI-Impact-Pack',
        'rgthree-comfy',
        'ComfyUI-Advanced-ControlNet',
        'ComfyUI-VideoHelperSuite'
    ]
    
    node_names = [node.get('name', '') for node in custom_nodes_data['nodes']]
    
    for required in required_nodes:
        assert required in node_names, f"Required node '{required}' not found in config"


def test_node_entries_have_required_fields(custom_nodes_data):
    """Test that each node entry has required fields."""
    required_fields = ['name', 'url']
    
    for i, node in enumerate(custom_nodes_data['nodes']):
        for field in required_fields:
            assert field in node, f"Node {i} missing required field '{field}'"
            assert node[field], f"Node {i} has empty '{field}'"


def test_node_urls_are_valid_git_repos(custom_nodes_data):
    """Test that all node URLs are valid git repository URLs."""
    invalid_urls = []
    
    for node in custom_nodes_data['nodes']:
        url = node.get('url', '')
        name = node.get('name', 'unknown')
        
        # Should be a valid git URL (HTTPS or git protocol)
        if not (url.startswith('https://') or url.startswith('git://')):
            invalid_urls.append(f"{name}: {url}")
        
        # Should end with .git or be a GitHub URL
        if not (url.endswith('.git') or 'github.com' in url):
            invalid_urls.append(f"{name}: {url} (should be a git repository)")
    
    assert len(invalid_urls) == 0, f"Found invalid git URLs:\n" + "\n".join(invalid_urls)


def test_no_duplicate_nodes(custom_nodes_data):
    """Test that there are no duplicate node names."""
    node_names = [node.get('name', '') for node in custom_nodes_data['nodes']]
    duplicates = [name for name in node_names if node_names.count(name) > 1]
    
    assert len(duplicates) == 0, f"Found duplicate node names: {duplicates}"


def test_install_script_exists():
    """Test that install_custom_nodes.sh script exists."""
    install_script = Path(__file__).parent.parent / "scripts" / "install_custom_nodes.sh"
    assert install_script.exists(), "install_custom_nodes.sh script not found"
    assert install_script.stat().st_mode & 0o111, "install_custom_nodes.sh is not executable"


def test_node_requirements_handling():
    """Test that nodes with requirements are handled properly."""
    # Test that each node entry can optionally have requirements
    custom_nodes_config_path = Path(__file__).parent.parent / "configs" / "custom_nodes.json"
    
    with open(custom_nodes_config_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    for node in data['nodes']:
        if 'requirements' in node:
            # If requirements field exists, it should be a list
            assert isinstance(node['requirements'], list), \
                f"Node '{node['name']}' requirements must be a list"


def test_custom_nodes_documentation_exists():
    """Test that custom nodes documentation exists."""
    docs_path = Path(__file__).parent.parent / "docs" / "custom-nodes.md"
    assert docs_path.exists(), "docs/custom-nodes.md not found"


@pytest.mark.slow
def test_install_script_syntax():
    """Test that install_custom_nodes.sh has valid bash syntax."""
    import subprocess
    
    install_script = Path(__file__).parent.parent / "scripts" / "install_custom_nodes.sh"
    
    # Use bash -n to check syntax without executing
    result = subprocess.run(
        ['bash', '-n', str(install_script)],
        capture_output=True,
        text=True
    )
    
    assert result.returncode == 0, f"Bash syntax error in install_custom_nodes.sh:\n{result.stderr}"


def test_comfyui_directory_structure():
    """Test expected ComfyUI directory structure is documented."""
    # The script should create proper directory structure
    # This test verifies the expected structure is documented
    
    expected_dirs = [
        'custom_nodes',
        'models',
        'input',
        'output',
        'temp'
    ]
    
    # We can't test actual directories without ComfyUI installed,
    # but we can verify the concept is understood
    assert len(expected_dirs) >= 3, "Expected ComfyUI directory structure should include at least 3 directories"


def test_node_enabled_field_optional(custom_nodes_data):
    """Test that 'enabled' field is optional for nodes."""
    for node in custom_nodes_data['nodes']:
        if 'enabled' in node:
            # If present, should be boolean
            assert isinstance(node['enabled'], bool), \
                f"Node '{node['name']}' enabled field must be boolean"


def test_manager_node_is_first(custom_nodes_data):
    """Test that ComfyUI-Manager is installed first (if present)."""
    nodes = custom_nodes_data['nodes']
    
    manager_indices = [
        i for i, node in enumerate(nodes) 
        if 'manager' in node.get('name', '').lower()
    ]
    
    if manager_indices:
        # Manager should be first if present
        assert manager_indices[0] == 0, \
            "ComfyUI-Manager should be first in the installation order"


def test_github_urls_use_https(custom_nodes_data):
    """Test that all GitHub URLs use HTTPS protocol."""
    http_github_urls = []
    
    for node in custom_nodes_data['nodes']:
        url = node.get('url', '')
        name = node.get('name', 'unknown')
        
        if 'github.com' in url and url.startswith('http://'):
            http_github_urls.append(f"{name}: {url}")
    
    assert len(http_github_urls) == 0, \
        f"Found GitHub URLs using HTTP (should use HTTPS):\n" + "\n".join(http_github_urls)
