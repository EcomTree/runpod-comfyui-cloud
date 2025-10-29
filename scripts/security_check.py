#!/usr/bin/env python3
"""
Security Check Script for ComfyUI Deployment
Validates configuration security and scans for vulnerabilities.

Usage:
    python security_check.py [--config-dir PATH] [--check-urls] [--scan-nodes]
"""

import argparse
import json
import sys
import re
from pathlib import Path
from urllib.parse import urlparse
from typing import List, Dict, Tuple


class SecurityChecker:
    """Security checker for ComfyUI configuration and deployment."""
    
    def __init__(self, workspace_dir: Path = Path("/workspace")):
        """
        Initialize security checker.
        
        Args:
            workspace_dir: Workspace directory path
        """
        self.workspace_dir = workspace_dir
        self.issues = []
        self.warnings = []
        self.passed = []
    
    def add_issue(self, category: str, message: str, severity: str = "ERROR"):
        """Add a security issue."""
        self.issues.append({
            'category': category,
            'message': message,
            'severity': severity
        })
    
    def add_warning(self, category: str, message: str):
        """Add a security warning."""
        self.warnings.append({
            'category': category,
            'message': message
        })
    
    def add_pass(self, category: str, message: str):
        """Add a passed check."""
        self.passed.append({
            'category': category,
            'message': message
        })
    
    def check_model_urls_https(self, models_file: Path) -> bool:
        """
        Check that all model URLs use HTTPS.
        
        Args:
            models_file: Path to models_download.json
            
        Returns:
            True if all checks passed
        """
        if not models_file.exists():
            self.add_warning("Models", f"Models file not found: {models_file}")
            return False
        
        try:
            with open(models_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            http_urls = []
            for category, items in data.items():
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
            
            if http_urls:
                self.add_issue(
                    "Models",
                    f"Found {len(http_urls)} HTTP URLs (should use HTTPS):\n" + "\n".join(http_urls[:5]),
                    "ERROR"
                )
                return False
            else:
                self.add_pass("Models", "All model URLs use HTTPS ✓")
                return True
                
        except Exception as e:
            self.add_issue("Models", f"Error checking model URLs: {e}", "ERROR")
            return False
    
    def check_custom_nodes_security(self, config_file: Path) -> bool:
        """
        Check custom nodes configuration for security issues.
        
        Args:
            config_file: Path to custom_nodes.json
            
        Returns:
            True if all checks passed
        """
        if not config_file.exists():
            self.add_warning("Custom Nodes", f"Config file not found: {config_file}")
            return False
        
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            nodes = data.get('nodes', [])
            issues_found = False
            
            for node in nodes:
                url = node.get('url', '')
                name = node.get('name', 'unknown')
                
                # Check for HTTPS
                if url.startswith('http://'):
                    self.add_issue(
                        "Custom Nodes",
                        f"Node '{name}' uses HTTP URL: {url}",
                        "ERROR"
                    )
                    issues_found = True
                
                # Check for suspicious patterns in node names
                suspicious_patterns = [
                    r'backdoor',
                    r'malware',
                    r'keylog',
                    r'exploit',
                    r'hack',
                ]
                
                for pattern in suspicious_patterns:
                    if re.search(pattern, name.lower()):
                        self.add_warning(
                            "Custom Nodes",
                            f"Node '{name}' contains suspicious pattern: {pattern}"
                        )
            
            if not issues_found:
                self.add_pass("Custom Nodes", f"Checked {len(nodes)} custom nodes ✓")
            
            return not issues_found
            
        except Exception as e:
            self.add_issue("Custom Nodes", f"Error checking custom nodes: {e}", "ERROR")
            return False
    
    def check_file_permissions(self) -> bool:
        """
        Check file permissions for sensitive files.
        
        Returns:
            True if all checks passed
        """
        sensitive_paths = [
            self.workspace_dir / "ComfyUI" / "extra_model_paths.yaml",
            Path("/home/comfy/.cache"),
        ]
        
        issues_found = False
        
        for path in sensitive_paths:
            if not path.exists():
                continue
            
            stat_info = path.stat()
            mode = stat_info.st_mode & 0o777
            
            # Check if world-readable/writable
            if mode & 0o007:
                self.add_warning(
                    "Permissions",
                    f"File {path} is world-accessible (mode: {oct(mode)})"
                )
                issues_found = True
        
        if not issues_found:
            self.add_pass("Permissions", "File permissions check passed ✓")
        
        return not issues_found
    
    def check_environment_security(self) -> bool:
        """
        Check for insecure environment variable patterns.
        
        Returns:
            True if all checks passed
        """
        import os
        
        issues_found = False
        
        # Check for tokens/passwords in plain environment variables
        sensitive_vars = ['HF_TOKEN', 'JUPYTER_PASSWORD', 'COMFYUI_API_KEY']
        
        for var in sensitive_vars:
            value = os.getenv(var)
            if value:
                # Don't log the actual value
                self.add_pass("Environment", f"{var} is set (value hidden) ✓")
        
        # Warn if running as root
        if os.geteuid() == 0:
            self.add_warning(
                "Environment",
                "Running as root user (not recommended for production)"
            )
            issues_found = True
        else:
            self.add_pass("Environment", "Not running as root ✓")
        
        return not issues_found
    
    def check_api_authentication(self) -> bool:
        """
        Check if API authentication is configured.
        
        Returns:
            True if authentication is enabled
        """
        import os
        
        api_key = os.getenv('COMFYUI_API_KEY')
        
        if not api_key:
            self.add_warning(
                "Authentication",
                "COMFYUI_API_KEY not set - API is not authenticated"
            )
            return False
        else:
            self.add_pass("Authentication", "API key configured ✓")
            return True
    
    def scan_for_secrets(self, directory: Path) -> bool:
        """
        Scan files for potential secrets/credentials.
        
        Args:
            directory: Directory to scan
            
        Returns:
            True if no secrets found
        """
        # Common secret patterns
        secret_patterns = [
            (r'api[_-]?key[\s]*=[\s]*["\']([^"\']+)["\']', 'API Key'),
            (r'password[\s]*=[\s]*["\']([^"\']+)["\']', 'Password'),
            (r'secret[\s]*=[\s]*["\']([^"\']+)["\']', 'Secret'),
            (r'token[\s]*=[\s]*["\']([^"\']+)["\']', 'Token'),
            (r'sk-[a-zA-Z0-9]{48}', 'OpenAI API Key'),
            (r'hf_[a-zA-Z0-9]{32,}', 'Hugging Face Token'),
        ]
        
        issues_found = False
        files_scanned = 0
        
        # Scan Python and JSON files
        for ext in ['*.py', '*.json', '*.yaml', '*.yml']:
            for file_path in directory.rglob(ext):
                # Skip large files and certain directories
                if file_path.stat().st_size > 1_000_000:  # 1MB
                    continue
                if any(part in str(file_path) for part in ['.git', '__pycache__', 'node_modules']):
                    continue
                
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    
                    files_scanned += 1
                    
                    for pattern, secret_type in secret_patterns:
                        matches = re.finditer(pattern, content, re.IGNORECASE)
                        for match in matches:
                            # Don't log the actual secret
                            self.add_warning(
                                "Secrets",
                                f"Potential {secret_type} found in {file_path.name}"
                            )
                            issues_found = True
                            
                except Exception:
                    # Skip files that can't be read
                    continue
        
        if not issues_found and files_scanned > 0:
            self.add_pass("Secrets", f"Scanned {files_scanned} files, no secrets found ✓")
        
        return not issues_found
    
    def check_rate_limiting(self) -> bool:
        """
        Check if rate limiting is implemented.
        
        Returns:
            True if rate limiting is configured
        """
        # This is a placeholder - actual implementation would check ComfyUI config
        self.add_warning(
            "Rate Limiting",
            "Rate limiting not implemented - consider adding for production"
        )
        return False
    
    def run_all_checks(
        self,
        check_urls: bool = True,
        scan_nodes: bool = True,
        scan_secrets: bool = False
    ) -> bool:
        """
        Run all security checks.
        
        Args:
            check_urls: Check model URLs
            scan_nodes: Scan custom nodes
            scan_secrets: Scan for hardcoded secrets
            
        Returns:
            True if all checks passed
        """
        all_passed = True
        
        print("🔒 Running Security Checks...")
        print("=" * 50)
        
        # Check model URLs
        if check_urls:
            models_file = self.workspace_dir.parent / "models_download.json"
            if not models_file.exists():
                models_file = Path("models_download.json")
            if models_file.exists():
                all_passed &= self.check_model_urls_https(models_file)
        
        # Check custom nodes
        if scan_nodes:
            config_file = self.workspace_dir.parent / "configs" / "custom_nodes.json"
            if not config_file.exists():
                config_file = Path("configs/custom_nodes.json")
            if config_file.exists():
                all_passed &= self.check_custom_nodes_security(config_file)
        
        # Check file permissions
        all_passed &= self.check_file_permissions()
        
        # Check environment
        all_passed &= self.check_environment_security()
        
        # Check authentication
        self.check_api_authentication()
        
        # Check rate limiting
        self.check_rate_limiting()
        
        # Scan for secrets
        if scan_secrets:
            scan_dir = self.workspace_dir if self.workspace_dir.exists() else Path(".")
            all_passed &= self.scan_for_secrets(scan_dir)
        
        return all_passed
    
    def print_results(self):
        """Print security check results."""
        print("\n" + "=" * 50)
        print("📊 Security Check Results")
        print("=" * 50)
        
        if self.passed:
            print(f"\n✅ Passed Checks ({len(self.passed)}):")
            for item in self.passed:
                print(f"  • {item['category']}: {item['message']}")
        
        if self.warnings:
            print(f"\n⚠️  Warnings ({len(self.warnings)}):")
            for item in self.warnings:
                print(f"  • {item['category']}: {item['message']}")
        
        if self.issues:
            print(f"\n❌ Issues ({len(self.issues)}):")
            for item in self.issues:
                severity = item['severity']
                print(f"  • [{severity}] {item['category']}: {item['message']}")
        
        print("\n" + "=" * 50)
        
        if not self.issues:
            print("✅ No critical security issues found!")
            return 0
        else:
            print("❌ Security issues found - please review!")
            return 1


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Security checker for ComfyUI deployment",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run all security checks
  python security_check.py
  
  # Run with secret scanning
  python security_check.py --scan-secrets
  
  # Check specific directory
  python security_check.py --workspace-dir /workspace
        """
    )
    
    parser.add_argument(
        '--workspace-dir',
        type=Path,
        default=Path('/workspace'),
        help='Workspace directory path (default: /workspace)'
    )
    
    parser.add_argument(
        '--check-urls',
        action='store_true',
        default=True,
        help='Check model URLs for HTTPS (default: enabled)'
    )
    
    parser.add_argument(
        '--scan-nodes',
        action='store_true',
        default=True,
        help='Scan custom nodes for security issues (default: enabled)'
    )
    
    parser.add_argument(
        '--scan-secrets',
        action='store_true',
        help='Scan files for hardcoded secrets (slow)'
    )
    
    args = parser.parse_args()
    
    # Create checker
    checker = SecurityChecker(workspace_dir=args.workspace_dir)
    
    # Run checks
    checker.run_all_checks(
        check_urls=args.check_urls,
        scan_nodes=args.scan_nodes,
        scan_secrets=args.scan_secrets
    )
    
    # Print results
    exit_code = checker.print_results()
    
    sys.exit(exit_code)


if __name__ == '__main__':
    main()
