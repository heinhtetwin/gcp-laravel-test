#!/bin/bash
# Install dependencies and configure environment

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install required tools
sudo apt-get install -y ca-certificates apt-transport-https software-properties-common curl gnupg

# Add PHP 8.1 repository
sudo add-apt-repository -y ppa:ondrej/php
sudo add-apt-repository -y ppa:ondrej/nginx-mainline

# Add Node.js 18.x repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# Update package lists
sudo apt-get update -y

# Install PHP 8.1 and extensions
sudo apt-get install -y \
    php8.1 \
    php8.1-fpm \
    php8.1-mysql \
    php8.1-mbstring \
    php8.1-xml \
    php8.1-curl \
    php8.1-zip

# Install Node.js and npm
sudo apt-get install -y nodejs

# Install Nginx and other dependencies
sudo apt-get install -y nginx unzip

# Install Cloud SQL Proxy
wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
chmod +x cloud_sql_proxy

# Configure PHP-FPM
sudo sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/8.1/fpm/php.ini
sudo systemctl restart php8.1-fpm

# Configure Nginx
sudo cat >/etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

# Create sample PHP application
sudo cat >/var/www/html/index.php <<EOF
<?php
try {
    echo "Connected to Cloud SQL successfully!<br>";
    echo "PHP Version: " . phpversion() . "<br>";
    echo "Node.js Version: " . shell_exec('node -v') . "<br>";
    echo "npm Version: " . shell_exec('npm -v') . "<br>";
} catch (PDOException \$e) {
    die("Connection failed: " . \$e->getMessage());
}
?>
EOF

# Set permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Restart services
sudo systemctl restart nginx
sudo systemctl restart php8.1-fpm

# Verify installations
echo "PHP 8.1 version: $(php -v | head -n 1)"
echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"
