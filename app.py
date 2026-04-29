import os
import time
import math
from flask import Flask, jsonify, Response
from prometheus_client import (
    Counter, Histogram, Gauge,
    generate_latest, CONTENT_TYPE_LATEST
)

app = Flask(__name__)

# ─────────────────────────────────────────────
# Prometheus metrics 定義
# 面試重點：每個 metric 類型的用途
#   Counter  → 只增不減，適合 request count、error count
#   Histogram → 分桶統計，適合 latency（讓你算 p50/p95/p99）
#   Gauge    → 可增可減，適合 CPU 用量、queue 長度
# ─────────────────────────────────────────────
REQUEST_COUNT = Counter(
    'flask_request_count_total',
    'Total HTTP request count',
    ['method', 'endpoint', 'status_code']
)

REQUEST_LATENCY = Histogram(
    'flask_request_latency_seconds',
    'HTTP request latency in seconds',
    ['endpoint'],
    # 分桶設計：從 5ms 到 10s，覆蓋正常與異常的延遲分佈
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

ACTIVE_REQUESTS = Gauge(
    'flask_active_requests',
    'Number of currently active (in-flight) requests'
)

LOAD_REQUESTS_TOTAL = Counter(
    'flask_load_requests_total',
    'Total number of CPU load generation requests'
)


def track_request(endpoint):
    """Decorator factory: 自動追蹤 latency 與 request count"""
    def decorator(f):
        def wrapper(*args, **kwargs):
            ACTIVE_REQUESTS.inc()
            start = time.time()
            status_code = 200
            try:
                response = f(*args, **kwargs)
                # Flask 回傳的是 (response, status) tuple
                if isinstance(response, tuple):
                    status_code = response[1]
                return response
            except Exception as e:
                status_code = 500
                raise e
            finally:
                duration = time.time() - start
                REQUEST_LATENCY.labels(endpoint=endpoint).observe(duration)
                REQUEST_COUNT.labels(
                    method='GET',
                    endpoint=endpoint,
                    status_code=str(status_code)
                ).inc()
                ACTIVE_REQUESTS.dec()
        wrapper.__name__ = f.__name__
        return wrapper
    return decorator


@app.route('/healthz')
@track_request('/healthz')
def healthz():
    """
    Health check endpoint for Kubernetes liveness/readiness probes.
    面試重點：liveness vs readiness probe 的差別
      - liveness:  失敗 → kubelet 殺掉 Pod 並重啟
      - readiness: 失敗 → 從 Service endpoints 移除，但不殺 Pod
    """
    return jsonify({"status": "ok"}), 200


@app.route('/load')
@track_request('/load')
def load():
    """
    CPU 壓力測試端點，用於觸發 HPA。
    面試重點：HPA 的 averageUtilization 是「所有 Pod 的平均 CPU 使用率」
    不是單一 Pod 超過就觸發，而是整體平均超過閾值才 scale out。
    """
    LOAD_REQUESTS_TOTAL.inc()
    start_time = time.time()
    result = 0
    while time.time() - start_time < 2:
        for i in range(10000):
            result += math.sqrt(i)

    return jsonify({
        "status": "load_generated",
        "duration_seconds": round(time.time() - start_time, 2)
    }), 200


@app.route('/metrics')
def metrics():
    """
    Prometheus scrape endpoint.
    面試重點：ServiceMonitor 會讓 Prometheus Operator 自動發現這個端點
    不需要在 prometheus.yaml 手動加 scrape config，
    這就是 Operator Pattern 的核心價值：用 CRD 取代手動設定。
    """
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
