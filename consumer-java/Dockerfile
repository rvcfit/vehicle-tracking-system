#===============================================================================
#  Consumer Java - RabbitMQ to MongoDB
#  Spring Boot Application
#===============================================================================

# Stage 1: Build
FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /build

# Copy proto files
COPY proto ./proto

# Copy pom.xml and download dependencies
COPY consumer-java/pom.xml ./pom.xml
RUN mvn dependency:go-offline -B

# Copy source code
COPY consumer-java/src ./src

# Build application
RUN mvn clean package -DskipTests -B

# Stage 2: Runtime
FROM eclipse-temurin:17-jre-alpine

LABEL maintainer="Vehicle Tracking System"
LABEL description="Java Consumer - RabbitMQ to MongoDB"

WORKDIR /app

# Install wget for healthcheck
RUN apk add --no-cache wget curl && \
    rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy JAR from build stage
COPY --from=build /build/target/*.jar app.jar

# Set ownership
RUN chown -R appuser:appgroup /app

# Expose ports
EXPOSE 8080 9123

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD wget -qO- http://localhost:8080/actuator/health | grep -q UP || exit 1

# Switch to non-root user
USER appuser

# JVM configuration
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"

# Run application
ENTRYPOINT exec java $JAVA_OPTS -jar app.jar
