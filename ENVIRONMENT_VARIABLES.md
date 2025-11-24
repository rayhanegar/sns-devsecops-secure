# Environment Variables - Single Source of Truth

## Overview

This document describes the environment variable architecture for the SNS DevSecOps application. All environment variables are centrally managed in the `.env` file, which serves as the **single source of truth** for configuration.

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────┐
│  .env (Single Source of Truth)                              │
│  /home/dso505/sns-devsecops/.env                            │
│                                                             │
│  DB_HOST=sns-dso-db                                         │
│  DB_NAME=twita_db                                           │
│  DB_USER=sns_user                                           │
│  DB_PASSWORD=devsecops-admin                                │
│  DB_ROOT_PASSWORD=devsecops-admin                           │
│  APP_VERSION=latest                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ├─────────────────────────────────────────┐
                  │                                         │
                  ▼                                         ▼
┌─────────────────────────────────┐   ┌──────────────────────────────┐
│  docker-compose.yaml            │   │  Docker Container            │
│                                 │   │  (sns-dso-app)               │
│  services:                      │   │                              │
│    sns-dso-app:                 │   │  Environment Variables:      │
│      environment:               │   │  - DB_HOST (from .env)       │
│        - DB_HOST=${DB_HOST}     │   │  - DB_NAME (from .env)       │
│        - DB_NAME=${DB_NAME}     │   │  - DB_USER (from .env)       │
│        - DB_USER=${DB_USER}     │   │  - DB_PASSWORD (from .env)   │
│        - DB_PASSWORD=${DB_PASS..│   │                              │
│                                 │   │  ┌────────────────────────┐  │
│    sns-dso-db:                  │   │  │ PHP Application        │  │
│      environment:               │   │  │ /var/www/html/         │  │
│        - MYSQL_DATABASE=${..}   │   │  │                        │  │
│        - MYSQL_USER=${DB_USER}  │   │  │ config/config.php:     │  │
│        - MYSQL_PASSWORD=${..}   │   │  │ getenv('DB_HOST')      │  │
│        - MYSQL_ROOT_PASSWORD=.. │   │  │ getenv('DB_NAME')      │  │
└─────────────────────────────────┘   │  │ getenv('DB_USER')      │  │
                                      │  │ getenv('DB_PASSWORD')  │  │
                                      │  └────────────────────────┘  │
                                      └──────────────────────────────┘
```

## Environment Variables Reference

### Database Configuration

| Variable | Default Value | Description | Used By |
|----------|--------------|-------------|---------|
| `DB_HOST` | `sns-dso-db` | Database server hostname | PHP app, MariaDB container |
| `DB_NAME` | `twita_db` | Database name | PHP app, MariaDB container |
| `DB_USER` | `sns_user` | Database user (non-root) | PHP app, MariaDB container |
| `DB_PASSWORD` | (required) | Database user password | PHP app, MariaDB container |
| `DB_ROOT_PASSWORD` | (required) | Database root password | MariaDB container only |

### Application Configuration

| Variable | Default Value | Description | Used By |
|----------|--------------|-------------|---------|
| `APP_VERSION` | `latest` | Docker image version tag | Docker build process |

## File Locations

### Primary Configuration Files

1. **`.env`** (Single Source of Truth)
   - Location: `/home/dso505/sns-devsecops/.env`
   - Purpose: Stores all environment variables
   - Security: **NEVER commit to version control** (in .gitignore)

2. **`.env.example`** (Template)
   - Location: `/home/dso505/sns-devsecops/.env.example`
   - Purpose: Template for creating .env file
   - Security: Safe to commit (contains no actual credentials)

3. **`docker-compose.yaml`**
   - Location: `/home/dso505/sns-devsecops/docker-compose.yaml`
   - Purpose: Passes environment variables from .env to containers
   - Pattern: `${VARIABLE_NAME:-default_value}`

4. **`config/config.php`**
   - Location: `/home/dso505/sns-devsecops/src/config/config.php`
   - Purpose: Loads environment variables in PHP application
   - Method: Uses `getenv()` to read from container environment

## How Environment Variables Flow

### 1. Define in .env File

```bash
# /home/dso505/sns-devsecops/.env
DB_HOST=sns-dso-db
DB_NAME=twita_db
DB_USER=sns_user
DB_PASSWORD=devsecops-admin
DB_ROOT_PASSWORD=devsecops-admin
APP_VERSION=latest
```

### 2. Docker Compose Reads .env

When you run `docker-compose up`, Docker Compose automatically reads the `.env` file in the same directory and substitutes variables.

```yaml
# docker-compose.yaml
services:
  sns-dso-app:
    environment:
      - DB_HOST=${DB_HOST:-sns-dso-db}
      - DB_NAME=${DB_NAME:-twita_db}
      - DB_USER=${DB_USER:-sns_user}
      - DB_PASSWORD=${DB_PASSWORD}
```

The syntax `${VAR:-default}` means:
- Use value from `.env` if available
- Otherwise use `default`

### 3. Container Receives Environment Variables

The `sns-dso-app` container starts with these environment variables set in its environment.

### 4. PHP Reads from Container Environment

```php
// src/config/config.php
$host = getenv('DB_HOST') ?: 'sns-dso-db';
$user = getenv('DB_USER') ?: 'sns_user';
$pass = getenv('DB_PASSWORD');
$dbname = getenv('DB_NAME') ?: 'twita_db';
```

## Security Best Practices

### ✅ DO:

1. **Keep .env file secure**
   ```bash
   chmod 600 .env  # Only owner can read/write
   ```

2. **Use strong passwords in production**
   ```bash
   DB_PASSWORD=$(openssl rand -base64 32)
   DB_ROOT_PASSWORD=$(openssl rand -base64 32)
   ```

3. **Use different passwords for different environments**
   - Development: Simple passwords for testing
   - Staging: Medium-strength passwords
   - Production: Strong, randomly generated passwords

4. **Regularly rotate passwords**
   - Update `.env` file
   - Recreate database container
   - Update application config if needed

### ❌ DON'T:

1. **Never commit .env to version control**
   - Already in `.gitignore`
   - Use `.env.example` for templates

2. **Never hardcode credentials in code**
   - Always use `getenv()` or environment variables
   - No direct string values like `"password123"`

3. **Never expose .env via web server**
   - NGINX already blocks `.env` files
   - Verify: `location ~ /\.(env|git|gitignore|htaccess) { deny all; }`

## Verification Commands

### Check if .env is loaded correctly

```bash
# View docker-compose variables (without starting containers)
docker-compose config

# Check environment variables in running container
docker exec sns-dso-app env | grep DB_

# Test database connection with environment variables
docker exec sns-dso-app php -r "
\$host = getenv('DB_HOST');
\$user = getenv('DB_USER');
\$pass = getenv('DB_PASSWORD');
\$db = getenv('DB_NAME');
echo \"Connecting to: \$host as \$user...\n\";
\$conn = new mysqli(\$host, \$user, \$pass, \$db);
if (\$conn->connect_error) {
    die('Failed: ' . \$conn->connect_error);
}
echo \"Success!\n\";
"
```

### Check if .env file exists and is readable

```bash
# Check file exists
ls -la /home/dso505/sns-devsecops/.env

# Check file permissions
stat /home/dso505/sns-devsecops/.env

# View file contents (be careful in production!)
cat /home/dso505/sns-devsecops/.env
```

## Troubleshooting

### Issue: Environment variables not loading

**Symptom**: Application can't connect to database

**Check**:
```bash
# 1. Verify .env exists
ls -la /home/dso505/sns-devsecops/.env

# 2. Check docker-compose can read it
cd /home/dso505/sns-devsecops
docker-compose config | grep DB_

# 3. Check container environment
docker exec sns-dso-app env | grep DB_
```

**Solution**:
- Ensure .env is in same directory as docker-compose.yaml
- Restart containers: `docker-compose down && docker-compose up -d`

### Issue: Database password mismatch

**Symptom**: "Access denied for user 'sns_user'"

**Cause**: Database was created with different password

**Solution**:
```bash
# Stop containers
docker-compose down

# Remove database data (WARNING: deletes all data!)
sudo rm -rf db-data/*

# Start fresh (will use new .env values)
docker-compose up -d
```

### Issue: Empty password in PHP

**Symptom**: `DB_PASSWORD environment variable is not set`

**Solution**:
1. Check .env file has `DB_PASSWORD=...`
2. Restart container: `docker-compose restart sns-dso-app`
3. Verify: `docker exec sns-dso-app env | grep DB_PASSWORD`

## Migration from Hardcoded Values

If you had hardcoded values before, here's how to migrate:

### Before (Hardcoded):
```php
$host = "sns-dso-db";
$user = "sns_user";
$pass = "devsecops-admin";
$dbname = "twita_db";
```

### After (Environment Variables):
```php
$host = getenv('DB_HOST') ?: 'sns-dso-db';
$user = getenv('DB_USER') ?: 'sns_user';
$pass = getenv('DB_PASSWORD');
$dbname = getenv('DB_NAME') ?: 'twita_db';
```

### Migration Steps:
1. ✅ Create .env file with all variables
2. ✅ Update config/config.php to use getenv()
3. ✅ Update docker-compose.yaml to pass env vars
4. ✅ Restart containers
5. ✅ Test application connectivity

## Summary

✅ **Single Source of Truth**: All configuration in `.env`  
✅ **Secure by Default**: .env never committed to version control  
✅ **Environment Agnostic**: Same code, different .env files  
✅ **Docker Native**: Uses docker-compose environment variable substitution  
✅ **Validation**: PHP config validates required variables  
✅ **Fallback Defaults**: Safe defaults for development  

**Last Updated**: November 24, 2025
