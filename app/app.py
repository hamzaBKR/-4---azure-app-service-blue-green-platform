import os
from datetime import datetime, timezone
from flask import Flask, jsonify, render_template

app = Flask(__name__)

def metadata():
    return {
        "name": os.getenv("APP_NAME", "Azure Service Status Dashboard"),
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "environment": os.getenv("APP_ENVIRONMENT", "Local"),
        "deployment_time": os.getenv(
            "DEPLOYMENT_TIME",
            datetime.now(timezone.utc).isoformat()
        ),
    }

@app.get("/")
def home():
    return render_template("index.html", **metadata())

@app.get("/health")
def health():
    return jsonify({"status": "healthy", **metadata()}), 200

@app.get("/api/info")
def info():
    return jsonify(metadata()), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8000")))
