# ✅ SNS-DevSecOps Setup Summary

**Last Updated**: October 11, 2025

## � Repository Overview

This repository (`sns-devsecops`) manages the **infrastructure and deployment** for the Twitah microblogging application. The application code is maintained separately in the `twitah-devsecops` repository by the development team.

### Architecture Approach
- **Separation of Concerns**: Infrastructure (this repo) vs Application Code (dev repo)
- **Symlink Integration**: `src/` directory is a symbolic link to the development repository
- **Immediate Updates**: Changes in dev repo reflect instantly via symlink
- **Independent Workflows**: Infrastructure and application teams work independently

---

## 📁 Repository Structure

### This Repository (sns-devsecops)
```
sns-devsecops/
├── docker/                      # PHP container configurations
│   └── php/
│       ├── php.dev.ini          # Development PHP settings
│       └── php.prod.ini         # Production PHP settings
├── nginx/                       # NGINX web server config
│   └── conf.d/
│       └── default.conf         # Virtual host configuration
├── database/                    # Database initialization
│   └── 01-init-twitah.sql      # Schema and seed data
├── src/ → symlink              # ⚡ Symlink to /home/student/twitah-devsecops/src
├── storage/                    # Mounted but not actively used
│   ├── cache/
│   ├── logs/
│   └── uploads/
├── db-data/                    # Database persistence (gitignored)
├── docker-compose.yaml         # Service orchestration
├── Dockerfile                  # PHP-FPM 8.2 image
├── .env                        # Environment variables
├── .gitignore                  # Git ignore rules
├── README.md                   # Complete documentation
├── SETUP_SUMMARY.md            # This file
└── REFACTOR_SUMMARY.md         # Recent refactor details
```

### Development Repository (twitah-devsecops)
```
twitah-devsecops/
└── src/                        # ⚡ Application code (symlinked)
    ├── index.php               # MVC routing entry point
    ├── config/
    │   └── config.php          # Database configuration
    ├── controllers/            # Business logic
    │   ├── AuthController.php
    │   ├── TweetController.php
    │   └── ProfileController.php
    ├── models/                 # Data models
    │   ├── User.php
    │   └── Tweet.php
    ├── views/                  # HTML templates
    │   ├── home.php
    │   ├── add.php
    │   ├── profile.php
    │   ├── auth/
    │   ├── layout/
    │   └── css/
    └── uploads/                # User uploaded files
```

---

## 🔧 Recent Refactor (October 11, 2025)

### What Changed:
1. **✅ Replaced Old Application**: Moved `src/` to `src.backup/`, created symlink to `twitah-devsecops/src`
2. **✅ Updated NGINX Config**: Changed document root from `/var/www/html/public` to `/var/www/html`
3. **✅ Fixed Database Init Path**: Changed from `./database/init/` to `./database/`
4. **✅ Added Missing Env Var**: Added `DB_ROOT_PASSWORD` to `.env`
5. **✅ Removed Old Artifacts**: Deleted `src.backup/` directory
6. **✅ Updated Documentation**: README.md now reflects symlink architecture

### Key Fixes Made:

### Key Fixes Made:

**Old Structure (src.backup)**:
- Had `public/` subdirectory with separate `api.php` and `index.php`
- Used procedural PHP with includes
- Static files in `public/`

**New Structure (via symlink)**:
- MVC architecture with single `index.php` router
- Controllers, Models, Views separation
- Static files in `views/css/`
- Uploads in `src/uploads/`

**Configuration Updates**:
- NGINX root: `public/` → root directory
- Database mount: `./database/init/` → `./database/`
- Environment: Added `DB_ROOT_PASSWORD`

---

## 🚀 Quick Start Guide

### Prerequisites
```bash
# Ensure Docker is installed
docker --version
docker compose version

# Ensure proxy-network exists
docker network create proxy-network --subnet 172.20.0.0/16

# Verify symlink
ls -la src
# Should show: src -> /home/student/twitah-devsecops/src
```

### Starting the Application

```bash
cd /home/student/sns-devsecops

# Clean start (if encountering database errors)
sudo docker compose down
sudo rm -rf db-data/*

# Build and start
sudo docker compose build
sudo docker compose up -d

# Check status
sudo docker compose ps

# View logs
sudo docker compose logs -f
```

### Access the Application

1. **Direct IP Access**: http://172.20.0.30/
2. **Via Nginx Proxy Manager**: http://sns.devsecops.local/

### Environment Variables (.env)

```env
DB_HOST=sns-dso-db
DB_NAME=twita_db
DB_USER=sns_user
DB_PASSWORD=devsecops-admin
DB_ROOT_PASSWORD=devsecops-admin
```

---

## 🔍 Common Issues & Solutions

### Issue 1: 500 Internal Server Error - Database Access Denied

**Error Message**: 
```
Access denied for user 'sns_user'@'%' to database 'twita_db'
```

**Root Cause**: 
The `db-data/` directory contains old database data with different credentials. MariaDB only runs init scripts when the data directory is empty.

**Solution**:
```bash
sudo docker compose down
sudo rm -rf db-data/*
sudo docker compose up -d
```

### Issue 2: Symlink Broken or Not Found

**Symptoms**: 
- Container starts but shows empty directory
- PHP errors about missing files

**Solution**:
```bash
# Check symlink
ls -la src

# If broken, recreate
rm src
ln -s /home/student/twitah-devsecops/src src

# Verify target exists
ls -la /home/student/twitah-devsecops/src
```

### Issue 3: Changes in Dev Repo Not Reflecting

**Symptoms**:
- Edited files in twitah-devsecops but changes don't appear

**Solution**:
```bash
# Verify symlink in container
sudo docker compose exec sns-dso-app ls -la /var/www/html

# Restart container to remount
sudo docker compose restart sns-dso-app
```

### Issue 4: Permission Denied on Uploads

**Symptoms**:
- Cannot upload images
- Permission errors in logs

**Solution**:
```bash
# Fix permissions in dev repo
cd /home/student/twitah-devsecops
sudo chown -R www-data:www-data src/uploads/
sudo chmod -R 755 src/uploads/
```

---

## 🌐 Network Configuration

### Docker Networks

1. **proxy-network** (External)
   - Subnet: 172.20.0.0/16
   - Purpose: External access via Nginx Proxy Manager
   - Web container IP: 172.20.0.30

2. **sns-dso-internal** (Internal)
   - Purpose: Internal communication between services
   - Isolated from external access

### Service Communication

```
Internet → Nginx Proxy Manager → 172.20.0.30:80 (nginx)
                                      ↓
                                 sns-dso-app:9000 (PHP-FPM)
                                      ↓
                                 sns-dso-db:3306 (MariaDB)
```

---

## � Team Workflows

### Development Team (Application Code)

**Work Location**: `/home/student/twitah-devsecops`

```bash
cd /home/student/twitah-devsecops

# Make changes to src/
vim src/controllers/TweetController.php

# Changes are immediately live in containers via symlink!

# Commit and push
git add .
git commit -m "Updated tweet controller"
git push origin main
```

### Infrastructure Team (Deployment)

**Work Location**: `/home/student/sns-devsecops`

```bash
cd /home/student/sns-devsecops

# Update infrastructure configs
vim docker-compose.yaml
vim nginx/conf.d/default.conf

# Rebuild and deploy
sudo docker compose down
sudo docker compose build
sudo docker compose up -d

# Commit infrastructure changes
git add .
git commit -m "Updated nginx configuration"
git push origin dev
```

---
---

## 📊 Service Details

### Container: sns-dso-app (PHP-FPM 8.2)
- **Base Image**: php:8.2-fpm-alpine
- **Extensions**: pdo_mysql, mysqli, mbstring, zip, gd, intl, bcmath
- **Port**: 9000 (internal)
- **Volume**: `./src` (symlinked) → `/var/www/html`
- **Config**: `docker/php/php.prod.ini`

### Container: web (NGINX)
- **Base Image**: nginx:alpine
- **Port**: 80 (exposed to proxy-network)
- **IP**: 172.20.0.30
- **Config**: `nginx/conf.d/default.conf`
- **Document Root**: `/var/www/html`

### Container: sns-dso-db (MariaDB 10.11)
- **Database**: twita_db
- **User**: sns_user
- **Port**: 3306 (internal only)
- **Volume**: `./db-data` → `/var/lib/mysql`
- **Init Script**: `./database/01-init-twitah.sql`

---

## 🗄️ Database Information

### Initialization
- **Script**: `database/01-init-twitah.sql`
- **Run Time**: Only when `db-data/` is empty (first start)
- **Contains**: Table schemas + seed data

### Tables Created

**users**:
```sql
- id (INT, AUTO_INCREMENT, PRIMARY KEY)
- username (VARCHAR(50), UNIQUE)
- email (VARCHAR(100), UNIQUE)
- password (VARCHAR(255))
- created_at (TIMESTAMP)
```

**tweets**:
```sql
- id (INT, AUTO_INCREMENT, PRIMARY KEY)
- user_id (INT, FOREIGN KEY → users.id)
- content (TEXT)
- image_url (VARCHAR(255), NULL)
- created_at (TIMESTAMP)
```

### Default Test Users
- **alice** / password123 / alice@example.com
- **bob** / qwerty / bob@example.com

---

## 🔒 Security Notes

### Current Security Features
✅ Network isolation (internal services not exposed)  
✅ Environment-based configuration  
✅ PHP security settings in php.prod.ini  
✅ NGINX security headers  
✅ Hidden files protection  
✅ Separate database user (not root)  

### Security Warnings
⚠️ **Default passwords** in `.env` - Change for production!  
⚠️ **Plain text passwords** in database - Implement proper hashing!  
⚠️ **No authentication** on most routes - Add auth middleware!  
⚠️ **File upload validation** missing - Implement file type checking!  
⚠️ **SQL injection vulnerable** - Some queries not using prepared statements!  

### Recommended for Production
1. Change all default passwords
2. Enable HTTPS via Nginx Proxy Manager
3. Implement proper password hashing (bcrypt/argon2)
4. Add authentication middleware
5. Validate file uploads properly
6. Use prepared statements everywhere
7. Set up log monitoring
8. Regular security updates

---

## � Additional Resources

- **README.md**: Complete documentation with setup instructions
- **REFACTOR_SUMMARY.md**: Details about the symlink refactor
- **docker-compose.yaml**: Service definitions and configuration
- **Dockerfile**: PHP-FPM image build instructions
- **nginx/conf.d/default.conf**: NGINX virtual host configuration

---

## 🎯 Quick Reference Commands

### Container Management
```bash
# Start services
sudo docker compose up -d

# Stop services
sudo docker compose down

# Restart specific service
sudo docker compose restart sns-dso-app

# View logs
sudo docker compose logs -f

# Check status
sudo docker compose ps

# Access container shell
sudo docker compose exec sns-dso-app sh
```

### Database Management
```bash
# Access MySQL CLI
sudo docker compose exec sns-dso-db mysql -u sns_user -pdevsecops-admin twita_db

# Backup database
sudo docker compose exec sns-dso-db mysqldump -u root -pdevsecops-admin twita_db > backup.sql

# Restore database
sudo docker compose exec -T sns-dso-db mysql -u root -pdevsecops-admin twita_db < backup.sql

# Reset database (deletes all data!)
sudo docker compose down
sudo rm -rf db-data/*
sudo docker compose up -d
```

### Development
```bash
# Watch application logs
sudo docker compose logs -f sns-dso-app

# Watch nginx logs
sudo docker compose logs -f web

# Edit application code (in dev repo)
cd /home/student/twitah-devsecops
vim src/controllers/TweetController.php

# Edit infrastructure (in this repo)
cd /home/student/sns-devsecops
vim docker-compose.yaml
```

### Troubleshooting
```bash
# Check symlink
ls -la /home/student/sns-devsecops/src

# Verify database credentials
sudo docker compose exec sns-dso-db env | grep MYSQL

# Test PHP connection to database
sudo docker compose exec sns-dso-app php -r "new mysqli('sns-dso-db', 'sns_user', 'devsecops-admin', 'twita_db') or die('Failed');"

# Check network connectivity
docker network inspect proxy-network
docker network inspect sns-devsecops_sns-dso-internal
```

---

## ✨ Summary

Your sns-devsecops infrastructure is configured with:

✅ **Symlinked application code** from twitah-devsecops repository  
✅ **Automated database initialization** via init scripts  
✅ **Network isolation** with proxy-network for external access  
✅ **Production-ready** PHP and NGINX configurations  
✅ **Comprehensive documentation** in README.md  
✅ **Separate team workflows** for dev and infrastructure  

**Current Status**: Ready to deploy!

**Access**: http://172.20.0.30/ or http://sns.devsecops.local/ (via NPM)

---

**Last Updated**: October 11, 2025  
**Infrastructure Repository**: sns-devsecops (dev branch)  
**Application Repository**: twitah-devsecops
