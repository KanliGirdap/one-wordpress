#!/bin/bash

# Drupal Otomatik Kurulum Scripti
# Bu script Ubuntu sistemde Drupal'ı hiçbir kullanıcı etkileşimi olmadan kurar

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Varsayılan değerler
DRUPAL_VERSION="10.2.0"
MYSQL_ROOT_PASSWORD="rootpassword123"
DRUPAL_DB_NAME="drupal_db"
DRUPAL_DB_USER="drupal_user"
DRUPAL_DB_PASSWORD="drupal_password123"
DRUPAL_ADMIN_USER="admin"
DRUPAL_ADMIN_PASSWORD="admin123456"
SITE_NAME="My Drupal Site"
SITE_EMAIL="admin@drupal.local"
DRUPAL_INSTALL_DIR="/var/www/html/drupal"

echo -e "${GREEN}Drupal otomatik kurulumu başlıyor...${NC}"

# Sistem güncellemeleri
echo -e "${YELLOW}Sistem güncelleştiriliyor...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Gerekli paketleri kur
echo -e "${YELLOW}Gerekli paketler kuruluyor...${NC}"
apt-get install -y \
    apache2 \
    mysql-server \
    php \
    php-mysql \
    php-xml \
    php-mbstring \
    php-curl \
    php-opcache \
    php-gd \
    php-zip \
    php-intl \
    libapache2-mod-php \
    curl \
    unzip \
    wget \
    composer \
    git

# Apache modüllerini etkinleştir
echo -e "${YELLOW}Apache modülleri etkinleştiriliyor...${NC}"
a2enmod rewrite
a2enmod headers

# MySQL'i güvenli yapılandır
echo -e "${YELLOW}MySQL yapılandırılıyor...${NC}"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';"
mysql -e "FLUSH PRIVILEGES;"

# Drupal için veritabanı oluştur
echo -e "${YELLOW}Drupal veritabanı oluşturuluyor...${NC}"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF
CREATE DATABASE ${DRUPAL_DB_NAME};
CREATE USER '${DRUPAL_DB_USER}'@'localhost' IDENTIFIED BY '${DRUPAL_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DRUPAL_DB_NAME}.* TO '${DRUPAL_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Drupal'ı indir
echo -e "${YELLOW}Drupal indiriliyor...${NC}"
cd /tmp
wget "https://www.drupal.org/download-latest/zip" -O drupal.zip
mkdir -p ${DRUPAL_INSTALL_DIR}
unzip drupal.zip -d /tmp/
DRUPAL_FOLDER=$(find /tmp -maxdepth 1 -type d -name "drupal-*" | head -1)
cp -r ${DRUPAL_FOLDER}/* ${DRUPAL_INSTALL_DIR}/
cp -r ${DRUPAL_FOLDER}/.* ${DRUPAL_INSTALL_DIR}/ 2>/dev/null || true

# Dizin izinlerini ayarla
echo -e "${YELLOW}Dizin izinleri ayarlanıyor...${NC}"
chown -R www-data:www-data ${DRUPAL_INSTALL_DIR}
mkdir -p ${DRUPAL_INSTALL_DIR}/sites/default/files
chown -R www-data:www-data ${DRUPAL_INSTALL_DIR}/sites/default/files
mkdir -p ${DRUPAL_INSTALL_DIR}/sites/default/private
chown -R www-data:www-data ${DRUPAL_INSTALL_DIR}/sites/default/private

# Apache VirtualHost yapılandırması
echo -e "${YELLOW}Apache VirtualHost yapılandırılıyor...${NC}"
cat > /etc/apache2/sites-available/drupal.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot ${DRUPAL_INSTALL_DIR}
    
    <Directory ${DRUPAL_INSTALL_DIR}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/drupal_error.log
    CustomLog \${APACHE_LOG_DIR}/drupal_access.log combined
</VirtualHost>
EOF

a2ensite drupal.conf
a2dissite 000-default.conf
systemctl restart apache2

# PHP ayarlarını optimize et
echo -e "${YELLOW}PHP ayarları optimize ediliyor...${NC}"
PHP_INI=$(php -r "echo php_ini_loaded_file();")
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 128M/' "$PHP_INI"
sed -i 's/post_max_size = .*/post_max_size = 128M/' "$PHP_INI"
sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
sed -i 's/memory_limit = .*/memory_limit = 512M/' "$PHP_INI"

# Drupal Kurulumunu Composer ile yap
echo -e "${YELLOW}Drupal bağımlılıkları kuruluyor...${NC}"
cd ${DRUPAL_INSTALL_DIR}
composer install --no-dev

# Drupal CLI kurulumu
echo -e "${YELLOW}Drupal CLI kuruluyor...${NC}"
wget https://github.com/drush-ops/drush/releases/download/11.x/drush.phar -O /usr/local/bin/drush
chmod +x /usr/local/bin/drush

# Drupal site kurulumu
echo -e "${YELLOW}Drupal site kuruluyor...${NC}"
cd ${DRUPAL_INSTALL_DIR}
drush site:install standard \
    --db-url="mysql://${DRUPAL_DB_USER}:${DRUPAL_DB_PASSWORD}@localhost/${DRUPAL_DB_NAME}" \
    --site-name="${SITE_NAME}" \
    --site-mail="${SITE_EMAIL}" \
    --account-name="${DRUPAL_ADMIN_USER}" \
    --account-pass="${DRUPAL_ADMIN_PASSWORD}" \
    --account-mail="${SITE_EMAIL}" \
    -y

# Servis yapılandırmaları
echo -e "${YELLOW}Servisler yeniden başlatılıyor...${NC}"
systemctl restart mysql
systemctl restart apache2

# Güvenlik duvarı yapılandırması (isteğe bağlı)
echo -e "${YELLOW}Güvenlik duvarı yapılandırılıyor...${NC}"
ufw enable
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp

# Cron job yapılandırması
echo -e "${YELLOW}Cron job ayarlanıyor...${NC}"
echo "0 * * * * cd ${DRUPAL_INSTALL_DIR} && /usr/local/bin/drush cron" | crontab -u www-data -

# SSH anahtarlarını silme
rm -f /root/.ssh/authorized_keys
rm -f /home/ubuntu/.ssh/authorized_keys
rm -f /var/www/html/index.html

# MySQL debian.cnf dosyasından şifreyi silme
sed -i 's/password = .*/password = /' /etc/mysql/debian.cnf

rm -f girdapdp.sh

# Kurulum bilgilerini göster
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}  Drupal kurulumu başarıyla tamamlandı!    ${NC}"
echo -e "${GREEN}===========================================${NC}"
echo -e "${YELLOW}Site Bilgileri:${NC}"
echo -e "URL: http://$(hostname -I | awk '{print $1}')/"
echo -e "Admin Kullanıcı: ${DRUPAL_ADMIN_USER}"
echo -e "Admin Şifre: ${DRUPAL_ADMIN_PASSWORD}"
echo -e "Veritabanı: ${DRUPAL_DB_NAME}"
echo -e "Veritabanı Kullanıcısı: ${DRUPAL_DB_USER}"
echo -e "Veritabanı Şifresi: ${DRUPAL_DB_PASSWORD}"
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}Kurulum tamamlandı! Site kullanıma hazır.${NC}"
