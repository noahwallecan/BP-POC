#! /bin/bash

function set_netwerk {
  # IP ROUTE
  ip route add 192.168.0.0/24 via 192.168.0.5 dev enp0s8
  # DNS
  echo "nameserver 8.8.8.8
  nameserver 192.168.0.1" > /etc/resolv.conf
  # IP ADRES
  echo "GATEWAY=192.168.0.5" >> /etc/sysconfig/network-scripts/ifcfg-enp0s8
  # NO SSH ROOT & USER LOGIN
  sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
  sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
  systemctl restart sshd
}

function install_prereq {
  sudo dnf install -y wget
  sudo dnf install -y unzip
  sudo dnf install -y vim
  sudo dnf install php php-mysqlnd php-json php-curl -y
  sudo yum install epel-release -y 
  #sudo yum install certbot -y
  sudo yum install git -y
  #sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
  #sudo dnf install docker-ce -y
  #sudo systemctl start docker
}

function install_postgresql {
  sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
  sudo yum install -y postgresql-server
  sudo dnf install -y postgresql-contrib
  sudo /usr/bin/postgresql-setup --initdb
  sudo systemctl enable postgresql
  sudo systemctl start postgresql
  # Configure Postgres
  sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
    # ident -> md5 ipv4
  sed -i "s?host    all             all             127.0.0.1/32            ident?host    all             all             127.0.0.1/32            md5?g" /var/lib/pgsql/data/pg_hba.conf
  # ident -> md5 ipv6
  sed -i "s?host    all             all             ::1/128                 ident?host    all             all             ::1/128                 md5?g" /var/lib/pgsql/data/pg_hba.conf
  sudo systemctl restart postgresql
}

function install_nginx {
  sudo yum install -y nginx > /dev/null 2>&1
  # Herstart de service
  sudo systemctl enable nginx.service > /dev/null 2>&1
  sudo systemctl restart nginx.service
  # Firewall ...
  sudo systemctl restart firewalld
  sudo systemctl enable firewalld > /dev/null 2>&1
  sudo firewall-cmd --add-service=http --permanent > /dev/null 2>&1
  sudo firewall-cmd --add-service=https --permanent > /dev/null 2>&1
  sudo firewall-cmd --add-port=3000/tcp --permanent > /dev/null 2>&1
  sudo setsebool -P httpd_can_network_connect 1
  sudo firewall-cmd --reload
}

function gen_certif {
  if [ ! -d /etc/ssl/private ]
  then
    sudo mkdir /etc/ssl/private
    sudo chmod 700 /etc/ssl/private
    #sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/theoracle-selfsigned.key -out /etc/ssl/certs/theoracle-selfsigned.crt -subj '/CN=bap.local'
    #sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    sudo openssl genrsa -out /etc/ssl/private/ca-key.pem 4096
    sudo openssl req -new -x509 -sha256 -days 365 -key /etc/ssl/private/ca-key.pem -out /etc/ssl/ca.pem -subj "/C=BE/ST=./L=. /O=./OU=./CN=bap.local/emailAddress=noah.wallecan@student.hogent.be"
    sudo openssl genrsa -out /etc/ssl/private/cert-key.pem 4096
    sudo openssl req -new -sha256 -subj "/C=BE/ST=./L=. /O=./OU=./CN=bap.local/emailAddress=noah.wallecan@student.hogent.be" -key /etc/ssl/private/cert-key.pem -out /etc/ssl/private/cert.csr
    echo "subjectAltName=DNS:www.bap.local,IP:192.168.0.2" >> /etc/ssl/extfile.cnf
    sudo openssl x509 -req -sha256 -days 365 -in /etc/ssl/private/cert.csr -CA /etc/ssl/ca.pem -CAkey /etc/ssl/private/ca-key.pem -out /etc/ssl/certs/cert.pem -extfile /etc/ssl/extfile.cnf -CAcreateserial

  fi
}

function install_mariadb {
  sudo dnf install mariadb-server mariadb -y > /dev/null 2>&1
  sudo systemctl start mariadb
  sudo systemctl enable mariadb > /dev/null 2>&1
  # database config
  mysql -u root -e "create database IF NOT EXISTS wordpressdb";
  mysql -u root -e "CREATE USER IF NOT EXISTS 'wordpressuser'@'localhost' identified by 'wordpresspassword'";
  mysql -u root -e "GRANT ALL PRIVILEGES ON wordpressdb.* TO 'wordpressuser'@'localhost';"
  mysql -u root -e "FLUSH PRIVILEGES;"
}

function install_wordpress {
  if [ ! -d /var/www/wordpress/ ]
  then
    sudo mkdir -p /var/www/
    sudo wget https://wordpress.org/latest.zip > /dev/null 2>&1
    sudo unzip latest.zip -d /var/www/ > /dev/null 2>&1
  fi
  sudo touch /etc/nginx/conf.d/wordpress.conf
  # Wordpress config
  if [ ! -f /var/www/wordpress/wp-config.php ]
  then
    sudo cp /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php
    sed -i 's/database_name_here/wordpressdb/g' /var/www/wordpress/wp-config.php
    sed -i 's/username_here/wordpressuser/g' /var/www/wordpress/wp-config.php
    sed -i 's/password_here/wordpresspassword/g' /var/www/wordpress/wp-config.php
    sudo chown -R nginx:nginx /var/www/wordpress/* > /dev/null 2>&1
    sudo chmod -R 775 /var/www/wordpress/* > /dev/null 2>&1
  fi
  # Nginx config
  echo '# Redirect HTTP -> HTTPS
server {
    server_tokens off;
    listen 80;
    server_name www.bap.local bap.local;

    return 301 https://bap.local$request_uri;
}

server {
    server_tokens off;
    listen 443 ssl http2;
    server_name bap.local www.bap.local;

    root /var/www/wordpress/;
    index index.php;

    # SSL parameters
    ssl_certificate /etc/ssl/certs/cert.pem;
    ssl_certificate_key /etc/ssl/private/cert-key.pem;

    # log files
    access_log /var/log/nginx/bap.local.access.log;
    error_log /var/log/nginx/bap.local.error.log;

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index   index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }
}' > /etc/nginx/conf.d/wordpress.conf
  sed -i 's/apache/nginx/g' /etc/php-fpm.d/www.conf
  sed -i 's/nginx,nginx/apache,nginx/g' /etc/php-fpm.d/www.conf
  sed -i 's/nobody/nginx/g' /etc/php-fpm.d/www.conf

  sudo systemctl restart nginx
  sudo systemctl restart php-fpm
}

function install_rallly {
  if [ ! -d /home/vagrant/rallly ]
  then
    # Install Yarn
    curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | sudo tee /etc/yum.repos.d/yarn.repo > /dev/null 2>&1
    sudo dnf install yarn -y > /dev/null 2>&1
    # Pull Rallly repo
    git clone https://github.com/lukevella/rallly.git --branch v2.8.2 > /dev/null 2>&1
    echo fs.inotify.max_user_watches=524288 >> /etc/sysctl.conf
  fi
  # Configure Rally
  cd rallly/
  cp sample.env .env
  sed -i 's?DATABASE_URL=postgres://your-database/db?DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/postgres?g' .env
  sed -i "s/SECRET_PASSWORD=minimum-32-characters/SECRET_PASSWORD=IyzcLUqZAWiQweD8RxKiRPT7JHlMa5+0XuJ4FdVVvRU=/g" .env
  sudo yarn > /dev/null 2>&1
  # sudo systemctl restart docker
  #sudo docker compose up -d
  # Configuring NGINX for Rallly
  sudo touch /etc/nginx/conf.d/rallly.conf
  echo '
server {
    server_tokens off;
    listen 80;
    server_name www.rallly.bap.local rallly.bap.local;

    return 301 https://rallly.bap.local$request_uri;
}

server {
    server_tokens off;
    listen 443 ssl http2;
    server_name rallly.bap.local www.rallly.bap.local;
    
    location / {
      proxy_pass http://127.0.0.1:3000;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # SSL parameters
    ssl_certificate /etc/ssl/certs/cert.pem;
    ssl_certificate_key /etc/ssl/private/cert-key.pem;

}' > /etc/nginx/conf.d/rallly.conf

  systemctl restart nginx
  yarn db:generate > /dev/null 2>&1 && yarn db:reset -f > /dev/null 2>&1
  yarn build > /dev/null 2>&1
  yarn start
}


echo "Changing network settings"
set_netwerk

echo "Installing prereq"
install_prereq > /dev/null 2>&1

echo "Installing postgresql"
install_postgresql > /dev/null 2>&1

echo "Installing nginx"
install_nginx

echo "Generating self signed certificate"
#if [ ! -f /etc/nginx/snippets/letsencrypt.conf ]
# then
gen_certif > /dev/null 2>&1
#fi

echo "Installing mariadb"
install_mariadb

echo "Installing wordpress"
install_wordpress

echo "Installing rallly"
install_rallly


# na NAT uittrekken en bridged ingestoken:
# sudo systemctl start NetworkManager.service