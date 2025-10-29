"""
Tests for model download system and validation.
"""

import json
import pytest
from pathlib import Path
from urllib.parse import urlparse


@pytest.fixture
def models_json_path():
    """Path to models_download.json file."""
    return Path(__file__).parent.parent / "models_download.json"


@pytest.fixture
def models_data(models_json_path):
    """Load models_download.json data."""
    with open(models_json_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def test_models_json_exists(models_json_path):
    """Test that models_download.json exists."""
    assert models_json_path.exists(), "models_download.json not found"


def test_models_json_valid_structure(models_data):
    """Test that models_download.json has valid structure."""
    assert isinstance(models_data, dict), "models_download.json must be a dict"
    assert len(models_data) > 0, "models_download.json must not be empty"
    
    # Check that values are lists
    for category, items in models_data.items():
        assert isinstance(items, list), f"Category '{category}' must be a list"


def test_all_urls_are_https(models_data):
    """Test that all model URLs use HTTPS protocol."""
    http_urls = []
    
    for category, items in models_data.items():
        for item in items:
            if isinstance(item, str):
                url = item
            elif isinstance(item, dict):
                url = item.get('url', '')
            else:
                continue
            
            parsed = urlparse(url)
            if parsed.scheme == 'http':
                http_urls.append(f"{category}: {url}")
    
    assert len(http_urls) == 0, f"Found HTTP URLs (should be HTTPS):\n" + "\n".join(http_urls)


def test_all_urls_valid_format(models_data):
    """Test that all URLs have valid format."""
    invalid_urls = []
    
    for category, items in models_data.items():
        for item in items:
            if isinstance(item, str):
                url = item
            elif isinstance(item, dict):
                url = item.get('url', '')
            else:
                invalid_urls.append(f"{category}: Invalid item type {type(item)}")
                continue
            
            parsed = urlparse(url)
            if not parsed.scheme or not parsed.netloc:
                invalid_urls.append(f"{category}: {url}")
    
    assert len(invalid_urls) == 0, f"Found invalid URLs:\n" + "\n".join(invalid_urls)


def test_model_categorization(models_data):
    """Test that all models have a category."""
    expected_categories = [
        'checkpoints', 'unet', 'vae', 'clip', 't5', 'clip_vision',
        'controlnet', 'loras', 'upscale_models', 'diffusion_models',
        'animatediff_models', 'text_encoders', 'ipadapter', 't2i_adapter',
        'animatediff', 'video_models', 'flux_gguf', 'sd35_gguf', 'wan_gguf',
        'inpainting', 'style_models'
    ]
    
    for category in models_data.keys():
        assert category in expected_categories, f"Unknown category: {category}"


def test_huggingface_urls_format(models_data):
    """Test that Hugging Face URLs use the correct format."""
    invalid_hf_urls = []
    
    for category, items in models_data.items():
        for item in items:
            if isinstance(item, str):
                url = item
            elif isinstance(item, dict):
                url = item.get('url', '')
            else:
                continue
            
            if 'huggingface.co' in url:
                # HF URLs should use /resolve/ not /blob/
                if '/blob/' in url:
                    invalid_hf_urls.append(f"{category}: {url}")
    
    assert len(invalid_hf_urls) == 0, f"Found HF URLs with /blob/ (should use /resolve/):\n" + "\n".join(invalid_hf_urls)


def test_checksum_format_if_present(models_data):
    """Test that checksums have valid SHA256 format if present."""
    invalid_checksums = []
    
    for category, items in models_data.items():
        for item in items:
            if isinstance(item, dict):
                checksum = item.get('checksum')
                if checksum:
                    # SHA256 should be 64 hex characters
                    if not isinstance(checksum, str) or len(checksum) != 64:
                        invalid_checksums.append(f"{category}: {item.get('url', 'unknown')} - invalid checksum length")
                    elif not all(c in '0123456789abcdefABCDEF' for c in checksum):
                        invalid_checksums.append(f"{category}: {item.get('url', 'unknown')} - invalid checksum format")
    
    assert len(invalid_checksums) == 0, f"Found invalid checksums:\n" + "\n".join(invalid_checksums)


def test_no_duplicate_urls(models_data):
    """Test that there are no duplicate URLs across all categories."""
    seen_urls = {}
    duplicates = []
    
    for category, items in models_data.items():
        for item in items:
            if isinstance(item, str):
                url = item
            elif isinstance(item, dict):
                url = item.get('url', '')
            else:
                continue
            
            if url in seen_urls:
                duplicates.append(f"URL appears in both '{seen_urls[url]}' and '{category}': {url}")
            else:
                seen_urls[url] = category
    
    assert len(duplicates) == 0, f"Found duplicate URLs:\n" + "\n".join(duplicates)


def test_model_count(models_data):
    """Test that there's a reasonable number of models."""
    total_models = sum(len(items) for items in models_data.values())
    
    # Should have at least 100 models
    assert total_models >= 100, f"Expected at least 100 models, found {total_models}"
    
    # Should not exceed 500 models (sanity check)
    assert total_models <= 500, f"Unexpectedly high model count: {total_models}"


def test_category_not_empty(models_data):
    """Test that important categories are not empty."""
    important_categories = ['checkpoints', 'vae', 'unet']
    
    for category in important_categories:
        assert category in models_data, f"Missing important category: {category}"
        assert len(models_data[category]) > 0, f"Category '{category}' is empty"


@pytest.mark.slow
def test_download_single_model_structure():
    """Test that download_models.py can be imported and has expected structure."""
    import sys
    from pathlib import Path
    
    # Add scripts directory to path
    scripts_dir = Path(__file__).parent.parent / "scripts"
    sys.path.insert(0, str(scripts_dir))
    
    try:
        import download_models
        
        # Check for expected classes and functions
        assert hasattr(download_models, 'ComfyUIModelDownloader'), "ComfyUIModelDownloader class not found"
        assert hasattr(download_models, 'verify_checksum'), "verify_checksum function not found"
        assert hasattr(download_models, 'setup_hf_session'), "setup_hf_session function not found"
        
    finally:
        sys.path.pop(0)


def test_verification_script_exists():
    """Test that verify_links.py script exists."""
    verify_script = Path(__file__).parent.parent / "scripts" / "verify_links.py"
    assert verify_script.exists(), "verify_links.py script not found"


def test_model_classification_mapping():
    """Test model classification mapping is comprehensive."""
    import sys
    from pathlib import Path
    
    scripts_dir = Path(__file__).parent.parent / "scripts"
    sys.path.insert(0, str(scripts_dir))
    
    try:
        import download_models
        
        mapping = download_models.MODEL_CLASSIFICATION_MAPPING
        
        # Should have entries for common model types
        directories = [item[0] for item in mapping]
        
        assert 'checkpoints' in directories, "checkpoints not in classification mapping"
        assert 'vae' in directories, "vae not in classification mapping"
        assert 'loras' in directories, "loras not in classification mapping"
        
    finally:
        sys.path.pop(0)
