#!/bin/bash

# ==============================================================================
# Laravel 13 + React + FrankenPHP + MariaDB Auto-Deployment Script (Debian 12)
# ==============================================================================
# Script Name: auto-react.sh
# Supports: Debian 12 (Bookworm)
# ==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. Root & OS Check
if [[ $EUID -ne 0 ]]; then
    log_error "Harus dijalankan sebagai root (sudo)."
    exit 1
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "debian" || "$VERSION_ID" != "12" ]]; then
        log_error "Script ini hanya untuk Debian 12."
        exit 1
    fi
else
    log_error "Sistem operasi tidak terdeteksi."
    exit 1
fi

# 2. Input Configuration
echo -e "${BLUE}=== Konfigurasi Deployment ===${NC}"
read -p "Nama Domain (contoh: example.com): " DOMAIN_NAME
read -p "Git Repository URL (Biarkan kosong untuk install Fresh Laravel): " GIT_REPO
read -p "Admin Email (untuk SSL Certbot): " ADMIN_EMAIL
read -sp "Password Mysql Root Baru: " MYSQL_ROOT_PASSWORD
echo ""
read -sp "Password Database User (untuk Laravel): " DB_PASSWORD
echo ""

APP_DIR="/var/www/$DOMAIN_NAME"
DB_NAME=$(echo $DOMAIN_NAME | sed 's/\./_/g')
DB_USER="user_$DB_NAME"

# 3. System Update & Dependencies
log_info "Updating system packages..."
apt update && apt upgrade -y
apt install -y curl git unzip wget gnupg lsb-release ca-certificates software-properties-common ufw supervisor sed

# 4. Setup PHP 8.4 (Sury Repo)
log_info "Installing PHP 8.4..."
curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
apt update
apt install -y php8.4-cli php8.4-common php8.4-fpm php8.4-mysql php8.4-zip php8.4-gd php8.4-mbstring php8.4-curl php8.4-xml php8.4-bcmath php8.4-intl php8.4-sqlite3 php8.4-redis

# 5. Setup Node.js 22 LTS
log_info "Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# 6. Setup MariaDB (MySQL)
log_info "Installing MariaDB..."
apt install -y mariadb-server
systemctl enable mariadb
systemctl start mariadb

# Auto-secure MariaDB
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE $DB_NAME;"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

# 7. Setup Composer
log_info "Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# 8. Download FrankenPHP
log_info "Downloading FrankenPHP binary..."
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    VERSION_ARCH="linux-x86_64"
elif [ "$ARCH" == "aarch64" ]; then
    VERSION_ARCH="linux-aarch64"
else
    log_error "Arsitektur $ARCH tidak didukung untuk binary otomatis."
    exit 1
fi

curl -L "https://github.com/dunglas/frankenphp/releases/download/v1.4.2/frankenphp-$VERSION_ARCH" -o /usr/local/bin/frankenphp
chmod +x /usr/local/bin/frankenphp
setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp

# 9. Setup Firewall
log_info "Configuring Firewall..."
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 80
ufw allow 443
echo "y" | ufw enable

# 10. Deploy Application
log_info "Preparing application directory..."
mkdir -p "$APP_DIR"
cd "$APP_DIR"

if [ -z "$GIT_REPO" ]; then
    log_info "Installing Fresh Laravel 13..."
    composer create-project laravel/laravel .
else
    log_info "Cloning Repository: $GIT_REPO"
    git clone "$GIT_REPO" .
fi

# Permissions
chown -R www-data:www-data "$APP_DIR"
chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"

# .env Setup
if [ ! -f .env ]; then
    cp .env.example .env
fi

# Update .env
sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env
sed -i "s/DB_HOST=.*/DB_HOST=127.0.0.1/" .env
sed -i "s/DB_PORT=.*/DB_PORT=3306/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN_NAME|" .env

php artisan key:generate --force

# Composer & NPM Build
log_info "Installing dependencies & building assets..."
composer install --no-interaction --prefer-dist --optimize-autoloader
npm install && npm run build

# Final Migrations
php artisan migrate --force

# 11. Supervisor Configuration (FrankenPHP)
log_info "Configuring Supervisor for FrankenPHP..."
FRANKEN_LOG="/var/log/frankenphp-$DOMAIN_NAME.log"
touch "$FRANKEN_LOG"
chown www-data:www-data "$FRANKEN_LOG"

cat > /etc/supervisor/conf.d/frankenphp-$DOMAIN_NAME.conf <<EOF
[program:frankenphp-$DOMAIN_NAME]
command=/usr/local/bin/frankenphp php-server --listen :8000 --root $APP_DIR/public
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=$FRANKEN_LOG
stopasgroup=true
killasgroup=true
EOF

supervisorctl reread
supervisorctl update

# 12. Nginx Reverse Proxy & SSL
log_info "Configuring Nginx Reverse Proxy..."
apt install -y nginx python3-certbot-nginx

cat > /etc/nginx/sites-available/$DOMAIN_NAME <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 100M;
    }
}
EOF

ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

log_info "Requesting SSL Certificate..."
certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos -m $ADMIN_EMAIL

# Final Status
echo -e "${GREEN}====================================================${NC}"
log_success "Deployment Selesai!"
echo -e "Domain: https://$DOMAIN_NAME"
echo -e "Database: $DB_NAME"
echo -e "DB User: $DB_USER"
echo -e "Port Internal: 8000"
echo -e "Log: $FRANKEN_LOG"
echo -e "${GREEN}====================================================${NC}"
