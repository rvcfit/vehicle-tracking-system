"""Vehicle Tracking Dashboard - Real-time monitoring"""
import os
from flask import Flask, render_template, jsonify
from pymongo import MongoClient
from datetime import datetime, timedelta

app = Flask(__name__)

MONGODB_URI = os.environ.get('MONGODB_URI', 'mongodb://admin:admin123@localhost:27017/vehicle_tracking?authSource=admin')
client = MongoClient(MONGODB_URI)
db = client.vehicle_tracking

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/health')
def health():
    return jsonify({'status': 'UP'})

@app.route('/api/stats')
def stats():
    try:
        total_events = db.vehicle_events.count_documents({})
        total_processed_java = db.processed_events_java.count_documents({})
        total_processed_node = db.processed_events_node.count_documents({})
        
        recent = list(db.vehicle_events.find().sort('timestamp', -1).limit(10))
        for r in recent:
            r['_id'] = str(r['_id'])
        
        return jsonify({
            'totalEvents': total_events,
            'processedJava': total_processed_java,
            'processedNode': total_processed_node,
            'recentEvents': recent,
            'timestamp': datetime.utcnow().isoformat()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
