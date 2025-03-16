#!/bin/bash
# Install dependencies and configure environment

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# Update system and install prerequisites
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo apt-get install -y ca-certificates apt-transport-https software-properties-common curl gnupg

# Add Node.js 18.x repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# Update package lists
sudo apt-get update -y

# Install PHP 8.1 and extensions
sudo apt-get install -y lsb-release
sudo curl -sSL https://packages.sury.org/php/apt.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/php.gpg
sudo echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
sudo apt-get update -y
sudo apt-get install -y php8.1 php8.1-cli php8.1-fpm php8.1-common php8.1-mysql php8.1-mbstring php8.1-xml php8.1-zip php8.1-curl

# Verify PHP installation
echo "PHP version: $(php -v | head -n 1)"

# Install Composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
sudo chmod +x /usr/local/bin/composer

# Verify Composer
echo "Composer version: $(composer --version)"

# Install Node.js and npm
sudo apt-get install -y nodejs

# Install Nginx and other dependencies
sudo apt-get install -y nginx unzip

# Configure PHP-FPM
sudo sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/8.1/fpm/php.ini
sudo systemctl restart php8.1-fpm

# Set permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Restart services
sudo systemctl restart nginx
sudo systemctl restart php8.1-fpm
