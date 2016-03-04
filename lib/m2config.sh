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

if [[ -z "$INSTALL_DIR" ]]; then
    echo "Error: env var INSTALL_DIR is missing!"
    exit -1
fi

echo 'Initializing software configuration'

cd $INSTALL_DIR
mr -q config:set system/full_page_cache/caching_application 2
mr -q config:set system/full_page_cache/ttl 604800
mr -q config:set system/full_page_cache/varnish/access_list localhost
mr -q config:set system/full_page_cache/varnish/backend_host localhost
mr -q config:set system/full_page_cache/varnish/backend_port 8080
mr -q cache:flush

echo 'Disabling secure URLs (currently no ssl support in vm)'
mr -q config:set web/secure/use_in_frontend 0
mr -q config:set web/secure/use_in_adminhtml 0
mr -q cache:flush

echo 'Setting file permissions and ownership'

find $INSTALL_DIR -type d -exec chmod 770 {} +
find $INSTALL_DIR -type f -exec chmod 660 {} +

chmod -R g+s $INSTALL_DIR
chown -R apache:nginx $INSTALL_DIR

chmod +x $INSTALL_DIR/bin/magento

echo 'Linking public directory into webroot'
rmdir /var/www/html
ln -s $INSTALL_DIR/pub /var/www/html
ln -s $INSTALL_DIR/pub $INSTALL_DIR/pub/pub     # todo: remove temp fix when GH Issue #2711 is resolved
