#!/usr/bin/env bash
##
 # Copyright © 2016 by David Alger. All rights reserved
 # 
 # Licensed under the Open Software License 3.0 (OSL-3.0)
 # See included LICENSE file for full text of OSL-3.0
 # 
 # http://davidalger.com/contact/
 ##

# set magento developer mode env vars
export MAGE_IS_DEVELOPER_MODE=0
export MAGE_MODE=production

# set central composer home
export COMPOSER_HOME=/vagrant/etc/composer

# configure PATH to use local and user scripts
export PATH=~/bin:/usr/local/bin:$PATH:/usr/local/sbin

# enbale color-ls emulation
export CLICOLOR=1

# setup rvm if present
[ -s "$HOME/.rvm/scripts/rvm" ] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

# git completion
[ -f ~/.git-completion.bash ] && . ~/.git-completion.bash

# command history searching
bind '"\e[A":history-search-backward'
bind '"\e[B":history-search-forward'
