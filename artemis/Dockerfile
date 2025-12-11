#===============================================================================
#  ActiveMQ Artemis - Enterprise Message Broker
#  Supports: JMS 1.1/2.0, AMQP 1.0, MQTT 3.1.1, STOMP 1.2
#===============================================================================

FROM eclipse-temurin:17-jre-alpine

LABEL maintainer="Vehicle Tracking System"
LABEL description="ActiveMQ Artemis Message Broker"
LABEL version="2.31.2"

# Artemis version
ENV ARTEMIS_VERSION=2.31.2
ENV ARTEMIS_HOME=/opt/artemis
ENV ARTEMIS_INSTANCE=/opt/artemis-instance
ENV ARTEMIS_USER=admin
ENV ARTEMIS_PASSWORD=admin

# Install dependencies
RUN apk add --no-cache \
    curl \
    bash \
    libaio \
    xmlstarlet \
    && rm -rf /var/cache/apk/*

# Download and install ActiveMQ Artemis
RUN mkdir -p /opt && \
    curl -fsSL -o /tmp/artemis.tar.gz \
    "https://archive.apache.org/dist/activemq/activemq-artemis/${ARTEMIS_VERSION}/apache-artemis-${ARTEMIS_VERSION}-bin.tar.gz" && \
    tar xzf /tmp/artemis.tar.gz -C /opt && \
    ln -s /opt/apache-artemis-${ARTEMIS_VERSION} ${ARTEMIS_HOME} && \
    rm /tmp/artemis.tar.gz

# Create broker instance
RUN cd /opt && \
    ${ARTEMIS_HOME}/bin/artemis create artemis-instance \
    --user ${ARTEMIS_USER} \
    --password ${ARTEMIS_PASSWORD} \
    --allow-anonymous \
    --http-host 0.0.0.0 \
    --relax-jolokia \
    --queues vehicle.events,vehicle.alerts,vehicle.telemetry \
    --no-autotune

# Configure broker
RUN sed -i 's/<acceptor name="artemis">tcp:\/\/0.0.0.0:61616/<acceptor name="artemis">tcp:\/\/0.0.0.0:61616?protocols=CORE,AMQP,STOMP,HORNETQ,MQTT,OPENWIRE/g' \
    ${ARTEMIS_INSTANCE}/etc/broker.xml

# Create non-root user
RUN addgroup -S artemis && adduser -S -G artemis artemis && \
    chown -R artemis:artemis ${ARTEMIS_INSTANCE} && \
    chown -R artemis:artemis /opt/apache-artemis-${ARTEMIS_VERSION}

# Expose ports
# 61616 - Core protocol (JMS, OpenWire)
# 5672  - AMQP
# 61613 - STOMP
# 1883  - MQTT
# 8161  - Web console
EXPOSE 61616 5672 61613 1883 8161

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD curl -sf http://localhost:8161/console || exit 1

# Switch to non-root user
USER artemis

WORKDIR ${ARTEMIS_INSTANCE}

# Start Artemis
CMD ["bin/artemis", "run"]
