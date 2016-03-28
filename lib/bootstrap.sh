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
function :: { echo ":: $@"; }

########################################
:: running generic guest configuration
########################################

# set dns record in hosts file
ip_address=$(ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
printf "\n$ip_address $(hostname)\n" >> /etc/hosts

########################################
:: configuring rpms needed for install
########################################

# enable rpm caching and set higher metadata cache
sed -i 's/keepcache=0/keepcache=1\nmetadata_expire=12h/' /etc/yum.conf

# append exclude rule to avoid updating the yum tool and kernel packages (causes issues with VM Ware tools on re-create)
printf "\n\nexclude=yum kernel*\n" >> /etc/yum.conf

# import gpg keys before installing anything
rpm --import ./etc/keys/RPM-GPG-KEY-CentOS-6.txt
rpm --import ./etc/keys/RPM-GPG-KEY-EPEL-6.txt
rpm --import ./etc/keys/RPM-GPG-KEY-MySql.txt
rpm --import ./etc/keys/RPM-GPG-KEY-remi.txt
rpm --import ./etc/keys/RPM-GPG-KEY-nginx.txt
rpm --import ./etc/keys/RPM-GPG-KEY-Varnish.txt

# install wget since it's not in Digital Ocean base image
yum install -y wget

if [[ ! -d /var/cache/yum/rpms ]]; then
    mkdir -p /var/cache/yum/rpms
fi
pushd /var/cache/yum/rpms

# redirect stderr -> stdin so info is logged
# ignore error codes for offline cache (where file does not exist the following commands should fail on rpm --checksig)
wget --timestamp http://rpms.famillecollet.com/enterprise/remi-release-6.rpm 2>&1 || true
wget --timestamp http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm 2>&1 || true
wget --timestamp https://repo.varnish-cache.org/redhat/varnish-4.1.el6.rpm 2>&1 || true
wget --timestamp http://repo.mysql.com/mysql-community-release-el6-5.noarch.rpm 2>&1 || true

rpm --checksig remi-release-6.rpm
rpm --checksig nginx-release-centos-6-0.el6.ngx.noarch.rpm
rpm --checksig varnish-4.1.el6.rpm
rpm --checksig mysql-community-release-el6-5.noarch.rpm

yum install -y epel-release
yum install -y remi-release-6.rpm
yum install -y nginx-release-centos-6-0.el6.ngx.noarch.rpm
yum install -y varnish-4.1.el6.rpm
yum install -y mysql-community-release-el6-5.noarch.rpm


popd

########################################
:: updating currently installed packages
########################################

yum update -y

########################################
:: installing npm package manager
########################################

yum install -y npm --disableexcludes=all
npm -g config set cache /var/cache/npm

# fix npm install problem by overwriting symlink with copy of linked version
if [[ -L /usr/lib/node_modules/inherits ]]; then
    inherits="$(readlink -f /usr/lib/node_modules/inherits)"
    rm -f /usr/lib/node_modules/inherits
    cp -r "$inherits" /usr/lib/node_modules/inherits
fi

########################################
:: setting zone info to match host zone
########################################

if [[ -f "$HOST_ZONEINFO" ]]; then
    if [[ -f /etc/localtime ]]; then
        mv /etc/localtime /etc/localtime.bak
    elif [[ -L /etc/localtime ]]; then
        rm /etc/localtime
    fi
    ln -s "$HOST_ZONEINFO" /etc/localtime
fi

########################################
:: installing generic guest tooling
########################################

yum install -y bash-completion bc man git rsync mysql

########################################
:: installing configuration into /etc
########################################

rsync -av ./guest/etc/ /etc/
git config --global core.excludesfile /etc/.gitignore_global

service sshd reload     # pickup the new config above rsync drops in place

########################################
:: installing web services
########################################

yum install -y redis sendmail varnish nginx

yum --enablerepo=remi --enablerepo=remi-php70 install -y php-fpm php-cli php-opcache \
    php-mysqlnd php-mhash php-curl php-gd php-intl php-mcrypt php-xsl php-mbstring php-soap php-bcmath php-zip

########################################
:: configuring web services
########################################

adduser --system --user-group --no-create-home www-data
usermod -a -G www-data nginx

perl -pi -e 's/^user = apache/user = www-data/' /etc/php-fpm.d/www.conf
perl -pi -e 's/^group = apache/group = www-data/' /etc/php-fpm.d/www.conf

chkconfig redis on
service redis start

chkconfig varnish on
service varnish start

chkconfig nginx on
service nginx start

chkconfig php-fpm on
service php-fpm start

########################################
:: installing mysqld service
########################################

[ -f ./guest/etc/my.cnf ] && cp ./guest/etc/my.cnf /etc/my.cnf
yum install -y mysql-server

chkconfig mysqld on
service mysqld start 2>&1 # data directory init process is is chatty on stderr

mysql -uroot -e "
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
"

########################################
:: installing develop tools
########################################

# import local env configuration (needed for composer config)
source /etc/profile.d/env.sh

npm install -g grunt-cli

# install composer
wget https://getcomposer.org/download/1.0.0-alpha11/composer.phar -O /usr/local/bin/composer 2>&1
chmod +x /usr/local/bin/composer
composer config -g github-oauth.github.com "$GITHUB_TOKEN"
composer config -g http-basic.repo.magento.com "$MAGENTO_KEY_USER" "$MAGENTO_KEY_PASS"

# install n98-magerun
wget http://files.magerun.net/n98-magerun2-latest.phar -O /usr/local/bin/n98-magerun 2>&1
chmod +x /usr/local/bin/n98-magerun
ln -s /usr/local/bin/n98-magerun /usr/local/bin/mr
