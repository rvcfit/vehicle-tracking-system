#===============================================================================
#  Client Flask - Web Application
#  Sends vehicle events to Artemis via STOMP
#===============================================================================

FROM python:3.11-slim

LABEL maintainer="Vehicle Tracking System"
LABEL description="Flask Client - Vehicle Event Sender"

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY client-flask/requirements.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY client-flask/app.py ./
COPY client-flask/templates ./templates
COPY client-flask/static ./static

# Copy proto files
COPY proto ./proto

# Create non-root user
RUN useradd -m -s /bin/bash appuser && \
    chown -R appuser:appuser /app

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:5000/health || exit 1

# Switch to non-root user
USER appuser

# Run application
CMD ["python", "app.py"]
