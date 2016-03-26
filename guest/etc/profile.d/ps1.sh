#!/usr/bin/env bash
##
 # Copyright © 2016 by David Alger. All rights reserved
 # 
 # Licensed under the Open Software License 3.0 (OSL-3.0)
 # See included LICENSE file for full text of OSL-3.0
 # 
 # http://davidalger.com/contact/
 ##

########################################
# configure a pretty ps1

## don't customize ps1 for non-bash shell
if [[ -z $BASH_VERSION ]]; then
    return;
fi

export PS1='\[\033[0;36m\]\u@\h\[\033[0m\]:\@:\[\033[0;37m\]\w\[\033[0m\]$ '
