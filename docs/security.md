# Security Best Practices for ComfyUI RunPod Deployment

This document outlines security best practices and recommendations for deploying ComfyUI on RunPod.

## Table of Contents

- [Overview](#overview)
- [API Authentication](#api-authentication)
- [Network Security](#network-security)
- [Container Security](#container-security)
- [File Permissions](#file-permissions)
- [Secret Management](#secret-management)
- [Security Scanning](#security-scanning)
- [Production Checklist](#production-checklist)

## Overview

Security is critical when deploying ComfyUI in production environments. This guide covers:

- **API authentication** - Protecting your ComfyUI API
- **Network security** - Firewall and access control
- **Container hardening** - Secure Docker configuration
- **Secret management** - Handling tokens and passwords
- **Vulnerability scanning** - Regular security audits

## API Authentication

### Enable API Key Authentication

ComfyUI API can be protected with an API key using the `COMFYUI_API_KEY` environment variable.

**Set API key:**

```bash
# Generate a strong random key
openssl rand -hex 32

# Set in RunPod environment variables
COMFYUI_API_KEY=your-secure-api-key-here
```

**Using API key in requests:**

```bash
# Add Authorization header to all API requests
curl -H "Authorization: Bearer your-secure-api-key-here" \
     http://your-pod-ip:8188/queue
```

### Jupyter Lab Password Protection

Always enable password protection for Jupyter Lab in production:

```bash
# Set strong password
JUPYTER_PASSWORD=YourSecurePassword123!
JUPYTER_ENABLE=true
```

**Generate hashed password:**

```python
from jupyter_server.auth import passwd
passwd('YourSecurePassword123!')
```

### Best Practices

- ✅ **Use strong, random API keys** (32+ characters)
- ✅ **Rotate keys regularly** (every 90 days)
- ✅ **Never commit keys to git** (use environment variables)
- ✅ **Use different keys for dev/prod** environments
- ❌ **Don't disable authentication** in production
- ❌ **Don't share API keys** in logs or URLs

## Network Security

### Firewall Configuration

**RunPod Pod Firewall:**

1. **Only expose required ports:**
   - `8188` - ComfyUI API (required)
   - `8888` - Jupyter Lab (optional, dev only)
   - `9090` - Prometheus (optional, internal only)

2. **Use RunPod's built-in security:**
   - Pods are isolated by default
   - Only exposed ports are accessible
   - Use RunPod's proxy for HTTPS

### IP Whitelisting

Consider restricting access to known IP addresses:

```bash
# Example with nginx proxy (if using custom setup)
allow 203.0.113.0/24;  # Your office IP range
deny all;
```

### HTTPS/TLS

**For production deployments:**

1. **Use RunPod's HTTPS proxy**
   - Automatic TLS termination
   - Free Let's Encrypt certificates

2. **Or configure custom reverse proxy:**
   ```nginx
   server {
       listen 443 ssl;
       server_name comfyui.yourdomain.com;
       
       ssl_certificate /path/to/cert.pem;
       ssl_certificate_key /path/to/key.pem;
       
       location / {
           proxy_pass http://localhost:8188;
       }
   }
   ```

### CORS Configuration

ComfyUI startup includes `--enable-cors-header` for cross-origin requests.

**Restrict CORS in production:**

```bash
# Modify start script to restrict origins
--enable-cors-header https://yourdomain.com
```

## Container Security

### Non-Root User

The Docker image already runs as non-root user `comfy`:

```dockerfile
# Already implemented in Dockerfile
USER comfy
```

**Verify:**
```bash
docker exec <container> whoami
# Output: comfy
```

### Read-Only Filesystem

For enhanced security, mount certain directories as read-only:

```bash
docker run --read-only \
  -v /workspace:/workspace \
  -v /tmp:/tmp \
  comfyui-cloud:latest
```

### File Permissions

**Cache directory permissions:**

```bash
# Already set in Dockerfile
chmod 700 /home/comfy/.cache
```

**Check permissions:**
```bash
ls -la /home/comfy/.cache
# Should show: drwx------ comfy comfy
```

### Sensitive File Protection

```bash
# Protect config files
chmod 600 /workspace/ComfyUI/extra_model_paths.yaml

# Protect environment files
chmod 600 .env
```

## Secret Management

### Environment Variables

**✅ Recommended approach:**

```bash
# Use environment variables (not hardcoded)
export HF_TOKEN="hf_xxxxxxxxxxxxx"
export COMFYUI_API_KEY="xxxxxxxxxxxxx"
export JUPYTER_PASSWORD="xxxxxxxxxxxxx"
```

**❌ Never do this:**

```python
# DON'T hardcode secrets in code
HF_TOKEN = "hf_xxxxxxxxxxxxx"  # Bad!
```

### RunPod Secrets

Use RunPod's secret management:

1. Go to RunPod Dashboard
2. Navigate to **Settings** → **Secrets**
3. Add secrets:
   - `HF_TOKEN`
   - `COMFYUI_API_KEY`
   - `JUPYTER_PASSWORD`

4. Reference in template:
   ```json
   {
     "env": [
       {
         "key": "HF_TOKEN",
         "value": "${{ secrets.HF_TOKEN }}"
       }
     ]
   }
   ```

### .gitignore

Ensure sensitive files are not committed:

```gitignore
# Secrets and credentials
.env
.env.*
*.key
*.pem
*.p12

# Jupyter configs
.jupyter/
jupyter_server_config.py

# Model downloads (large files)
ComfyUI/models/
downloaded_models_summary.json
```

## Security Scanning

### Running Security Checks

Use the included security check script:

```bash
# Basic security scan
python scripts/security_check.py

# With secret scanning (slower)
python scripts/security_check.py --scan-secrets

# Custom workspace directory
python scripts/security_check.py --workspace-dir /custom/path
```

**Output example:**
```
🔒 Running Security Checks...
==================================================
✅ Passed Checks (5):
  • Models: All model URLs use HTTPS ✓
  • Custom Nodes: Checked 5 custom nodes ✓
  • Permissions: File permissions check passed ✓
  • Environment: Not running as root ✓
  • Authentication: API key configured ✓

⚠️  Warnings (2):
  • Authentication: Jupyter password not set
  • Rate Limiting: Rate limiting not implemented

❌ No critical security issues found!
```

### Automated Scanning

**GitHub Actions (CI/CD):**

Already configured in `.github/workflows/test.yml`:

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'
```

**Manual Docker scanning:**

```bash
# Scan Docker image with Trivy
trivy image comfyui-cloud:latest

# Scan for critical vulnerabilities only
trivy image --severity CRITICAL,HIGH comfyui-cloud:latest
```

### Dependency Scanning

**Check Python dependencies:**

```bash
# Install safety
pip install safety

# Scan requirements.txt
safety check -r requirements.txt

# Scan installed packages
safety check
```

## Production Checklist

### Pre-Deployment

- [ ] **Enable API authentication** (`COMFYUI_API_KEY` set)
- [ ] **Set Jupyter password** (`JUPYTER_PASSWORD` set)
- [ ] **Use HTTPS** (RunPod proxy or custom TLS)
- [ ] **Limit exposed ports** (only 8188 required)
- [ ] **Review file permissions** (chmod 700 for cache)
- [ ] **Scan for secrets** (no hardcoded credentials)
- [ ] **Update dependencies** (latest security patches)
- [ ] **Run security scan** (`python scripts/security_check.py`)

### Post-Deployment

- [ ] **Monitor logs** for unauthorized access attempts
- [ ] **Set up alerts** for suspicious activity
- [ ] **Regular backups** of workspace data
- [ ] **Rotate secrets** every 90 days
- [ ] **Review access logs** monthly
- [ ] **Update Docker image** quarterly

### Monitoring

**Enable security monitoring:**

```bash
# Monitor API access
tail -f /workspace/logs/comfyui.log | grep "401\|403\|500"

# Monitor GPU usage (detect crypto mining)
python scripts/monitor.py --interval 10

# Check for unusual network activity
netstat -tuln
```

## Common Vulnerabilities

### 1. Exposed Jupyter Without Auth

**Risk:** Unauthorized code execution

**Solution:**
```bash
JUPYTER_ENABLE=true
JUPYTER_PASSWORD=YourSecurePassword
```

### 2. HTTP Model Downloads

**Risk:** Man-in-the-middle attacks

**Solution:** All models already use HTTPS (verified by tests)

### 3. World-Readable Cache

**Risk:** Information disclosure

**Solution:**
```bash
chmod 700 /home/comfy/.cache
```

### 4. Hardcoded Secrets

**Risk:** Credential exposure

**Solution:** Use environment variables and RunPod secrets

### 5. Running as Root

**Risk:** Container escape, privilege escalation

**Solution:** Already runs as `comfy` user (verified)

## Incident Response

### If Compromised

1. **Immediately:**
   - Stop the pod
   - Rotate all API keys and passwords
   - Review access logs
   
2. **Investigate:**
   - Check `/workspace/logs/` for suspicious activity
   - Review model downloads for tampering
   - Scan for backdoors in custom nodes

3. **Remediate:**
   - Deploy fresh image
   - Restore from clean backup
   - Apply security patches

4. **Prevent:**
   - Enable additional monitoring
   - Implement stricter access controls
   - Review security checklist

## Additional Resources

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [RunPod Security Best Practices](https://docs.runpod.io/docs/security)
- [ComfyUI Security Considerations](https://github.com/comfyanonymous/ComfyUI/wiki/Security)

## Security Contacts

**Report vulnerabilities:**
- GitHub: Open a security advisory
- Email: [Maintainer contact from README]

**Response time:** 48 hours for critical issues

---

**Last Updated:** 2025-10-29

**Security Version:** 1.0
