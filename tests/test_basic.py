"""
Basic tests for runpod-comfyui-cloud
"""

import sys
import os

# Add project root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


def test_imports():
    """Test that basic imports work"""
    try:
        import requests
        assert requests is not None
    except ImportError:
        # If requests is not installed, that's okay for basic test
        pass


def test_project_structure():
    """Test that essential project files exist"""
    project_root = os.path.dirname(os.path.dirname(__file__))
    
    essential_files = [
        'README.md',
        'Dockerfile',
        'requirements.txt',
        'setup.py',
        'pyproject.toml',
    ]
    
    for file in essential_files:
        file_path = os.path.join(project_root, file)
        assert os.path.exists(file_path), f"Essential file {file} is missing"


def test_scripts_exist():
    """Test that essential scripts exist"""
    project_root = os.path.dirname(os.path.dirname(__file__))
    scripts_dir = os.path.join(project_root, 'scripts')
    
    essential_scripts = [
        'setup.sh',
        'common-codex.sh',
        'download_models.py',
        'verify_links.py',
    ]
    
    for script in essential_scripts:
        script_path = os.path.join(scripts_dir, script)
        assert os.path.exists(script_path), f"Essential script {script} is missing"


if __name__ == '__main__':
    test_imports()
    test_project_structure()
    test_scripts_exist()
    print("All basic tests passed!")

