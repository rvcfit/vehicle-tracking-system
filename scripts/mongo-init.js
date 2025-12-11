// MongoDB Initialization Script
// Creates database, collections, and indexes

db = db.getSiblingDB('vehicle_tracking');

// Create collections
db.createCollection('vehicle_events');
db.createCollection('processed_events_java');
db.createCollection('processed_events_node');

// Create indexes for vehicle_events
db.vehicle_events.createIndex({ "licensePlate": 1 });
db.vehicle_events.createIndex({ "timestamp": -1 });
db.vehicle_events.createIndex({ "eventType": 1 });
db.vehicle_events.createIndex({ "vehicleType": 1 });
db.vehicle_events.createIndex({ "source": 1 });

// Create indexes for processed_events_java
db.processed_events_java.createIndex({ "licensePlate": 1 });
db.processed_events_java.createIndex({ "processedAt": -1 });

// Create indexes for processed_events_node
db.processed_events_node.createIndex({ "licensePlate": 1 });
db.processed_events_node.createIndex({ "processedAt": -1 });

// Create TTL index to auto-delete old events (30 days)
db.vehicle_events.createIndex({ "timestamp": 1 }, { expireAfterSeconds: 2592000 });
db.processed_events_java.createIndex({ "processedAt": 1 }, { expireAfterSeconds: 2592000 });
db.processed_events_node.createIndex({ "processedAt": 1 }, { expireAfterSeconds: 2592000 });

print('MongoDB initialized successfully!');
