# SNS DevSecOps - Database Setup Guide

## Overview

This guide explains how to set up and configure the SNS DevSecOps database environment.

## Database Schema

### Users Table

| Column | Type | Description |
|--------|------|-------------|
| id | INT | Primary key (auto-increment) |
| username | VARCHAR(50) | Unique username |
| email | VARCHAR(100) | Unique email address |
| password | VARCHAR(255) | Hashed password |
| role | VARCHAR(20) | User role (default: 'jelata') |
| failed_attempts | INT | Failed login attempts counter |
| last_attempt | DATETIME | Timestamp of last failed login |
| locked_until | DATETIME | Account lock expiration time |
| created_at | TIMESTAMP | Account creation timestamp |

### Tweets Table

| Column | Type | Description |
|--------|------|-------------|
| id | INT | Primary key (auto-increment) |
| user_id | INT | Foreign key to users table |
| content | TEXT | Tweet content |
| image_url | VARCHAR(255) | Optional image URL |
| created_at | TIMESTAMP | Tweet creation timestamp |

## Environment Variables

The database connection uses the following environment variables (defined in `.env`):

```bash
DB_HOST=sns-dso-db          # Database container hostname
DB_NAME=twita_db            # Database name
DB_USER=sns_user            # Database user
DB_PASSWORD=devsecops-admin # Database password
DB_ROOT_PASSWORD=devsecops-admin  # Root password
```

## Quick Setup

### Option 1: Automated Setup Script (Recommended)

Run the setup script to automatically configure everything:

```bash
cd /home/dso505/sns-devsecops
./setup-db.sh
```

This script will:
1. Load environment variables from `.env`
2. Check if database container is running
3. Test database connection
4. Display current schema
5. Apply schema updates (add missing columns)
6. Create performance indexes
7. Verify the final schema
8. Display connection summary

### Option 2: Manual Setup

If you prefer manual setup:

1. **Ensure containers are running:**
   ```bash
   cd /home/dso505/sns-devsecops
   docker-compose up -d
   ```

2. **Apply schema updates:**
   ```bash
   docker exec sns-dso-db mysql -usns_user -pdevsecops-admin twita_db < database/02-update-schema.sql
   ```

3. **Verify schema:**
   ```bash
   docker exec sns-dso-db mysql -usns_user -pdevsecops-admin -e "USE twita_db; DESCRIBE users;"
   ```

## Fresh Database Initialization

If you need to completely reset the database:

```bash
# Stop containers
docker-compose down

# Remove database volume
rm -rf db-data/

# Start containers (will run initialization scripts)
docker-compose up -d

# Wait for initialization (check logs)
docker logs sns-dso-db --tail 50
```

The initialization script `database/01-init-twitah.sql` will automatically:
- Create the `twita_db` database
- Create `users` and `tweets` tables with complete schema
- Add indexes for performance
- Insert sample data

## Connection Details

### Connect from Host Machine

```bash
docker exec -it sns-dso-db mysql -usns_user -pdevsecops-admin twita_db
```

### Connect from PHP Application

The connection is handled in `config/config.php`:

```php
$host = getenv('DB_HOST') ?: "sns-dso-db";
$user = getenv('DB_USER') ?: "sns_user";
$pass = getenv('DB_PASSWORD') ?: "";
$dbname = getenv('DB_NAME') ?: "twita_db";

$conn = new mysqli($host, $user, $pass, $dbname);
```

## Troubleshooting

### Check if containers are running

```bash
docker ps --filter name=sns-dso
```

### View database logs

```bash
docker logs sns-dso-db --tail 50
```

### View application logs

```bash
docker logs sns-dso-app --tail 50
```

### Test database connection

```bash
docker exec sns-dso-db mysql -usns_user -pdevsecops-admin -e "SELECT 1;"
```

### Check current schema

```bash
docker exec sns-dso-db mysql -usns_user -pdevsecops-admin twita_db -e "SHOW TABLES; DESCRIBE users; DESCRIBE tweets;"
```

### Restart application after schema changes

```bash
docker-compose restart sns-dso-app
```

## Database Features

### Brute Force Protection

The `users` table includes columns for tracking failed login attempts:
- After 3 failed attempts, the account is locked for 180 seconds
- `failed_attempts`: Counter for consecutive failed logins
- `last_attempt`: Timestamp of the last failed login
- `locked_until`: Expiration time for account lock

This is implemented in `models/User.php` in the `login()` method.

### Performance Indexes

The following indexes are created for better query performance:
- `idx_email` on `users.email`
- `idx_locked_until` on `users.locked_until`
- `idx_user_tweets` on `tweets.user_id`
- `idx_created_at` on `tweets.created_at`

## Files Reference

- `database/01-init-twitah.sql` - Initial database schema (for fresh setup)
- `database/02-update-schema.sql` - Schema migration (for existing database)
- `setup-db.sh` - Automated setup script
- `.env` - Environment variables configuration
- `docker-compose.yaml` - Container orchestration
- `config/config.php` - Database connection configuration

## Security Notes

1. **Passwords**: The sample data includes plain-text passwords. In production, always use `password_hash()` for storing passwords.
2. **Environment Variables**: Never commit `.env` files with production credentials to version control.
3. **Database Access**: The database is only accessible within the Docker network by default.
4. **SQL Injection**: The application uses prepared statements to prevent SQL injection.

## Support

For issues or questions, check:
1. Application logs: `docker logs sns-dso-app --tail 50`
2. Database logs: `docker logs sns-dso-db --tail 50`
3. Container status: `docker ps -a --filter name=sns-dso`
