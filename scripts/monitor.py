#!/usr/bin/env python3
"""
GPU Monitoring Script for ComfyUI
Monitors GPU utilization, VRAM usage, and workflow execution times.

Usage:
    python monitor.py [--interval SECONDS] [--log-file PATH] [--prometheus-port PORT]
"""

import argparse
import json
import time
import sys
import os
import signal
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List
import requests

try:
    import pynvml
    PYNVML_AVAILABLE = True
except ImportError:
    PYNVML_AVAILABLE = False
    print("⚠️  pynvml not available. Install with: pip install pynvml")

# Optional Prometheus metrics support
try:
    from prometheus_client import start_http_server, Gauge, Counter
    PROMETHEUS_AVAILABLE = True
except ImportError:
    PROMETHEUS_AVAILABLE = False


class GPUMonitor:
    """Monitor GPU statistics and ComfyUI workflow execution."""
    
    def __init__(
        self,
        interval: int = 5,
        log_file: Optional[Path] = None,
        prometheus_port: Optional[int] = None,
        comfyui_url: str = "http://localhost:8188"
    ):
        """
        Initialize GPU monitor.
        
        Args:
            interval: Polling interval in seconds
            log_file: Path to log file
            prometheus_port: Port for Prometheus metrics server (optional)
            comfyui_url: ComfyUI API URL
        """
        self.interval = interval
        self.log_file = log_file or Path("/workspace/logs/monitor.log")
        self.prometheus_port = prometheus_port
        self.comfyui_url = comfyui_url
        self.running = True
        
        # Ensure log directory exists
        self.log_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize NVML if available
        if PYNVML_AVAILABLE:
            try:
                pynvml.nvmlInit()
                self.device_count = pynvml.nvmlDeviceGetCount()
                print(f"✅ Detected {self.device_count} GPU(s)")
            except Exception as e:
                print(f"❌ Failed to initialize NVML: {e}")
                self.device_count = 0
        else:
            self.device_count = 0
        
        # Initialize Prometheus metrics if enabled
        self.prometheus_metrics = {}
        if prometheus_port and PROMETHEUS_AVAILABLE:
            self._init_prometheus_metrics()
            try:
                start_http_server(prometheus_port)
                print(f"✅ Prometheus metrics available at http://localhost:{prometheus_port}")
            except Exception as e:
                print(f"❌ Failed to start Prometheus server: {e}")
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _init_prometheus_metrics(self):
        """Initialize Prometheus metrics gauges and counters."""
        self.prometheus_metrics = {
            'gpu_utilization': Gauge('comfyui_gpu_utilization_percent', 'GPU utilization percentage', ['gpu_id']),
            'gpu_memory_used': Gauge('comfyui_gpu_memory_used_mb', 'GPU memory used in MB', ['gpu_id']),
            'gpu_memory_total': Gauge('comfyui_gpu_memory_total_mb', 'GPU memory total in MB', ['gpu_id']),
            'gpu_temperature': Gauge('comfyui_gpu_temperature_celsius', 'GPU temperature in Celsius', ['gpu_id']),
            'gpu_power_usage': Gauge('comfyui_gpu_power_watts', 'GPU power usage in Watts', ['gpu_id']),
            'workflow_executions': Counter('comfyui_workflow_executions_total', 'Total workflow executions'),
            'workflow_errors': Counter('comfyui_workflow_errors_total', 'Total workflow errors'),
            'queue_pending': Gauge('comfyui_queue_pending', 'Number of pending queue items'),
            'queue_running': Gauge('comfyui_queue_running', 'Number of running queue items'),
        }
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully."""
        print(f"\n🛑 Received signal {signum}, shutting down...")
        self.running = False
    
    def get_gpu_stats(self) -> List[Dict]:
        """
        Get current GPU statistics.
        
        Returns:
            List of dicts containing GPU stats for each device
        """
        if not PYNVML_AVAILABLE or self.device_count == 0:
            return []
        
        stats = []
        for i in range(self.device_count):
            try:
                handle = pynvml.nvmlDeviceGetHandleByIndex(i)
                
                # Get GPU name
                name = pynvml.nvmlDeviceGetName(handle)
                if isinstance(name, bytes):
                    name = name.decode('utf-8')
                
                # Get utilization
                utilization = pynvml.nvmlDeviceGetUtilizationRates(handle)
                
                # Get memory info
                memory = pynvml.nvmlDeviceGetMemoryInfo(handle)
                
                # Get temperature
                try:
                    temperature = pynvml.nvmlDeviceGetTemperature(handle, pynvml.NVML_TEMPERATURE_GPU)
                except:
                    temperature = None
                
                # Get power usage
                try:
                    power = pynvml.nvmlDeviceGetPowerUsage(handle) / 1000.0  # Convert mW to W
                except:
                    power = None
                
                gpu_stat = {
                    'gpu_id': i,
                    'name': name,
                    'utilization_percent': utilization.gpu,
                    'memory_used_mb': memory.used / (1024 * 1024),
                    'memory_total_mb': memory.total / (1024 * 1024),
                    'memory_percent': (memory.used / memory.total) * 100,
                    'temperature_celsius': temperature,
                    'power_watts': power,
                }
                
                stats.append(gpu_stat)
                
                # Update Prometheus metrics if enabled
                if self.prometheus_metrics:
                    gpu_id_str = str(i)
                    self.prometheus_metrics['gpu_utilization'].labels(gpu_id=gpu_id_str).set(utilization.gpu)
                    self.prometheus_metrics['gpu_memory_used'].labels(gpu_id=gpu_id_str).set(memory.used / (1024 * 1024))
                    self.prometheus_metrics['gpu_memory_total'].labels(gpu_id=gpu_id_str).set(memory.total / (1024 * 1024))
                    if temperature is not None:
                        self.prometheus_metrics['gpu_temperature'].labels(gpu_id=gpu_id_str).set(temperature)
                    if power is not None:
                        self.prometheus_metrics['gpu_power_usage'].labels(gpu_id=gpu_id_str).set(power)
                
            except Exception as e:
                print(f"⚠️  Error getting stats for GPU {i}: {e}")
        
        return stats
    
    def get_comfyui_queue_status(self) -> Optional[Dict]:
        """
        Get ComfyUI queue status.
        
        Returns:
            Dict with queue info or None if unavailable
        """
        try:
            response = requests.get(f"{self.comfyui_url}/queue", timeout=5)
            if response.status_code == 200:
                data = response.json()
                
                queue_info = {
                    'pending': len(data.get('queue_pending', [])),
                    'running': len(data.get('queue_running', [])),
                }
                
                # Update Prometheus metrics if enabled
                if self.prometheus_metrics:
                    self.prometheus_metrics['queue_pending'].set(queue_info['pending'])
                    self.prometheus_metrics['queue_running'].set(queue_info['running'])
                
                return queue_info
        except Exception as e:
            # Don't spam errors if ComfyUI is not running
            pass
        
        return None
    
    def log_stats(self, stats: Dict):
        """
        Log statistics to file and stdout.
        
        Args:
            stats: Dict containing monitoring statistics
        """
        timestamp = datetime.now().isoformat()
        log_entry = {
            'timestamp': timestamp,
            **stats
        }
        
        # Write to log file
        try:
            with open(self.log_file, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
        except Exception as e:
            print(f"⚠️  Error writing to log file: {e}")
        
        # Print to stdout (formatted)
        print(f"\n[{timestamp}]")
        
        if 'gpus' in stats and stats['gpus']:
            for gpu in stats['gpus']:
                print(f"GPU {gpu['gpu_id']} ({gpu['name']}):")
                print(f"  Utilization: {gpu['utilization_percent']}%")
                print(f"  VRAM: {gpu['memory_used_mb']:.1f} MB / {gpu['memory_total_mb']:.1f} MB ({gpu['memory_percent']:.1f}%)")
                if gpu['temperature_celsius'] is not None:
                    print(f"  Temperature: {gpu['temperature_celsius']}°C")
                if gpu['power_watts'] is not None:
                    print(f"  Power: {gpu['power_watts']:.1f} W")
        else:
            print("  No GPU stats available")
        
        if 'queue' in stats and stats['queue']:
            print(f"ComfyUI Queue:")
            print(f"  Pending: {stats['queue']['pending']}")
            print(f"  Running: {stats['queue']['running']}")
    
    def monitor_loop(self):
        """Main monitoring loop."""
        print(f"🔍 Starting GPU monitoring (interval: {self.interval}s)")
        print(f"📋 Logging to: {self.log_file}")
        print("Press Ctrl+C to stop\n")
        
        while self.running:
            try:
                # Collect stats
                gpu_stats = self.get_gpu_stats()
                queue_status = self.get_comfyui_queue_status()
                
                stats = {
                    'gpus': gpu_stats,
                    'queue': queue_status,
                }
                
                # Log stats
                self.log_stats(stats)
                
                # Sleep until next interval
                time.sleep(self.interval)
                
            except Exception as e:
                print(f"❌ Error in monitoring loop: {e}")
                time.sleep(self.interval)
        
        # Cleanup
        if PYNVML_AVAILABLE:
            try:
                pynvml.nvmlShutdown()
            except:
                pass
        
        print("\n✅ Monitoring stopped")
    
    def get_summary(self) -> Dict:
        """
        Get current monitoring summary.
        
        Returns:
            Dict with summary statistics
        """
        gpu_stats = self.get_gpu_stats()
        queue_status = self.get_comfyui_queue_status()
        
        return {
            'timestamp': datetime.now().isoformat(),
            'gpus': gpu_stats,
            'queue': queue_status,
        }


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="GPU monitoring for ComfyUI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Monitor with default settings (5s interval)
  python monitor.py
  
  # Monitor with custom interval
  python monitor.py --interval 10
  
  # Enable Prometheus metrics
  python monitor.py --prometheus-port 9090
  
  # Custom log file location
  python monitor.py --log-file /workspace/logs/gpu_monitor.log
        """
    )
    
    parser.add_argument(
        '--interval',
        type=int,
        default=5,
        help='Polling interval in seconds (default: 5)'
    )
    
    parser.add_argument(
        '--log-file',
        type=Path,
        default=Path('/workspace/logs/monitor.log'),
        help='Path to log file (default: /workspace/logs/monitor.log)'
    )
    
    parser.add_argument(
        '--prometheus-port',
        type=int,
        default=None,
        help='Port for Prometheus metrics server (default: disabled)'
    )
    
    parser.add_argument(
        '--comfyui-url',
        type=str,
        default='http://localhost:8188',
        help='ComfyUI API URL (default: http://localhost:8188)'
    )
    
    parser.add_argument(
        '--summary',
        action='store_true',
        help='Print current summary and exit (no continuous monitoring)'
    )
    
    args = parser.parse_args()
    
    # Create monitor
    monitor = GPUMonitor(
        interval=args.interval,
        log_file=args.log_file,
        prometheus_port=args.prometheus_port,
        comfyui_url=args.comfyui_url
    )
    
    if args.summary:
        # Just print summary and exit
        summary = monitor.get_summary()
        print(json.dumps(summary, indent=2))
    else:
        # Start monitoring loop
        monitor.monitor_loop()


if __name__ == '__main__':
    main()
