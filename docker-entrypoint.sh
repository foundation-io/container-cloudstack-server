#!/bin/bash
set -e

# Environment variables with defaults
DB_HOST=${DB_HOST:-mysql}
DB_PORT=${DB_PORT:-3306}
DB_PASSWORD=${DB_PASSWORD:-cloud}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-root}
MANAGEMENT_SERVER_IP=${MANAGEMENT_SERVER_IP:-$(hostname -I | awk '{print $1}')}

echo "CloudStack Docker Entrypoint Starting..."
echo "Database Host: ${DB_HOST}:${DB_PORT}"
echo "Management Server IP: ${MANAGEMENT_SERVER_IP}"

# Wait for MySQL to be ready and accepting connections
echo "Waiting for MySQL at ${DB_HOST}:${DB_PORT} to be ready..."
max_attempts=60
attempt=1
while [ $attempt -le $max_attempts ]; do
    if mysql -h "${DB_HOST}" -P "${DB_PORT}" -u root -p"${DB_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; then
        echo "Successfully connected to MySQL"
        break
    fi
    echo "Waiting for MySQL... (attempt $attempt/$max_attempts)"
    sleep 2
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo "ERROR: Could not connect to MySQL after $max_attempts attempts"
    echo "Please check:"
    echo "  1. MySQL container is running: docker compose ps"
    echo "  2. MySQL logs: docker compose logs mysql"
    echo "  3. Environment variables are correct"
    exit 1
fi

# Check if CloudStack database has tables (not empty)
echo "Checking if CloudStack database is initialized..."
TABLE_COUNT=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" -u root -p"${DB_ROOT_PASSWORD}" -s -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='cloud'" 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" -gt "0" ]; then
    echo "CloudStack database already initialized with $TABLE_COUNT tables"
else
    echo "CloudStack database is empty. Setting it up..."

    # Setup CloudStack databases
    if cloudstack-setup-databases cloud:${DB_PASSWORD}@${DB_HOST}:${DB_PORT} \
        --deploy-as=root:${DB_ROOT_PASSWORD} \
        -i ${MANAGEMENT_SERVER_IP}; then
        echo "CloudStack database setup completed successfully"

        # Verify the setup worked
        NEW_TABLE_COUNT=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" -u root -p"${DB_ROOT_PASSWORD}" -s -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='cloud'" 2>/dev/null || echo "0")
        echo "CloudStack database now has $NEW_TABLE_COUNT tables"

        if [ "$NEW_TABLE_COUNT" = "0" ]; then
            echo "ERROR: Database setup completed but no tables were created"
            exit 1
        fi
    else
        echo "ERROR: Failed to setup CloudStack database"
        echo "Please check the error messages above"
        exit 1
    fi
fi

echo "Starting supervisord..."
# Execute the CMD from Dockerfile
exec "$@"
