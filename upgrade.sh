#!/bin/bash
# Functionality to install Vaultwarden 
# Author & Copyright: Christoph Schläpfer <chris+github@cleverly.ch>
# Version: 1.0.0
# Date: 2024-06-06
# License: AGPL3

function parse_config
{
    # Parse the configuration file
    if [ -f $1 ]; then
        echo "TODO"
    else
        echo "Configuration file not found"
        exit 1
    fi
}

function upgrade_vaultwarden {
    parse_config $1
}