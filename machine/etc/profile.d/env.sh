#!/usr/bin/env bash
##
 # Copyright © 2016 by David Alger. All rights reserved
 # 
 # Licensed under the Open Software License 3.0 (OSL-3.0)
 # See included LICENSE file for full text of OSL-3.0
 # 
 # http://davidalger.com/contact/
 ##

# set magento mode forcefully
export MAGE_MODE=production

# composer global configuration
export COMPOSER_HOME=/var/composer
export COMPOSER_CACHE_DIR=/var/cache/composer
export COMPOSER_NO_INTERACTION=1

export PATH=~/bin:/usr/local/bin:$PATH:/usr/local/sbin
export CLICOLOR=1
