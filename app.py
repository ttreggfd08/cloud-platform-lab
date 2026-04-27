import os
import time
import math
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/healthz')
def healthz():
    """Health check endpoint for Kubernetes liveness/readiness probes."""
    return jsonify({"status": "ok"}), 200

@app.route('/load')
def load():
    """
    Endpoint to artificially generate CPU load. 
    This will be used to trigger Kubernetes HPA (Horizontal Pod Autoscaler).
    Spins the CPU for approximately 2-3 seconds.
    """
    start_time = time.time()
    result = 0
    # Loop for roughly 2 seconds
    while time.time() - start_time < 2:
        for i in range(10000):
            result += math.sqrt(i)
    
    return jsonify({
        "status": "load_generated", 
        "duration_seconds": round(time.time() - start_time, 2)
    }), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
