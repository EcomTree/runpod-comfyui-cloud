# RunPod Jupyter Lab Fix Guide 🚀

## Problem
Jupyter Lab doesn't start even though `JUPYTER_ENABLE=true` is set in RunPod.

## Root Cause
RunPod environment variables are sometimes not properly passed to the container, resulting in empty values.

## Solution

### Option 1: Rebuild with Fixed Image (Recommended)

The new image version includes automatic detection of RunPod secrets and better error handling.

**Steps:**
1. Stop your current pod
2. Go to your template settings
3. Update the Docker image to the latest version
4. Ensure environment variables are **saved** (click "Save" button!)
5. Deploy a new pod

### Option 2: Manual Workaround (Current Pod)

If you can't redeploy, you can manually start Jupyter:

**SSH into your pod and run:**

```bash
# 1. Check if variables are set
env | grep -E "JUPYTER|DOWNLOAD|RUNPOD"

# 2. If empty, manually export them
export JUPYTER_ENABLE=true
export JUPYTER_ALLOW_NO_AUTH=true
export DOWNLOAD_MODELS=true

# 3. Start Jupyter manually
cd /workspace
nohup jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.token='' \
  --ServerApp.password='' \
  --NotebookApp.token='' \
  --NotebookApp.password='' \
  --notebook-dir="/workspace" \
  > /workspace/logs/jupyter.log 2>&1 &

# 4. Check if it's running
tail -f /workspace/logs/jupyter.log
```

**Access Jupyter:**
- Click the HTTP Services port 8888 in RunPod
- Or use: `https://[your-pod-id]-8888.proxy.runpod.net`

### Option 3: Set as RunPod Secrets

RunPod also supports secrets (more secure for tokens):

1. Go to your RunPod account settings
2. Navigate to "Secrets"
3. Add these secrets:
   - `JUPYTER_ENABLE` = `true`
   - `DOWNLOAD_MODELS` = `true`
   - `HF_TOKEN` = `hf_xxxxx` (if needed)
4. In your template, reference them as:
   - `{{ RUNPOD_SECRET_JUPYTER_ENABLE }}`
   - `{{ RUNPOD_SECRET_DOWNLOAD_MODELS }}`
   - `{{ RUNPOD_SECRET_HF_TOKEN }}`

## Verification

**Check if Jupyter is running:**
```bash
# Method 1: Check process
ps aux | grep jupyter

# Method 2: Check port
netstat -tulpn | grep 8888

# Method 3: Check logs
cat /workspace/logs/jupyter.log
```

## Common Issues

### Issue: "Empty environment variables"
**Symptom:** Logs show `JUPYTER_ENABLE raw='' normalized=''`

**Fix:**
1. Verify you clicked "Save" in RunPod template settings
2. Try restarting the pod (not just the container)
3. Use Option 2 (manual start) as temporary workaround

### Issue: "Port 8888 not accessible"
**Symptom:** Can't connect to Jupyter

**Fix:**
1. Check if port 8888 is exposed in template: `8888:8888`
2. Verify Jupyter is running: `ps aux | grep jupyter`
3. Check firewall: RunPod should auto-configure this

### Issue: "Authentication required"
**Symptom:** Jupyter asks for token/password

**Fix:**
1. Set `JUPYTER_ALLOW_NO_AUTH=true` environment variable
2. Or set a password: `JUPYTER_PASSWORD=YourPassword123`

## Debug Commands

```bash
# Full environment dump
env | sort

# Check container logs
docker logs [container-id]

# Check all running processes
ps aux | grep -E "jupyter|comfyui|python"

# Network check
curl -v http://localhost:8888
```

## Contact

If you still have issues after trying these solutions, check:
- RunPod logs (in pod details)
- Container logs (in terminal)
- GitHub issues: https://github.com/ecomtree/comfyui-cloud/issues

