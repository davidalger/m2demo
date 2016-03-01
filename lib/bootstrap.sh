#!/usr/bin/env bash
##
 # Copyright © 2016 by David Alger. All rights reserved
 # 
 # Licensed under the Open Software License 3.0 (OSL-3.0)
 # See included LICENSE file for full text of OSL-3.0
 # 
 # http://davidalger.com/contact/
 ##

set -e
cd /vagrant

export PATH="/usr/local/bin:$PATH"

########################################
# generic machine configuration

# import all our custom conf files
rsync -av ./machine/etc/ /etc/

# set dns record in hosts file
ip_address=$(ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
printf "\n$ip_address $(hostname)\n" >> /etc/hosts

# set zone info to match host if possible
if [[ -f "$HOST_ZONEINFO" ]]; then
    if [[ -f /etc/localtime ]]; then
        mv /etc/localtime /etc/localtime.bak
    elif [[ -L /etc/localtime ]]; then
        rm /etc/localtime
    fi
    ln -s "$HOST_ZONEINFO" /etc/localtime
fi

########################################
# import / configure rpms
yum install -y wget

rpm --import ./etc/keys/RPM-GPG-KEY-CentOS-6.txt
rpm --import ./etc/keys/RPM-GPG-KEY-EPEL-6.txt
rpm --import ./etc/keys/RPM-GPG-KEY-MySql.txt
rpm --import ./etc/keys/RPM-GPG-KEY-remi.txt
rpm --import ./etc/keys/RPM-GPG-KEY-nginx.txt
rpm --import ./etc/keys/RPM-GPG-KEY-Varnish.txt

if [[ ! -d /var/cache/yum/rpms ]]; then
    mkdir -p /var/cache/yum/rpms
fi
pushd /var/cache/yum/rpms

wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm 2>&1
wget http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm 2>&1
wget https://repo.varnish-cache.org/redhat/varnish-4.1.el6.rpm 2>&1
wget http://repo.mysql.com/mysql-community-release-el6-5.noarch.rpm 2>&1

rpm --checksig remi-release-6.rpm
rpm --checksig nginx-release-centos-6-0.el6.ngx.noarch.rpm
rpm --checksig varnish-4.1.el6.rpm
rpm --checksig mysql-community-release-el6-5.noarch.rpm

yum install -y epel-release
yum install -y remi-release-6.rpm
yum install -y nginx-release-centos-6-0.el6.ngx.noarch.rpm
yum install -y varnish-4.1.el6.rpm
yum install -y mysql-community-release-el6-5.noarch.rpm

yum update -y -q

popd

########################################
# configure npm

yum install -y npm --disableexcludes=all
npm -g config set cache /var/cache/npm

# fix npm install problem by overwriting symlink with copy of linked version
if [[ -L /usr/lib/node_modules/inherits ]]; then
    inherits="$(readlink -f /usr/lib/node_modules/inherits)"
    rm -f /usr/lib/node_modules/inherits
    cp -r "$inherits" /usr/lib/node_modules/inherits
fi

########################################
# install and configure tooling

yum install -y bash-completion bc man git redis sendmail varnish nginx httpd mysql mysql-server
npm install -g grunt-cli

# configure mysqld
service mysqld start >> $BOOTSTRAP_LOG 2>&1 # init data directory and access
mysql -uroot -e "
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
"
service mysqld stop >> $BOOTSTRAP_LOG 2>&1 # leave mysqld in stopped state

# configure httpd
perl -pi -e 's/Listen 80//' /etc/httpd/conf/httpd.conf
perl -0777 -pi -e 's#(<Directory "/var/www/html">.*?)AllowOverride None(.*?</Directory>)#$1AllowOverride All$2#s' \
        /etc/httpd/conf/httpd.conf

if [[ -f "/var/www/error/noindex.html" ]]; then
    mv /var/www/error/noindex.html /var/www/error/noindex.html.disabled
fi

# install php and related dependencies
yum --enablerepo=remi --enablerepo=remi-php70 install -y php php-cli php-opcache \
    php-mysqlnd php-mhash php-curl php-gd php-intl php-mcrypt php-xsl php-mbstring php-soap php-bcmath php-zip

# install composer
wget https://getcomposer.org/download/1.0.0-alpha11/composer.phar -O /usr/local/bin/composer 2>&1
chmod +x /usr/local/bin/composer
composer config -g github-oauth.github.com "$GITHUB_TOKEN"
composer config -g http-basic.repo.magento.com "$MAGENTO_KEY_USER" "$MAGENTO_KEY_PASS"

# install n98-magerun
wget http://files.magerun.net/n98-magerun2-latest.phar -O /usr/local/bin/n98-magerun 2>&1
chmod +x /usr/local/bin/n98-magerun
ln -s /usr/local/bin/n98-magerun /usr/local/bin/mr

# install m2setup.sh
wget https://raw.githubusercontent.com/davidalger/devenv/develop/vagrant/bin/m2setup.sh -O /usr/local/bin/m2setup.sh 2>&1
chmod +x /usr/local/bin/m2setup.sh
