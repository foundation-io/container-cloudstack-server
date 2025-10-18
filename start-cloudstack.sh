#!/bin/bash

# CloudStack startup wrapper script based on systemd unit files

# Environment variables with defaults
export DB_HOST=${DB_HOST:-mysql}
export DB_PORT=${DB_PORT:-3306}
export DB_PASSWORD=${DB_PASSWORD:-cloud}
export DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-root}
export PRIMARY_IP=$(hostname -I | awk '{print $1}')
export MANAGEMENT_SERVER_IP=${MANAGEMENT_SERVER_IP:-$PRIMARY_IP}

# Function to start CloudStack Management Server
start_cloudstack_management() {
    # Source the environment file
    . /etc/default/cloudstack-management

    # Create necessary directories
    mkdir -p /var/log/cloudstack/management
    mkdir -p /var/run

    # Change to working directory
    cd /var/log/cloudstack/management

    # Set umask as per systemd unit
    umask 0022

    # # Create cloud user if it doesn't exist
    # if ! id -u cloud >/dev/null 2>&1; then
    #     useradd -r -d /var/lib/cloudstack/management -s /bin/sh -c "CloudStack cloud user" cloud
    # fi

    # Ensure lib directory ownership
    chown -R cloud:cloud /var/lib/cloudstack

    # Ensure log directory ownership
    chown -R cloud:cloud /var/log/cloudstack/management

    # Set management IP in configuration
    export DB_CONFIG=/etc/cloudstack/management/db.properties
    sed -i -e "s/^cluster\.node\.IP.*/cluster.node.IP=${MANAGEMENT_SERVER_IP}/g" $DB_CONFIG

    # Set database connection parameters
    sed -i -e "s/^db\.cloud\.host.*/db.cloud.host=${DB_HOST}/g" $DB_CONFIG
    sed -i -e "s/^db\.cloud\.port.*/db.cloud.port=${DB_PORT}/g" $DB_CONFIG
    sed -i -e "s/^db\.cloud\.password.*/db.cloud.password=${DB_PASSWORD}/g" $DB_CONFIG
    sed -i -e "s/^db\.usage\.host.*/db.usage.host=${DB_HOST}/g" $DB_CONFIG
    sed -i -e "s/^db\.usage\.port.*/db.usage.port=${DB_PORT}/g" $DB_CONFIG
    sed -i -e "s/^db\.usage\.password.*/db.usage.password=${DB_PASSWORD}/g" $DB_CONFIG

    # Run as cloud user - exactly as systemd unit does
    exec su - cloud -s /bin/bash -c "cd /var/log/cloudstack/management && exec /usr/bin/java $JAVA_DEBUG $JAVA_OPTS -cp $CLASSPATH $BOOTSTRAP_CLASS"
}

# Function to start CloudStack Usage Server
start_cloudstack_usage() {
    # Source the environment file
    . /etc/default/cloudstack-usage

    # Create necessary directories
    mkdir -p /var/log/cloudstack/usage

    # Create cloud user if it doesn't exist
    if ! id -u cloud >/dev/null 2>&1; then
        useradd -r -d /var/lib/cloudstack/management -s /bin/sh -c "CloudStack cloud user" cloud
    fi

    # Ensure log directory ownership
    chown -R cloud:cloud /var/log/cloudstack/usage

    # Set JAVA_PID for the process
    export JAVA_PID=$$

    # Run the usage server - exactly as systemd unit does
    exec su - cloud -s /bin/bash -c "/usr/bin/java -Dpid=${JAVA_PID} $JAVA_OPTS $JAVA_DEBUG -cp $CLASSPATH $JAVA_CLASS"
}

# Main execution based on the first argument
case "$1" in
    management)
        start_cloudstack_management
        ;;
    usage)
        start_cloudstack_usage
        ;;
    *)
        echo "Usage: $0 {management|usage}"
        exit 1
        ;;
esac
