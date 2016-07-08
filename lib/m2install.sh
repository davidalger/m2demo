#!/usr/bin/env bash
##
 # Copyright © 2016 by David Alger. All rights reserved
 # 
 # Licensed under the Open Software License 3.0 (OSL-3.0)
 # See included LICENSE file for full text of OSL-3.0
 # 
 # http://davidalger.com/contact/
 ##

set -eu

# run command, logging and buffering filtered output by line (for immediate bubble up)
function logrun {
    echo "++ $@" >> /var/log/m2install.log
    "$@" \
       > >(tee -a /var/log/m2install.log | stdbuf -oL grep -E '^::') \
      2> >(tee -a /var/log/m2install.log | stdbuf -oL grep -vE -f /vagrant/etc/filters/m2install >&2)
}

function :: { echo ":: $@" | tee -a /var/log/m2install.log; }

# will fail script if these required vars are unbound when run
echo $DEMO_HOSTNAME > /dev/null
echo $IS_ENTERPRISE > /dev/null

install_dir=/var/www/magento2
db_name=magento2

base_url="http://$DEMO_HOSTNAME"
base_url_secure="https://$DEMO_HOSTNAME"
backend_frontname=backend

admin_user=admin
admin_email=demouser@example.com
admin_first=Demo
admin_last=User
admin_pass="$(openssl rand -base64 12)" # Note: It's possible this will ocassionally fail install due to lack of number
admin_url="$base_url/$backend_frontname/admin"  # TODO: update after secure urls are enabled

########################################
:: deploying meta-packages

mkdir -p $install_dir
cd $install_dir

if [[ $IS_ENTERPRISE ]]; then
    package_name="magento/project-enterprise-edition"
else
    package_name="magento/project-community-edition"
fi

logrun composer create-project --no-interaction --prefer-dist --repository-url=https://repo.magento.com $package_name ./

########################################
:: deploying sampledata meta-packages

# point the composer_home Magento CLI tool uses at globally configured home
ln -s $COMPOSER_HOME var/composer_home
logrun mr sampledata:deploy

########################################
:: installing application

mysql -e "create database $db_name"
logrun mr setup:install                         \
    --base-url=$base_url                        \
    --base-url-secure=$base_url_secure          \
    --backend-frontname=$backend_frontname      \
    --use-rewrites=1                            \
    --admin-user=$admin_user                    \
    --admin-firstname=$admin_first              \
    --admin-lastname=$admin_last                \
    --admin-email=$admin_email                  \
    --admin-password="$admin_pass"              \
    --db-host=localhost                         \
    --db-user=root                              \
    --db-name=$db_name                          \
    --magento-init-params='MAGE_MODE=production'\
;
    # TODO: included these flags once ssl support is added
    #--use-secure=1                              \
    #--use-secure-admin=1                        \

########################################
:: compiling dependency injection

rm -rf var/di/ var/generation/
logrun mr setup:di:compile-multi-tenant

########################################
:: generating static content

logrun mr setup:static-content:deploy

########################################
:: running magento indexers

logrun mr indexer:reindex

########################################
:: setting magento system configuration

mr -q config:set system/full_page_cache/caching_application 2
mr -q config:set system/full_page_cache/ttl 604800
mr -q config:set system/full_page_cache/varnish/access_list localhost
mr -q config:set system/full_page_cache/varnish/backend_host localhost
mr -q config:set system/full_page_cache/varnish/backend_port 8080

########################################
:: flushing magento cache

mr -q cache:flush

########################################
:: setting file permissions and ownership

find $install_dir -type d -exec chmod 770 {} +
find $install_dir -type f -exec chmod 660 {} +

chmod -R g+s $install_dir
chown -R www-data:www-data $install_dir

chmod +x $install_dir/bin/magento

########################################
:: configuring crontab worker

crontab -u www-data <(echo '* * * * * /var/www/magento2/bin/magento cron:run >> /var/www/magento2/var/log/cron.log')

########################################
:: demo site information

function print_install_info {
        # note: in CentOS bash .* isn't supported (is on Darwin), but *.* is more cross-platform
    local header="+ %*.*s + %*.*s + \n"
    local infoln="+ %-*s + %-*s + \n"
    
    local fill_str=$(printf "%0.s-" {1..128})
    local c1_len=8
    local c2_len=0

    let "c2_len=${#admin_url}>${#admin_pass}?${#admin_url}:${#admin_pass}"

    printf "$header" 0 $c1_len $fill_str 0 $c2_len $fill_str
    printf "$infoln" $c1_len FrontURL $c2_len "$base_url"
    
    printf "$header" 0 $c1_len $fill_str 0 $c2_len $fill_str
    printf "$infoln" $c1_len AdminURL $c2_len "$admin_url"
    
    printf "$header" 0 $c1_len $fill_str 0 $c2_len $fill_str
    printf "$infoln" $c1_len Username $c2_len "$admin_user"
    
    printf "$header" 0 $c1_len $fill_str 0 $c2_len $fill_str
    printf "$infoln" $c1_len Password $c2_len "$admin_pass"
    
    printf "$header" 0 $c1_len $fill_str 0 $c2_len $fill_str
    printf "\n"
}; print_install_info
