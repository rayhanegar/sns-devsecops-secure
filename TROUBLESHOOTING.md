# 🔧 Troubleshooting Guide - SNS DevSecOps

## Common Issues and Solutions

### 🔴 Issue: 500 Internal Server Error

**URL**: http://sns.devsecops.local/

**Error in Logs**:
```
PHP Fatal error: Uncaught mysqli_sql_exception: 
Access denied for user 'sns_user'@'%' to database 'twita_db'
```

#### Root Cause

The MariaDB container only runs initialization scripts (`.sql` files in `/docker-entrypoint-initdb.d/`) when the database data directory is **completely empty**. 

If `db-data/` contains existing data from a previous setup, the database will start with the old credentials instead of using the values from your `.env` file.

#### Solution

**Option 1: Clean Start (Recommended)**
```bash
# Stop all containers
sudo docker compose down

# Delete old database data (WARNING: This deletes all data!)
sudo rm -rf db-data/*

# Start containers - init script will run automatically
sudo docker compose up -d

# Verify it's working
curl http://172.20.0.30/
```

**Option 2: Manual User Creation (Keep existing data)**
```bash
# Access the database
sudo docker compose exec sns-dso-db mysql -u root -p

# When prompted, try the old password or the new one
# Then run these commands:

CREATE USER IF NOT EXISTS 'sns_user'@'%' IDENTIFIED BY 'devsecops-admin';
GRANT ALL PRIVILEGES ON twita_db.* TO 'sns_user'@'%';
FLUSH PRIVILEGES;
EXIT;

# Restart the app container
sudo docker compose restart sns-dso-app
```

#### Verification

```bash
# Check container logs
sudo docker compose logs -f sns-dso-app

# Test the connection
sudo docker compose exec sns-dso-app php -r \
  "new mysqli('sns-dso-db', 'sns_user', 'devsecops-admin', 'twita_db') or die('Failed');"

# Access the website
curl http://172.20.0.30/
```

---

### 🔴 Issue: Symlink Not Working

**Symptom**: Container starts but application shows errors about missing files

**Check**:
```bash
ls -la /home/student/sns-devsecops/src
# Should show: src -> /home/student/twitah-devsecops/src
```

**Solution**:
```bash
# If symlink is broken
cd /home/student/sns-devsecops
rm src
ln -s /home/student/twitah-devsecops/src src

# Verify target exists
ls -la /home/student/twitah-devsecops/src

# Restart containers
sudo docker compose restart
```

---

### 🔴 Issue: Changes in Dev Repo Not Appearing

**Symptom**: You edit files in `twitah-devsecops` but changes don't show up

**Cause**: Symlink might not be properly mounted in container

**Solution**:
```bash
# Verify symlink in container
sudo docker compose exec sns-dso-app ls -la /var/www/html

# Should show files from twitah-devsecops/src

# If not, restart container
sudo docker compose restart sns-dso-app
```

---

### 🔴 Issue: Database Connection Refused

**Error**: `Connection refused` or `Can't connect to MySQL server`

**Check**:
```bash
# Is the database container running?
sudo docker compose ps sns-dso-db

# Check database logs
sudo docker compose logs sns-dso-db
```

**Solution**:
```bash
# Wait for database to be healthy
sudo docker compose ps

# If database keeps restarting, check init script syntax
cat database/01-init-twitah.sql

# Restart database
sudo docker compose restart sns-dso-db
```

---

### 🔴 Issue: 502 Bad Gateway

**Symptom**: Nginx returns 502 error

**Cause**: PHP-FPM is not running or not responding

**Check**:
```bash
# Is PHP-FPM running?
sudo docker compose ps sns-dso-app

# Check PHP-FPM logs
sudo docker compose logs sns-dso-app
```

**Solution**:
```bash
# Restart PHP-FPM
sudo docker compose restart sns-dso-app

# Check nginx config
sudo docker compose exec web nginx -t

# Verify fastcgi_pass setting
grep fastcgi_pass nginx/conf.d/default.conf
# Should show: fastcgi_pass sns-dso-app:9000;
```

---

### 🔴 Issue: Permission Denied on File Upload

**Symptom**: Cannot upload images/files

**Cause**: Upload directory permissions

**Solution**:
```bash
# Fix permissions in dev repo
cd /home/student/twitah-devsecops
sudo chown -R www-data:www-data src/uploads/
sudo chmod -R 755 src/uploads/

# Alternatively, make it writable by all (less secure)
chmod 777 src/uploads/
```

---

### 🔴 Issue: Port Already in Use

**Error**: `Bind for 0.0.0.0:80 failed: port is already allocated`

**Check**:
```bash
# Find what's using port 80
sudo netstat -tulpn | grep :80
```

**Solution**:
```bash
# Stop the conflicting service
# OR change the port in docker-compose.yaml

# Edit docker-compose.yaml to use a different port
# web:
#   ports:
#     - "8080:80"  # Use 8080 instead
```

---

### 🔴 Issue: Nginx Proxy Manager Can't Reach Container

**Symptom**: NPM shows offline or connection error

**Check**:
```bash
# Verify proxy-network exists
docker network ls | grep proxy-network

# Check if web container is on proxy-network
docker network inspect proxy-network | grep sns-dso-web

# Check IP address
docker inspect sns-dso-web | grep IPAddress
```

**Solution**:
```bash
# Recreate proxy-network if missing
docker network create proxy-network --subnet 172.20.0.0/16

# Restart containers to reconnect to network
sudo docker compose down
sudo docker compose up -d

# Verify container IP is 172.20.0.30
docker inspect sns-dso-web | grep -A 10 Networks
```

---

## 🛠️ General Debugging Steps

### 1. Check Container Status
```bash
sudo docker compose ps
```

All containers should show status "Up" and health "(healthy)" where applicable.

### 2. Check Logs
```bash
# All containers
sudo docker compose logs

# Specific container
sudo docker compose logs -f sns-dso-app
sudo docker compose logs -f web
sudo docker compose logs -f sns-dso-db
```

### 3. Check Environment Variables
```bash
# In app container
sudo docker compose exec sns-dso-app env | grep DB_

# In database container
sudo docker compose exec sns-dso-db env | grep MYSQL_
```

### 4. Test Database Connection
```bash
# From app container
sudo docker compose exec sns-dso-app php -r \
  "new mysqli('sns-dso-db', 'sns_user', 'devsecops-admin', 'twita_db') or die(mysqli_connect_error());"
```

### 5. Check File Permissions
```bash
# In app container
sudo docker compose exec sns-dso-app ls -la /var/www/html
```

### 6. Rebuild from Scratch
```bash
# Nuclear option - clean everything
sudo docker compose down -v
sudo rm -rf db-data/*

# Rebuild images
sudo docker compose build --no-cache

# Start fresh
sudo docker compose up -d
```

---

## 📞 Getting Help

If you're still having issues:

1. **Check the logs**: `sudo docker compose logs -f`
2. **Review configuration files**:
   - `docker-compose.yaml`
   - `nginx/conf.d/default.conf`
   - `.env`
3. **Verify symlink**: `ls -la src`
4. **Check README.md**: Complete documentation
5. **Check REFACTOR_SUMMARY.md**: Recent changes

---

**Last Updated**: October 11, 2025
