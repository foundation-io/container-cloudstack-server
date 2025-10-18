# Apache CloudStack Management Server Container

A containerized Apache CloudStack management server with separate MySQL/MariaDB database and usage server, based on AlmaLinux 9.6.

## Quick Start

```bash
# Build the container
docker compose build

# Start CloudStack with MySQL
docker compose up -d

# View logs
docker compose logs -f

# Stop and DESTROY ALL DATA
docker compose down -v
```

Access the CloudStack UI at: http://localhost:8080/client/
- Default credentials: admin / password

## Architecture

This setup uses two separate containers:
- **MySQL/MariaDB container**: Dedicated database server
- **CloudStack container**: Management server and usage server

## Features

- Apache CloudStack management server with usage server
- Separate MySQL/MariaDB database container
- Automatic database initialization on first run
- Persistent data volumes
- Supervisord process management
- Health checks for service dependencies

## Configuration

Environment variables can be set in `.env` file:

```bash
# CloudStack version
CLOUDSTACK_VERSION=4.21

# Database configuration
DB_HOST=mysql
DB_PORT=3306
DB_PASSWORD=cloud
DB_ROOT_PASSWORD=root

# Management server IP (auto-detected if not set)
MANAGEMENT_SERVER_IP=
```

## Services

### MySQL/MariaDB Service
- Image: `mariadb:10.11`
- Port: `3306`
- Health check included for automatic startup sequencing

### CloudStack Service
- Management server
- Usage server
- Depends on MySQL service health

## Exposed Ports

- `3306` - MySQL/MariaDB database
- `8080` - Management UI
- `8250` - Cluster management
- `8251` - System VM communication
- `9090` - Integration API
- `8096` - Usage server

## Volumes

- `mysql-data` - MySQL/MariaDB database files
- `cloudstack-data` - CloudStack data
- `cloudstack-logs` - CloudStack logs

## Custom MySQL/MariaDB

To use an external MySQL/MariaDB instance instead of the containerized one:

1. Remove or comment out the `mysql` service from `docker-compose.yml`
2. Update the environment variables to point to your external database:
   ```bash
   DB_HOST=your-mysql-host
   DB_PORT=3306
   DB_PASSWORD=your-password
   DB_ROOT_PASSWORD=your-root-password
   ```
3. Ensure your external database is accessible from the CloudStack container

## Troubleshooting

### MySQL Connection Issues

If you see "Access denied for user 'root'@'x.x.x.x'" errors:

1. **On first run**, ensure the MySQL container is fully initialized:
   ```bash
   # Remove existing volumes and start fresh
   docker compose down -v
   docker compose up -d mysql
   
   # Wait for MySQL to be ready
   docker compose logs -f mysql
   
   # Once ready, start CloudStack
   docker compose up -d cloudstack
   ```

2. **Verify MySQL is accepting connections**:
   ```bash
   # Test connection from host
   mysql -h localhost -P 3306 -u root -p
   # Password: root (or your DB_ROOT_PASSWORD)
   
   # Test from CloudStack container
   docker compose exec cloudstack mysql -h mysql -u root -p
   ```

3. **Check MySQL permissions**:
   ```bash
   docker compose exec mysql mysql -u root -p -e "SELECT Host, User FROM mysql.user;"
   ```

4. **Manually grant permissions if needed**:
   ```bash
   docker compose exec mysql mysql -u root -p
   # Then run:
   GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;
   FLUSH PRIVILEGES;
   ```

### Check CloudStack logs
```bash
docker compose exec cloudstack tail -f /var/log/cloudstack/management/management-server.log
```

### Access CloudStack container
```bash
docker compose exec cloudstack bash
```

### Reset Everything
If you need to start completely fresh:
```bash
# Stop and remove all containers and volumes
docker compose down -v

# Remove any cached images
docker compose down --rmi all

# Rebuild and start
docker compose build --no-cache
docker compose up -d
```

## License

Apache License 2.0