/**
 * Vehicle Tracking System - Node.js Consumer
 * Consumes messages from RabbitMQ and persists to MongoDB
 */

const express = require('express');
const amqp = require('amqplib');
const { MongoClient } = require('mongodb');
const promClient = require('prom-client');
const { v4: uuidv4 } = require('uuid');

// Configuration
const config = {
    rabbitmq: {
        host: process.env.RABBITMQ_HOST || 'localhost',
        port: process.env.RABBITMQ_PORT || 5672,
        user: process.env.RABBITMQ_USER || 'admin',
        password: process.env.RABBITMQ_PASSWORD || 'admin',
        queue: process.env.RABBITMQ_QUEUE || 'vehicle.events'
    },
    mongodb: {
        uri: process.env.MONGODB_URI || 'mongodb://admin:admin123@localhost:27017/vehicle_tracking?authSource=admin',
        database: 'vehicle_tracking',
        collection: 'processed_events_node'
    },
    server: {
        port: process.env.PORT || 3000,
        metricsPort: process.env.METRICS_PORT || 9124
    }
};

// Logger
const winston = require('winston');
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console()
    ]
});

// Prometheus Metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const messagesConsumed = new promClient.Counter({
    name: 'consumer_node_messages_consumed_total',
    help: 'Total messages consumed from RabbitMQ',
    registers: [register]
});

const messagesProcessed = new promClient.Counter({
    name: 'consumer_node_messages_processed_total',
    help: 'Total messages successfully processed',
    registers: [register]
});

const messagesFailed = new promClient.Counter({
    name: 'consumer_node_messages_failed_total',
    help: 'Total failed message processing',
    registers: [register]
});

const processingTime = new promClient.Histogram({
    name: 'consumer_node_processing_seconds',
    help: 'Message processing time in seconds',
    buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
    registers: [register]
});

// Express App
const app = express();
app.use(express.json());

// Health endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'UP', service: 'consumer-node' });
});

// Status endpoint
app.get('/status', async (req, res) => {
    try {
        const stats = await mongoClient.db(config.mongodb.database)
            .collection(config.mongodb.collection)
            .countDocuments();
        
        res.json({
            service: 'consumer-node',
            status: 'running',
            processedEvents: stats,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
    try {
        res.set('Content-Type', register.contentType);
        res.end(await register.metrics());
    } catch (error) {
        res.status(500).end(error.message);
    }
});

// MongoDB connection
let mongoClient;

async function connectMongo() {
    try {
        mongoClient = new MongoClient(config.mongodb.uri);
        await mongoClient.connect();
        logger.info('Connected to MongoDB');
        return mongoClient;
    } catch (error) {
        logger.error('MongoDB connection error:', error);
        throw error;
    }
}

// RabbitMQ connection and consumer
let rabbitConnection;
let rabbitChannel;

async function connectRabbitMQ() {
    const url = `amqp://${config.rabbitmq.user}:${config.rabbitmq.password}@${config.rabbitmq.host}:${config.rabbitmq.port}`;
    
    try {
        rabbitConnection = await amqp.connect(url);
        rabbitChannel = await rabbitConnection.createChannel();
        
        await rabbitChannel.assertQueue(config.rabbitmq.queue, {
            durable: true
        });
        
        rabbitChannel.prefetch(10);
        
        logger.info(`Connected to RabbitMQ, consuming from queue: ${config.rabbitmq.queue}`);
        
        rabbitChannel.consume(config.rabbitmq.queue, async (msg) => {
            if (msg) {
                const timer = processingTime.startTimer();
                messagesConsumed.inc();
                
                try {
                    const content = msg.content.toString();
                    logger.info(`Received message: ${content}`);
                    
                    let eventData;
                    try {
                        eventData = JSON.parse(content);
                    } catch {
                        eventData = { rawMessage: content };
                    }
                    
                    const processedEvent = {
                        ...eventData,
                        _id: uuidv4(),
                        processedBy: 'consumer-node',
                        processedAt: new Date(),
                        consumerId: uuidv4()
                    };
                    
                    await mongoClient.db(config.mongodb.database)
                        .collection(config.mongodb.collection)
                        .insertOne(processedEvent);
                    
                    messagesProcessed.inc();
                    logger.info(`Processed event: ${processedEvent.licensePlate || 'unknown'}`);
                    
                    rabbitChannel.ack(msg);
                    
                } catch (error) {
                    messagesFailed.inc();
                    logger.error('Error processing message:', error);
                    rabbitChannel.nack(msg, false, false);
                } finally {
                    timer();
                }
            }
        });
        
        rabbitConnection.on('error', (err) => {
            logger.error('RabbitMQ connection error:', err);
        });
        
        rabbitConnection.on('close', () => {
            logger.warn('RabbitMQ connection closed, attempting reconnect...');
            setTimeout(connectRabbitMQ, 5000);
        });
        
    } catch (error) {
        logger.error('RabbitMQ connection error:', error);
        setTimeout(connectRabbitMQ, 5000);
    }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
    logger.info('SIGTERM received, shutting down gracefully');
    
    if (rabbitChannel) await rabbitChannel.close();
    if (rabbitConnection) await rabbitConnection.close();
    if (mongoClient) await mongoClient.close();
    
    process.exit(0);
});

// Start application
async function start() {
    try {
        await connectMongo();
        await connectRabbitMQ();
        
        app.listen(config.server.port, () => {
            logger.info(`Consumer Node running on port ${config.server.port}`);
        });
        
    } catch (error) {
        logger.error('Failed to start application:', error);
        process.exit(1);
    }
}

start();
