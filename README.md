# SNS-DevSecOps - Microblogging Platform Infrastructure

## Deskripsi Sistem

SNS-DevSecOps adalah platform microblogging berbasis web yang mengadopsi prinsip-prinsip DevSecOps dengan arsitektur containerized menggunakan Docker. Repositori ini (`sns-devsecops`) bertugas mengelola **infrastruktur dan deployment**, sementara kode aplikasi dikelola secara terpisah di repositori `rayhanegar/twitah-devsecops` oleh tim developer. Pemisahan ini memungkinkan separation of concerns antara infrastructure management dan application development, dengan integrasi melalui symbolic link untuk memastikan perubahan kode aplikasi dapat langsung tercermin dalam lingkungan deployment tanpa memerlukan rebuild container.

## Arsitektur Sistem

### Topologi Infrastructure

Deployment ini mengimplementasikan multi-tier architecture dengan tiga layer services yang terhubung melalui dua network layer yang terisolasi:

```
┌────────────────────────────────────────────────────────────────────┐
│                    proxy-network (172.20.0.0/16)                   │
│                       External Network Layer                       │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │          Nginx Proxy Manager (External Service)          │      │
│  │                   IP: 172.20.0.10                        │      │
│  │        Domain: sns.devsecops.local / sns.dso505.com      │      │
│  │         - Reverse Proxy & Load Balancing                 │      │
│  │         - SSL/TLS Termination (Let's Encrypt)            │      │
│  │         - Access Control & Security Headers              │      │
│  └──────────────────────┬───────────────────────────────────┘      │
│                         │ HTTP/HTTPS                               │
│                         │ Forward to: 172.20.0.30:80               │
│                         ▼                                          │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │              NGINX Web Server (sns-dso-web)              │      │
│  │                   IP: 172.20.0.30                        │      │
│  │         - Static File Serving                            │      │
│  │         - PHP-FPM FastCGI Proxy                          │      │
│  │         - Request Routing & URL Rewriting                │      │
│  │         - Access Logs & Error Logs                       │      │
│  └──────────────────────┬───────────────────────────────────┘      │
└─────────────────────────┼───────────────────────────────────-──────┘
                          │
                          │ sns-dso-internal network
                          │ (Bridge, Private Network)
                          │
            ┌─────────────┴─────────────┐
            │                           │
            ▼                           ▼
┌───────────────────────────┐  ┌───────────────────────────┐
│   PHP-FPM Application     │  │    MariaDB Database       │
│     (sns-dso-app)         │  │     (sns-dso-db)          │
│                           │  │                           │
│  - PHP 8.2-FPM Alpine     │  │  - MariaDB 10.11          │
│  - MVC Application Logic  │  │  - Database: twita_db     │
│  - Session Management     │  │  - Character Set: utf8mb4 │
│  - File Upload Handler    │  │  - Max Connections: 200   │
│  - Database Connector     │  │  - Health Check Enabled   │
│                           │  │                           │
│  Volume Mounts:           │  │  Volume Mounts:           │
│  - src/ (symlink)         │  │  - ./db-data              │
│  - storage/               │  │  - ./database (init SQL)  │
└───────────────────────────┘  └───────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│              Repository Integration Architecture                   │
│                                                                    │
│  ┌──────────────────────────────────────────────────────┐          │
│  │  Development Repository (rayhanegar/twitah-devsecops)│          │
│  │  /home/dso505/twitah-devsecops/                      │          │
│  │                                                      │          │
│  │  src/                                                │          │
│  │  ├── index.php        (Front Controller)             │          │
│  │  ├── config/          (DB Configuration)             │          │
│  │  ├── controllers/     (MVC Controllers)              │          │
│  │  ├── models/          (Data Models)                  │          │
│  │  ├── views/           (HTML Templates)               │          │
│  │  └── uploads/         (User-uploaded Media)          │          │
│  └──────────────────────┬───────────────────────────────┘          │
│                         │                                          │
│                         │ Symbolic Link                            │
│                         │                                          │
│                         ▼                                          │
│  ┌──────────────────────────────────────────────────────┐          │
│  │  Infrastructure Repository (sns-devsecops)           │          │
│  │  /home/dso505/sns-devsecops/                         │          │
│  │                                                      │          │
│  │  src/ → /home/dso505/twitah-devsecops/src (symlink)  │          │
│  │  docker-compose.yaml                                 │          │
│  │  Dockerfile                                          │          │
│  │  nginx/                                              │          │
│  │  database/                                           │          │
│  │  docker/                                             │          │
│  └──────────────────────────────────────────────────────┘          │
└────────────────────────────────────────────────────────────────────┘
```

### Pemisahan Repositori

Arsitektur ini mengimplementasikan **separation of concerns** dengan dua repositori terpisah:

1. **`rayhanegar/twitah-devsecops`** (Development Repository)
   - Mengelola source code aplikasi PHP dengan arsitektur MVC
   - Berisi logic bisnis, controllers, models, dan views
   - Maintained oleh development team
   - Independent versioning untuk application code
   - Lokasi: `/home/dso505/twitah-devsecops/`

2. **`sns-devsecops`** (Infrastructure Repository - repositori ini)
   - Mengelola Docker configuration dan orchestration
   - Berisi Dockerfile, docker-compose.yaml, nginx config
   - Maintained oleh DevOps/Infrastructure team
   - Independent versioning untuk infrastructure changes
   - Lokasi: `/home/dso505/sns-devsecops/`

3. **Integrasi via Symbolic Link**
   - Path: `./src` → `/home/dso505/twitah-devsecops/src`
   - Memungkinkan hot-reload: perubahan di development repo langsung terlihat
   - Tidak memerlukan rebuild container saat update kode aplikasi
   - Volume mount di Docker: `./src:/var/www/html:delegated`

## Services dan Komponen

### 1. PHP-FPM Application Container (`sns-dso-app`)

**Image:** Custom build dari `php:8.2-fpm-alpine`

**Fungsi:**
- Menjalankan aplikasi PHP dengan PHP-FPM (FastCGI Process Manager)
- Memproses business logic dari aplikasi microblogging MVC
- Menangani session management dan authentication
- Memproses file uploads (gambar untuk tweets)
- Melakukan koneksi ke database MariaDB untuk operasi CRUD

**Build Configuration:**
- **Base Image:** `php:8.2-fpm-alpine` (lightweight Alpine Linux)
- **Build Target:** `production` (multi-stage build)
- **Installed Extensions:**
  - `pdo_mysql`, `mysqli` - Database connectivity
  - `mbstring` - Multi-byte string handling
  - `gd`, `exif` - Image processing dan metadata
  - `zip` - Archive handling
  - `intl` - Internationalization
  - `bcmath`, `pcntl` - Math dan process control
- **Composer:** Installed untuk dependency management

**Container Configuration:**
- **Container Name:** `sns-dso-app`
- **Restart Policy:** `unless-stopped`
- **Network:** `sns-dso-internal` (isolated private network)
- **User:** `www-data` (non-root user untuk security)
- **Exposed Port:** 9000 (FastCGI)

**Environment Variables:**
- `DB_HOST`: Hostname database server (sns-dso-db)
- `DB_NAME`: Nama database (twita_db)
- `DB_USER`: Username database (sns_user)
- `DB_PASSWORD`: Password database (dari .env file)

**Volume Mounts:**
- `./src:/var/www/html:delegated` - Application code (symlinked dari twitah-devsecops)
- `./storage:/var/www/html/storage:delegated` - Writable storage untuk logs, cache, uploads

**Health Check:**
- Command: `php -v` (verify PHP binary)
- Interval: 30 detik
- Timeout: 10 detik
- Retries: 3 kali
- Start Period: 40 detik

**Dependencies:**
- Menunggu `sns-dso-db` ready sebelum start

### 2. NGINX Web Server Container (`web`)

**Image:** `nginx:alpine`

**Fungsi:**
- Bertindak sebagai reverse proxy untuk PHP-FPM application
- Melayani static files (CSS, JavaScript, images) secara langsung
- Melakukan URL rewriting untuk MVC routing
- Meneruskan PHP requests ke PHP-FPM via FastCGI protocol
- Logging akses dan error untuk monitoring
- Implementasi caching untuk static assets

**Container Configuration:**
- **Container Name:** `sns-dso-web`
- **Restart Policy:** `unless-stopped`
- **Networks:** 
  - `proxy-network` dengan static IP 172.20.0.30 (external facing)
  - `sns-dso-internal` (backend communication)
- **Exposed Port:** 80 (HTTP internal)

**Volume Mounts:**
- `./src:/var/www/html:ro` - Application code (read-only untuk security)
- `./nginx/conf.d:/etc/nginx/conf.d:ro` - NGINX configuration files (read-only)

**NGINX Configuration Highlights:**
```nginx
server {
    listen 80;
    server_name sns.devsecops;
    root /var/www/html;
    
    client_max_body_size 20M;  # Allow 20MB file uploads
    
    # MVC routing: rewrite all requests to index.php
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # PHP-FPM FastCGI configuration
    location ~ \.php$ {
        fastcgi_pass sns-dso-app:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        # Buffer configuration untuk performa
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
    }
    
    # Static files caching (365 days)
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        expires 365d;
        add_header Cache-Control "public, immutable";
    }
    
    # Security: deny access to hidden files
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

**Dependencies:**
- Menunggu `sns-dso-app` ready sebelum start

### 3. MariaDB Database Container (`sns-dso-db`)

**Image:** `mariadb:10.11`

**Fungsi:**
- Menyimpan data persistent aplikasi (users, tweets, sessions)
- Menjalankan database server dengan MariaDB engine
- Melakukan initialization dengan SQL schema saat first run
- Menyediakan health check untuk high availability
- Menggunakan utf8mb4 character set untuk full Unicode support

**Container Configuration:**
- **Container Name:** `sns-dso-db`
- **Restart Policy:** `unless-stopped`
- **Network:** `sns-dso-internal` only (tidak terekspos ke external network)
- **Exposed Port:** 3306 (MySQL protocol, internal only)

**Environment Variables:**
- `MYSQL_DATABASE`: twita_db (auto-created on first run)
- `MYSQL_USER`: sns_user (non-root user untuk aplikasi)
- `MYSQL_PASSWORD`: Password dari environment file
- `MYSQL_ROOT_PASSWORD`: Root password untuk administrasi

**Command Parameters:**
```bash
--character-set-server=utf8mb4           # Full Unicode support (emoji, special chars)
--collation-server=utf8mb4_unicode_ci    # Case-insensitive Unicode collation
--max-connections=200                     # Support untuk concurrent connections
```

**Volume Mounts:**
- `./db-data:/var/lib/mysql` - Persistent database storage
- `./database:/docker-entrypoint-initdb.d:ro` - Initialization SQL scripts (run once)

**Health Check:**
- Command: `healthcheck.sh --connect --innodb_initialized`
- Interval: 30 detik
- Timeout: 10 detik
- Retries: 5 kali
- Memastikan database service available dan InnoDB engine initialized

**Database Initialization:**
- File: `./database/01-init-twitah.sql`
- Dieksekusi otomatis saat database pertama kali dibuat (db-data kosong)
- Membuat schema dan seed data untuk development/testing

### 4. Redis Cache (Optional - Commented)

**Image:** `redis:7-alpine`

Service Redis tersedia dalam konfigurasi namun di-nonaktifkan secara default. Dapat diaktifkan untuk:
- Object caching untuk meningkatkan performa
- Session storage
- Queue management untuk background jobs

**Konfigurasi (jika diaktifkan):**
- **Container Name:** `sns-dso-redis`
- **Network:** `sns-dso-internal`
- **Persistence:** AOF (Append-Only File) mode
- **Volume:** `./redis-data:/data`

## Database Schema

### Struktur Database: `twita_db`

Database menggunakan schema relasional dengan dua tabel utama yang mengimplementasikan relationship one-to-many antara users dan tweets.

#### Tabel: `users`

**Deskripsi:** Menyimpan informasi user yang terdaftar dalam sistem.

| Kolom        | Tipe Data       | Constraint        | Deskripsi                                      |
|--------------|-----------------|-------------------|------------------------------------------------|
| `id`         | INT             | PRIMARY KEY, AUTO_INCREMENT | User ID unik                        |
| `username`   | VARCHAR(50)     | UNIQUE, NOT NULL  | Username untuk login (unique per system)       |
| `email`      | VARCHAR(100)    | UNIQUE, NOT NULL  | Email address user                             |
| `password`   | VARCHAR(255)    | NOT NULL          | Password (hashed untuk security)               |
| `role`       | VARCHAR(20)     | DEFAULT 'jelata'  | User role (jelata/admin untuk authorization)   |
| `created_at` | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP | Waktu registrasi user                  |

**Indexes:**
- PRIMARY KEY pada `id`
- UNIQUE INDEX pada `username`
- UNIQUE INDEX pada `email`

**Sample Data:**
```sql
INSERT INTO users (username, email, password) VALUES
('alice', 'alice@example.com', 'password123'),
('bob', 'bob@example.com', 'qwerty');
```

**Catatan Keamanan:**
- Password disimpan dalam plaintext dalam sample data (untuk demo/learning)
- **Production:** harus menggunakan password hashing (bcrypt, Argon2)
- Role 'jelata' adalah default user role (non-privileged)

#### Tabel: `tweets`

**Deskripsi:** Menyimpan konten tweets/posts yang dibuat oleh users.

| Kolom        | Tipe Data       | Constraint        | Deskripsi                                      |
|--------------|-----------------|-------------------|------------------------------------------------|
| `id`         | INT             | PRIMARY KEY, AUTO_INCREMENT | Tweet ID unik                        |
| `user_id`    | INT             | FOREIGN KEY, NOT NULL | Reference ke users.id (pemilik tweet)    |
| `content`    | TEXT            | NOT NULL          | Isi konten tweet (text/message)                |
| `image_url`  | VARCHAR(255)    | NULL              | Path ke image upload (optional)                |
| `created_at` | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP | Waktu tweet dibuat                     |

**Relationships:**
- FOREIGN KEY `user_id` REFERENCES `users(id)`
  - One user can have many tweets (1:N relationship)
  - Cascade behavior: not specified (manual handling in application)

**Indexes:**
- PRIMARY KEY pada `id`
- FOREIGN KEY INDEX pada `user_id`

**Sample Data:**
```sql
INSERT INTO tweets (user_id, content) VALUES
(1, 'Hello world!'),
(2, 'Ini tweet dari Bob');
```

#### Entity Relationship Diagram (ERD)

```
┌─────────────────────────┐
│        users            │
├─────────────────────────┤
│ PK  id (INT)            │
│ UQ  username (VARCHAR)  │
│ UQ  email (VARCHAR)     │
│     password (VARCHAR)  │
│     role (VARCHAR)      │
│     created_at (TS)     │
└───────────┬─────────────┘
            │ 1
            │
            │ has many
            │
            │ N
┌───────────┴─────────────┐
│        tweets           │
├─────────────────────────┤
│ PK  id (INT)            │
│ FK  user_id (INT)       │
│     content (TEXT)      │
│     image_url (VARCHAR) │
│     created_at (TS)     │
└─────────────────────────┘
```

#### Database Initialization

Database schema dan seed data diinisialisasi otomatis menggunakan MariaDB's entrypoint initialization mechanism:

1. File SQL: `./database/01-init-twitah.sql`
2. Execution: Saat container `sns-dso-db` pertama kali dibuat (db-data directory kosong)
3. Process:
   - Drop existing tables (jika ada)
   - Create database `twita_db`
   - Create tables `users` dan `tweets`
   - Insert sample data untuk testing

**PENTING:** Initialization scripts hanya dijalankan sekali. Jika ingin re-initialize:
```bash
docker-compose down
sudo rm -rf db-data/*
docker-compose up -d
```

## Network Architecture

### 1. proxy-network (External Network)

**Konfigurasi:**
- **Network Name:** `proxy-network`
- **Driver:** Bridge
- **Subnet:** 172.20.0.0/16
- **Gateway:** 172.20.0.1
- **Type:** External (pre-created, shared across multiple projects)

**Purpose:**
- Menghubungkan services dengan Nginx Proxy Manager
- Memungkinkan reverse proxy dari external domain ke internal services
- Shared network untuk multiple applications di infrastructure yang sama

**Connected Services:**
- Nginx Proxy Manager (172.20.0.10)
- WordPress (172.20.0.20) - dari wordpress-dso deployment
- SNS Web Server (172.20.0.30) - dari deployment ini

**Labels:**
```yaml
com.devsecops.description: "Shared network for reverse proxy"
com.devsecops.managed-by: "nginx-proxy-manager"
```

### 2. sns-dso-internal (Internal Network)

**Konfigurasi:**
- **Network Name:** `sns-dso-internal`
- **Driver:** Bridge
- **IPAM:** Automatic IP assignment
- **Type:** Internal (created by docker-compose)

**Purpose:**
- Isolasi komunikasi antara application tier dan database tier
- Security: database tidak terekspos ke external network
- Private communication channel untuk service-to-service calls

**Connected Services:**
- NGINX Web Server (`web`)
- PHP-FPM Application (`sns-dso-app`)
- MariaDB Database (`sns-dso-db`)

**Security Benefits:**
- Database hanya accessible dari application container
- Tidak ada direct external access ke database port 3306
- Network segmentation sesuai principle of least privilege

## Struktur Direktori

```
sns-devsecops/
├── docker/                          # Container-specific configurations
│   └── php/
│       ├── php.dev.ini              # PHP development settings (debug enabled)
│       └── php.prod.ini             # PHP production settings (optimized)
│
├── nginx/                           # NGINX web server configurations
│   └── conf.d/
│       └── default.conf             # Virtual host configuration untuk sns.devsecops
│
├── database/                        # Database initialization scripts
│   └── 01-init-twitah.sql          # Schema creation dan seed data
│
├── src/ → symlink                   # ⚡ Symbolic link ke /home/dso505/twitah-devsecops/src
│                                    # Berisi application code (MVC structure)
│
├── storage/                         # Writable storage directory (mounted ke container)
│   ├── cache/                       # Application cache files
│   ├── logs/                        # Application logs
│   └── uploads/                     # User-uploaded files (images untuk tweets)
│
├── db-data/                         # ⚠️  Database persistent storage (gitignored)
│   ├── mysql/                       # MySQL system database
│   ├── performance_schema/          # Performance monitoring
│   ├── sys/                         # System schema
│   └── twita_db/                    # Application database
│
├── docker-compose.yaml              # Service orchestration configuration
├── Dockerfile                       # PHP-FPM 8.2 custom image build
├── .env                             # ⚠️  Environment variables dengan credentials (gitignored)
├── .env.example                     # Template environment variables untuk setup
├── .gitignore                       # Git ignore rules untuk sensitive files
│
├── README.md                        # Dokumentasi lengkap (file ini)
├── SETUP_SUMMARY.md                 # Ringkasan setup dan configuration
└── TROUBLESHOOTING.md               # Panduan troubleshooting untuk common issues
```

### File dan Directory yang Tidak Di-commit

Pastikan file-file berikut **TIDAK** di-commit ke version control (sudah ada di `.gitignore`):

- `.env` - Environment variables dengan database credentials
- `db-data/` - Database files dengan sensitive user data
- `storage/logs/` - Application logs yang mungkin berisi sensitive information
- `storage/uploads/` - User-uploaded files
- `src/` - Symbolic link (destination directory di repository terpisah)

## Panduan Instalasi dan Setup

### Prasyarat

1. **System Requirements:**
   - Docker Engine versi 20.10 atau lebih baru
   - Docker Compose versi 2.0 atau lebih baru
   - Linux OS (tested pada Ubuntu 20.04/22.04)
   - Minimum 2GB RAM available
   - Minimum 10GB disk space

2. **Network Requirements:**
   - Network `proxy-network` (172.20.0.0/16) sudah dibuat
   - Nginx Proxy Manager sudah terinstall dan berjalan
   - Port 172.20.0.30:80 available (tidak bentrok dengan service lain)

3. **Repository Requirements:**
   - Repository `rayhanegar/twitah-devsecops` sudah di-clone
   - Symbolic link `src` sudah dibuat dan pointing ke twitah-devsecops/src

### Langkah 1: Clone Repositori

```bash
# Clone infrastructure repository
cd /home/dso505
git clone <repository-url> sns-devsecops
cd sns-devsecops

# Verify repository structure
ls -la
```

### Langkah 2: Clone Application Repository

```bash
# Clone application code repository
cd /home/dso505
git clone https://github.com/rayhanegar/twitah-devsecops.git

# Verify application structure
ls -la twitah-devsecops/src
```

### Langkah 3: Create Symbolic Link

```bash
# Masuk ke infrastructure repository
cd /home/dso505/sns-devsecops

# Hapus src directory jika sudah ada
rm -rf src

# Buat symbolic link ke application repository
ln -s /home/dso505/twitah-devsecops/src src

# Verify symlink
ls -la src
# Output: src -> /home/dso505/twitah-devsecops/src
```

### Langkah 4: Konfigurasi Environment Variables

1. Salin template environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit file `.env` dengan editor:
   ```bash
   nano .env
   ```

3. Konfigurasi credentials yang aman:
   ```env
   # Database Configuration
   DB_HOST=sns-dso-db
   DB_NAME=twita_db
   DB_USER=sns_user
   DB_PASSWORD=<strong_password_here>
   DB_ROOT_PASSWORD=<strong_root_password_here>
   
   # Application Configuration
   APP_VERSION=latest
   ```

**Best Practices untuk Password:**
- Minimal 16 karakter
- Kombinasi huruf besar, kecil, angka, dan simbol
- Tidak menggunakan dictionary words
- Berbeda antara DB_PASSWORD dan DB_ROOT_PASSWORD
- Gunakan password manager atau generator

### Langkah 5: Verify Network Proxy

```bash
# Check apakah proxy-network sudah ada
docker network ls | grep proxy-network

# Jika belum ada, buat network baru
docker network create proxy-network \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  --label com.devsecops.description="Shared network for reverse proxy"

# Verify network details
docker network inspect proxy-network
```

### Langkah 6: Deploy Services

1. Build dan start semua containers:
   ```bash
   docker-compose up -d --build
   ```

2. Monitor build dan startup process:
   ```bash
   docker-compose logs -f
   ```

3. Verify semua containers running:
   ```bash
   docker-compose ps
   ```

   Expected output:
   ```
   NAME          STATUS         PORTS
   sns-dso-app   Up (healthy)   9000/tcp
   sns-dso-web   Up             80/tcp
   sns-dso-db    Up (healthy)   3306/tcp
   ```

4. Check health status:
   ```bash
   docker-compose ps --format json | jq '.[].Health'
   ```

### Langkah 7: Konfigurasi Nginx Proxy Manager

1. Akses Nginx Proxy Manager web interface:
   ```
   URL: http://<server-ip>:81
   Default credentials:
   - Email: admin@example.com
   - Password: changeme
   ```

2. **PENTING:** Change default password setelah first login

3. Tambahkan Proxy Host baru:
   - Navigasi ke: **Hosts** > **Proxy Hosts** > **Add Proxy Host**

4. Konfigurasi Details Tab:
   ```
   Domain Names: sns.devsecops.local (atau sns.dso505.com)
   Scheme: http
   Forward Hostname / IP: 172.20.0.30
   Forward Port: 80
   Cache Assets: ✓ (enabled)
   Block Common Exploits: ✓ (enabled)
   Websockets Support: ✓ (enabled)
   ```

5. (Opsional) Konfigurasi SSL Tab untuk HTTPS:
   - Untuk domain publik: gunakan **Let's Encrypt** certificate
   - Untuk domain lokal: upload **Custom Certificate**
   - Enable: Force SSL, HTTP/2 Support, HSTS Enabled

6. Konfigurasi Advanced Tab (optional security headers):
   ```nginx
   # Security Headers
   add_header X-Frame-Options "SAMEORIGIN" always;
   add_header X-Content-Type-Options "nosniff" always;
   add_header X-XSS-Protection "1; mode=block" always;
   add_header Referrer-Policy "no-referrer-when-downgrade" always;
   
   # Rate Limiting (optional)
   limit_req_zone $binary_remote_addr zone=sns_limit:10m rate=10r/s;
   limit_req zone=sns_limit burst=20 nodelay;
   ```

7. Save dan test configuration

### Langkah 8: Verify Deployment

1. Test direct access ke NGINX container:
   ```bash
   curl -I http://172.20.0.30/
   ```

   Expected: HTTP 200 OK response

2. Test melalui domain dengan hosts file (untuk local testing):
   ```bash
   sudo nano /etc/hosts
   ```

   Tambahkan entry:
   ```
   <server-ip>  sns.devsecops.local
   ```

3. Test akses via browser:
   ```
   http://sns.devsecops.local
   ```

4. Verify database connectivity:
   ```bash
   docker-compose exec sns-dso-db mysql -u sns_user -p${DB_PASSWORD} -e "SHOW DATABASES;"
   ```

5. Check application logs:
   ```bash
   docker-compose logs -f sns-dso-app
   docker-compose logs -f web
   docker-compose logs -f sns-dso-db
   ```

### Langkah 9: Initialize Application Data

Jika perlu re-initialize database dengan fresh data:

```bash
# Stop containers
docker-compose down

# Remove database data
sudo rm -rf db-data/*

# Start containers (akan auto-run init SQL)
docker-compose up -d

# Verify initialization
docker-compose exec sns-dso-db mysql -u sns_user -p${DB_PASSWORD} twita_db -e "SELECT * FROM users;"
```

## Referensi

### Documentation

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PHP Official Docker Images](https://hub.docker.com/_/php)
- [NGINX Official Documentation](https://nginx.org/en/docs/)
- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)
- [Nginx Proxy Manager](https://nginxproxymanager.com/guide/)

### Related Repositories

- **Application Code:** [rayhanegar/twitah-devsecops](https://github.com/rayhanegar/twitah-devsecops)
- **Infrastructure:** `sns-devsecops` (repositori ini)

---

**Terakhir Diperbarui:** Oktober 2025  
**Version:** 1.0.0  
**License:** Educational Use Only
