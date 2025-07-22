# Moodle LMS - Production Docker Setup

This repository contains a production-ready Docker setup for [Moodle LMS](https://moodle.org/) 

## ✅ Features

- **Pinned Image Versions** - Prevents unexpected breaking changes
- **Resource Limits** - Optimized for 2 vCPU systems
- **Redis Caching** - Significantly improves performance
- **Automated Moodle Cron** - Scheduled tasks every 5 minutes
- **SSL/TLS Support** - Nginx reverse proxy with Let's Encrypt
- **Automated Backups** - Complete backup and restore scripts
- **Health Checks** - Container monitoring and auto-restart
- **Production Security** - Environment-based secrets and proper networking

## 🏗️ Architecture

```
Internet → Nginx (SSL/Reverse Proxy) → Moodle → MariaDB
                                           ↓
                                       Redis (Cache)
                                           ↑
                                    Moodle Cron (Scheduled Tasks)
```

## 📁 Directory Structure

```
/
├── docker-compose.yml      ← Main Docker configuration
├── .env.example           ← Environment variables template
├── backup.sh              ← Automated backup script
├── restore.sh             ← Restore script
├── README.md
├── nginx/
│   ├── nginx.conf         ← Nginx configuration
│   ├── ssl/               ← SSL certificates
│   └── html/              ← Static files
└── data/
    ├── moodle/            ← Moodle app files
    ├── moodledata/        ← Uploaded files, sessions
    ├── mariadb/           ← MariaDB data
    └── redis/             ← Redis cache data
```

## 🚀 Quick Start

### 1. Environment Setup
```bash
# Clone and navigate to project
cd your-moodle-project

# Create environment file
cp .env.example .env

# Edit with your actual values
nano .env
```

### 2. Required Environment Variables
```bash
# Moodle admin credentials
MOODLE_USERNAME=admin
MOODLE_PASSWORD=your_strong_admin_password
MOODLE_EMAIL=admin@yourdomain.com

# Database configuration
MARIADB_ROOT_PASSWORD=your_root_password
MARIADB_DATABASE=bitnami_moodle
MARIADB_USER=bn_moodle
MARIADB_PASSWORD=your_db_password

# Redis configuration
REDIS_PASSWORD=your_redis_password
```

### 3. Deploy
```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f moodle
```

## 🔧 Resource Allocation (2 vCPU System)

| Service     | CPU Limit | Memory Limit | Purpose |
|-------------|-----------|--------------|---------|
| Moodle      | 0.8 vCPU  | 512MB       | Main application |
| MariaDB     | 0.8 vCPU  | 1GB         | Database |
| Redis       | 0.5 vCPU  | 512MB       | Caching |
| MoodleCron  | 0.2 vCPU  | 256MB       | Scheduled tasks |
| Nginx       | 0.1 vCPU  | 64MB        | Reverse proxy |

## 🔒 SSL/HTTPS Setup

### Initial SSL Certificate
```bash
# Stop nginx temporarily
docker-compose stop nginx

# Get initial certificate
docker run --rm -v $(pwd)/nginx/ssl:/etc/letsencrypt \
  -v $(pwd)/nginx/html:/usr/share/nginx/html \
  certbot/certbot certonly --webroot \
  -w /usr/share/nginx/html \
  -d your-domain.com

# Start nginx
docker-compose start nginx
```

### SSL Renewal (Add to crontab)
```bash
# Add to crontab -e
0 3 * * 0 docker run --rm -v $(pwd)/nginx/ssl:/etc/letsencrypt -v $(pwd)/nginx/html:/usr/share/nginx/html certbot/certbot renew --webroot -w /usr/share/nginx/html && docker-compose restart nginx
```

## 💾 Backup & Restore

### Automated Backup
```bash
# Manual backup
./backup.sh

# Automated daily backup (add to crontab)
0 2 * * * /path/to/your/project/backup.sh
```

### Restore from Backup
```bash
# List available backups
ls -la backups/

# Restore specific backup
./restore.sh moodle_backup_20240122_143000
```

### Backup Contents
- **Database**: Complete MariaDB dump
- **Files**: Moodle application and user data
- **Cache**: Redis data
- **Config**: Docker and Nginx configuration

## 📊 Monitoring & Maintenance

### Health Checks
```bash
# Check container health
docker-compose ps

# View health check logs
docker inspect moodle | grep -A 10 Health
```

### Performance Monitoring
```bash
# Resource usage
docker stats

# Moodle logs
docker-compose logs -f moodle

# Database performance
docker exec -it mariadb mysql -u root -p -e "SHOW PROCESSLIST;"
```

### Maintenance Tasks
```bash
# Update containers (with pinned versions)
docker-compose pull
docker-compose up -d

# Clean up old images
docker image prune -f

# Database optimization
docker exec -it mariadb mysql -u root -p -e "OPTIMIZE TABLE moodle.*;"
```

## 🔧 Troubleshooting

### Common Issues

**Out of Memory**
```bash
# Check memory usage
free -h
docker stats

# Restart services if needed
docker-compose restart
```

**Database Connection Issues**
```bash
# Check MariaDB logs
docker-compose logs mariadb

# Test database connection
docker exec -it mariadb mysql -u root -p
```

**Performance Issues**
```bash
# Check Redis cache
docker exec -it redis redis-cli info stats

# Monitor Moodle performance
docker-compose logs moodle | grep -i error
```

### Moodle Cron Monitoring
```bash
# Check cron job status
docker-compose logs -f moodlecron

# Manual cron run (if needed)
docker exec -it moodlecron /opt/bitnami/php/bin/php /bitnami/moodle/admin/cli/cron.php

# Check last cron execution in Moodle admin
# Go to: Site Administration → Server → Tasks → Task processing
```

### Log Locations
- **Moodle**: `docker-compose logs moodle`
- **Moodle Cron**: `docker-compose logs moodlecron`
- **Database**: `docker-compose logs mariadb`
- **Nginx**: `docker-compose logs nginx`
- **Redis**: `docker-compose logs redis`

## 🔄 Updates & Upgrades

### Updating Moodle
1. Update image version in `docker-compose.yml`
2. Create backup: `./backup.sh`
3. Pull new image: `docker-compose pull moodle`
4. Restart: `docker-compose up -d moodle`

### Database Maintenance
```bash
# Weekly database optimization
docker exec -it mariadb mysql -u root -p -e "
  OPTIMIZE TABLE moodle.mdl_sessions;
  OPTIMIZE TABLE moodle.mdl_log;
  ANALYZE TABLE moodle.mdl_user;
"
```

## 📈 Scaling Considerations

For higher traffic, consider:
- Upgrading to larger Lightsail instance
- Adding external Redis service
- Using RDS for database
- Implementing CDN for static assets
- Load balancing multiple Moodle instances

## 🆘 Support

- **Moodle Documentation**: https://docs.moodle.org/
- **Bitnami Moodle**: https://github.com/bitnami/bitnami-docker-moodle
- **Docker Compose**: https://docs.docker.com/compose/

---

**⚠️ Important**: Always test updates in a staging environment before applying to production!