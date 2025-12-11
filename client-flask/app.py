"""
Vehicle Tracking System - Flask Client
Sends vehicle events to ActiveMQ Artemis via STOMP protocol
"""

import os
import json
import logging
import time
from datetime import datetime
from uuid import uuid4

from flask import Flask, render_template, request, jsonify
import stomp
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

# Configuration
CONFIG = {
    'artemis': {
        'host': os.environ.get('ARTEMIS_HOST', 'localhost'),
        'port': int(os.environ.get('ARTEMIS_PORT', 61613)),  # STOMP port
        'user': os.environ.get('ARTEMIS_USER', 'admin'),
        'password': os.environ.get('ARTEMIS_PASSWORD', 'admin'),
        'queue': os.environ.get('ARTEMIS_QUEUE', 'vehicle.events')
    },
    'server': {
        'host': '0.0.0.0',
        'port': int(os.environ.get('PORT', 5000)),
        'debug': os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'
    }
}

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Flask App
app = Flask(__name__)

# Prometheus Metrics
messages_sent = Counter(
    'client_flask_messages_sent_total',
    'Total messages sent to Artemis'
)
messages_failed = Counter(
    'client_flask_messages_failed_total',
    'Total failed message sends'
)
send_latency = Histogram(
    'client_flask_send_latency_seconds',
    'Message send latency',
    buckets=[0.01, 0.05, 0.1, 0.5, 1, 2, 5]
)

# STOMP Connection
class StompConnection:
    def __init__(self):
        self.conn = None
        self.connected = False
    
    def connect(self):
        try:
            self.conn = stomp.Connection(
                [(CONFIG['artemis']['host'], CONFIG['artemis']['port'])],
                heartbeats=(10000, 10000)
            )
            self.conn.connect(
                CONFIG['artemis']['user'],
                CONFIG['artemis']['password'],
                wait=True
            )
            self.connected = True
            logger.info(f"Connected to Artemis at {CONFIG['artemis']['host']}:{CONFIG['artemis']['port']}")
        except Exception as e:
            self.connected = False
            logger.error(f"Failed to connect to Artemis: {e}")
            raise
    
    def send(self, message):
        if not self.connected or not self.conn.is_connected():
            self.connect()
        
        destination = f"/queue/{CONFIG['artemis']['queue']}"
        self.conn.send(
            destination=destination,
            body=json.dumps(message),
            content_type='application/json'
        )
    
    def disconnect(self):
        if self.conn and self.conn.is_connected():
            self.conn.disconnect()
            self.connected = False

stomp_conn = StompConnection()

# Routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/health')
def health():
    return jsonify({'status': 'UP', 'service': 'client-flask'})

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/api/status')
def status():
    return jsonify({
        'service': 'client-flask',
        'artemis_connected': stomp_conn.connected,
        'artemis_host': CONFIG['artemis']['host'],
        'artemis_port': CONFIG['artemis']['port'],
        'queue': CONFIG['artemis']['queue'],
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/send', methods=['POST'])
def send_event():
    start_time = time.time()
    
    try:
        data = request.get_json() or {}
        
        # Build event
        event = {
            'id': str(uuid4()),
            'licensePlate': data.get('licensePlate', data.get('license_plate', 'UNKNOWN')),
            'vehicleType': data.get('vehicleType', data.get('vehicle_type', 'CAR')),
            'eventType': data.get('eventType', data.get('event_type', 'DETECTION')),
            'latitude': data.get('latitude'),
            'longitude': data.get('longitude'),
            'speed': data.get('speed'),
            'direction': data.get('direction'),
            'source': 'flask-client',
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # Remove None values
        event = {k: v for k, v in event.items() if v is not None}
        
        # Send to Artemis
        stomp_conn.send(event)
        
        messages_sent.inc()
        send_latency.observe(time.time() - start_time)
        
        logger.info(f"Sent event for plate: {event['licensePlate']}")
        
        return jsonify({
            'success': True,
            'event': event,
            'message': 'Event sent successfully'
        })
        
    except Exception as e:
        messages_failed.inc()
        logger.error(f"Failed to send event: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/send/batch', methods=['POST'])
def send_batch():
    try:
        events = request.get_json() or []
        
        if not isinstance(events, list):
            events = [events]
        
        results = []
        for event_data in events:
            try:
                event = {
                    'id': str(uuid4()),
                    'licensePlate': event_data.get('licensePlate', 'UNKNOWN'),
                    'vehicleType': event_data.get('vehicleType', 'CAR'),
                    'eventType': event_data.get('eventType', 'DETECTION'),
                    'source': 'flask-client',
                    'timestamp': datetime.utcnow().isoformat()
                }
                stomp_conn.send(event)
                messages_sent.inc()
                results.append({'success': True, 'licensePlate': event['licensePlate']})
            except Exception as e:
                messages_failed.inc()
                results.append({'success': False, 'error': str(e)})
        
        return jsonify({
            'total': len(events),
            'successful': sum(1 for r in results if r.get('success')),
            'results': results
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Cleanup on shutdown
import atexit
atexit.register(stomp_conn.disconnect)

if __name__ == '__main__':
    # Initial connection
    try:
        stomp_conn.connect()
    except Exception as e:
        logger.warning(f"Initial connection failed, will retry: {e}")
    
    app.run(
        host=CONFIG['server']['host'],
        port=CONFIG['server']['port'],
        debug=CONFIG['server']['debug']
    )
