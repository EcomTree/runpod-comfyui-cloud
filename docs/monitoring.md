# ComfyUI GPU Monitoring & Health Checks

This document describes the GPU monitoring and health check infrastructure for the ComfyUI RunPod deployment.

## Overview

The monitoring system provides:

- **Real-time GPU monitoring** - Utilization, VRAM usage, temperature, power consumption
- **Workflow tracking** - Monitor ComfyUI queue status and execution times
- **Health checks** - Automated system health validation
- **Prometheus integration** - Optional metrics export for visualization (Grafana)

## Components

### 1. GPU Monitor (`scripts/monitor.py`)

A Python-based monitoring tool that tracks GPU and ComfyUI metrics in real-time.

#### Features

- **GPU Statistics**
  - Utilization percentage
  - VRAM usage (used/total)
  - Temperature (°C)
  - Power consumption (Watts)
  - Support for multiple GPUs

- **ComfyUI Queue Monitoring**
  - Pending queue items
  - Running queue items

- **Logging**
  - JSON-formatted logs to file
  - Human-readable console output

- **Prometheus Metrics** (optional)
  - Expose metrics on HTTP port for scraping
  - Compatible with Grafana dashboards

#### Usage

**Basic monitoring (5-second interval):**
```bash
python scripts/monitor.py
```

**Custom interval:**
```bash
python scripts/monitor.py --interval 10
```

**Enable Prometheus metrics:**
```bash
python scripts/monitor.py --prometheus-port 9090
```

**Custom log file:**
```bash
python scripts/monitor.py --log-file /workspace/logs/gpu.log
```

**Get current summary (no continuous monitoring):**
```bash
python scripts/monitor.py --summary
```

**Run as background service:**
```bash
nohup python scripts/monitor.py --prometheus-port 9090 > /workspace/logs/monitor_daemon.log 2>&1 &
```

#### Requirements

```bash
pip install pynvml>=11.5.0
pip install prometheus-client>=0.16.0  # Optional, for Prometheus support
```

These are already included in `requirements.txt`.

### 2. Health Check Script (`scripts/health_check.sh`)

A bash script that validates system health and can be used for automated monitoring or container orchestration.

#### Checks Performed

1. **ComfyUI API** - Verifies API is responding
2. **GPU Availability** - Checks nvidia-smi access
3. **VRAM Usage** - Warns if VRAM usage exceeds threshold (default: 95%)
4. **Queue Size** - Monitors queue for congestion
5. **Disk Space** - Checks /workspace disk usage

#### Usage

**Basic health check:**
```bash
bash scripts/health_check.sh
```

**Exit codes:**
- `0` - All checks passed (healthy)
- `1` - One or more checks failed (unhealthy)

**With Docker healthcheck:**

This script is already integrated into the Dockerfile as a health check:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
    CMD bash /opt/runpod/scripts/health_check.sh || exit 1
```

**Environment Variables:**

- `COMFYUI_URL` - ComfyUI API URL (default: `http://localhost:8188`)
- `VRAM_THRESHOLD_PERCENT` - VRAM warning threshold (default: `95`)
- `MAX_QUEUE_SIZE` - Maximum queue size before warning (default: `100`)

Example:
```bash
VRAM_THRESHOLD_PERCENT=90 bash scripts/health_check.sh
```

### 3. Log Files

#### Monitor Log (`/workspace/logs/monitor.log`)

JSON-formatted log entries with timestamped GPU and queue statistics:

```json
{
  "timestamp": "2025-10-29T12:34:56.789123",
  "gpus": [
    {
      "gpu_id": 0,
      "name": "NVIDIA H200",
      "utilization_percent": 87,
      "memory_used_mb": 45678.5,
      "memory_total_mb": 81920.0,
      "memory_percent": 55.8,
      "temperature_celsius": 72,
      "power_watts": 350.2
    }
  ],
  "queue": {
    "pending": 3,
    "running": 1
  }
}
```

#### Accessing Logs

**View recent entries:**
```bash
tail -20 /workspace/logs/monitor.log
```

**Watch live updates:**
```bash
tail -f /workspace/logs/monitor.log
```

**Parse JSON logs:**
```bash
cat /workspace/logs/monitor.log | jq '.gpus[0].utilization_percent'
```

**Filter by timestamp:**
```bash
grep "2025-10-29T12" /workspace/logs/monitor.log
```

## Prometheus Integration

### Setup

1. **Start monitor with Prometheus:**
```bash
python scripts/monitor.py --prometheus-port 9090
```

2. **Configure Prometheus scraper** (`prometheus.yml`):
```yaml
scrape_configs:
  - job_name: 'comfyui'
    static_configs:
      - targets: ['localhost:9090']
```

3. **Available metrics:**
- `comfyui_gpu_utilization_percent{gpu_id="0"}` - GPU utilization
- `comfyui_gpu_memory_used_mb{gpu_id="0"}` - VRAM used (MB)
- `comfyui_gpu_memory_total_mb{gpu_id="0"}` - VRAM total (MB)
- `comfyui_gpu_temperature_celsius{gpu_id="0"}` - GPU temperature
- `comfyui_gpu_power_watts{gpu_id="0"}` - Power consumption
- `comfyui_queue_pending` - Pending queue items
- `comfyui_queue_running` - Running queue items
- `comfyui_workflow_executions_total` - Total workflow executions
- `comfyui_workflow_errors_total` - Total workflow errors

### Grafana Dashboard

You can create a Grafana dashboard with panels for:

- GPU utilization over time (line chart)
- VRAM usage over time (area chart)
- GPU temperature (gauge)
- Queue status (stat panels)
- Workflow throughput (rate calculation)

Example PromQL queries:

**Average GPU utilization:**
```promql
avg(comfyui_gpu_utilization_percent)
```

**VRAM usage percentage:**
```promql
(comfyui_gpu_memory_used_mb / comfyui_gpu_memory_total_mb) * 100
```

**Workflow execution rate (per minute):**
```promql
rate(comfyui_workflow_executions_total[5m]) * 60
```

## Troubleshooting

### Monitor not showing GPU stats

**Problem:** GPU statistics showing as "No GPU stats available"

**Solutions:**
1. Install pynvml: `pip install pynvml>=11.5.0`
2. Check nvidia-smi access: `nvidia-smi`
3. Verify CUDA drivers are installed
4. Check container has GPU access: `docker run --gpus all ...`

### Health check failing

**Problem:** Health check returns exit code 1

**Solutions:**
1. Check ComfyUI is running: `curl http://localhost:8188/queue`
2. Verify GPU access: `nvidia-smi`
3. Check VRAM usage: `nvidia-smi --query-gpu=memory.used,memory.total --format=csv`
4. Review health check logs in Docker: `docker logs <container_id>`

### Prometheus metrics not accessible

**Problem:** Cannot access Prometheus metrics endpoint

**Solutions:**
1. Verify monitor started with `--prometheus-port` flag
2. Check port is exposed in Docker: `-p 9090:9090`
3. Test locally: `curl http://localhost:9090/metrics`
4. Check firewall rules on RunPod

### Log file not being created

**Problem:** `/workspace/logs/monitor.log` is missing

**Solutions:**
1. Ensure /workspace is mounted as volume
2. Check directory permissions: `ls -la /workspace/logs/`
3. Try manual creation: `mkdir -p /workspace/logs && touch /workspace/logs/monitor.log`
4. Verify script has write permissions

## Best Practices

### Production Monitoring

1. **Run monitor as background service**
   ```bash
   nohup python scripts/monitor.py --prometheus-port 9090 > /workspace/logs/monitor_daemon.log 2>&1 &
   ```

2. **Set up log rotation** to prevent disk space issues
   ```bash
   # Truncate old logs
   find /workspace/logs/ -name "*.log" -mtime +7 -exec truncate -s 0 {} \;
   ```

3. **Use Prometheus + Grafana** for visualization and alerting

4. **Configure alerts** for critical thresholds:
   - VRAM usage > 90%
   - GPU temperature > 85°C
   - Queue size > 50

### Development Monitoring

1. **Use summary mode** for quick checks
   ```bash
   python scripts/monitor.py --summary
   ```

2. **Monitor with short interval** during debugging
   ```bash
   python scripts/monitor.py --interval 1
   ```

3. **Tail logs** in separate terminal
   ```bash
   tail -f /workspace/logs/monitor.log | jq .
   ```

## Integration with RunPod

### RunPod Template Configuration

Add monitoring to your RunPod template environment variables:

```json
{
  "MONITOR_ENABLED": "true",
  "MONITOR_INTERVAL": "5",
  "PROMETHEUS_PORT": "9090"
}
```

### Startup Script Integration

Add to your `start_comfyui_h200.sh`:

```bash
# Start GPU monitoring in background
if [ "${MONITOR_ENABLED:-false}" = "true" ]; then
    echo "🔍 Starting GPU monitoring..."
    python3 /opt/runpod/scripts/monitor.py \
        --interval ${MONITOR_INTERVAL:-5} \
        --prometheus-port ${PROMETHEUS_PORT:-9090} \
        > /workspace/logs/monitor_daemon.log 2>&1 &
    echo "✅ Monitoring started"
fi
```

### Health Check Integration

The health check script is already integrated into the Dockerfile as a container healthcheck. You can manually run it:

```bash
docker exec <container_id> bash /opt/runpod/scripts/health_check.sh
```

## Performance Impact

- **GPU Monitor:** Minimal overhead (~0.1% GPU utilization, ~50MB RAM)
- **Health Check:** Negligible (runs every 30s, completes in <1s)
- **Prometheus:** ~20MB RAM for metrics storage

## See Also

- [Performance Tuning Guide](performance-tuning.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Environment Variables](environment-variables.md)

---

**Last Updated:** 2025-10-29
