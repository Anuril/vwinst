#!/bin/bash
# Utilities for the Installer script for Vaultwarden 
# Author & Copyright: Christoph Schläpfer <chris+github@cleverly.ch>
# Version: 1.0.0
# Date: 2024-06-06
# License: AGPL3


# Constants
help_string="\n\
Usage: \n \
 ./vw_installer.sh -d <database> -w <website> -u <localuser> [options] \n \n\
\
WARNING: This script will install Vaultwarden on a clean system. \n\
Installing on a system with existing data will probably lead to dataloss. \n\
Use this script at your own risk. \n\n\
Vaultwarden will be installed to /usr/bin/vaultwarden and the web-vault component to /var/lib/vaultwarden/web-vault \n\
The database information and admin token will be displayed at the end of the installation.\n\n\
\
Options (required): \n \
 -d, --database <database> \t\t Database type (postgresql or mariadb) \n \
 -w, --website <website> \t\t Website url (No protocol) f.ex: vault.mydomain.com  \n \
 -u, --localuser <localuser> \t\t Local user name with which to run vaultwarden \n \n\
Options (optional): \n \
 -r, --reverseproxy <bool> \t\t Set if Vaultwarden is behind a reverse proxy (default: false) \n\
 \t\t\t\t\t If this is enabled, certbot will be disabled as it is assumed that the reverse proxy takes care of SSL.\n \
 -s, --signupdomain \"<domains>\"\t\t Comma separated list of domains from which users can sign up \n \
 -e, --enablesends <bool> \t\t Enable/disable sends (default: false) \n \
 -i, --invitations <bool> \t\t Enable/disable invitations (default: false) \n \
 -b, --builddir <path> \t\t\t Path to build directory (default: /usr/local/src) \n \
 -w, --webversion <version> \t\t Force a specific web version \n \
 -c, --certbot <bool>  \t\t\t Enable/disable certbot (default: false) - not recommended if DNS records don't yet point to this host) \n \
 -a, --admininterface <bool> \t\t Enable/disable admin interface (default: true) \n \
 -h, --help \t\t\t\t Display this help text \n \n \
Options (upgrading): \n \
 -g, --upgrade <bool> \t\t\t Upgrade existing installation\n \
 -C, --config <path> \t\t\t Path to configuration file\n\n\
Examples (Installing): \n \
#sudo ./vw_installer.sh -d postgresql -w vault.mydomain.com -u vaultwarden \n   \
- Installs Vaultwarden without sends, invitations and certbot, but with admin interface.\n\n \
#sudo ./vw_installer.sh -d postgresql -w vault.mydomain.com -u vaultwarden -r true -s \"domain.com,site.com\" -e true -i true -a false \n   \
- Installs Vaultwarden with sends, invitations and certbot, but without admin interface. \n   \
- Allows only users with Email adresses from domain.com and site.com to sign up. \n   \
- Assumes that Vaultwarden is behind a reverse proxy.\n\n\
Examples (Upgrading): \n \
#sudo ./vw_installer.sh -g \n   \
- Checks for an existing installation and upgrades it to the latest version. \n   \
- Tries to use the existing configuration file, but you can specify a different one with the -C flag. \n\n \
#sudo ./vw_installer.sh -g -C /etc/vaultwarden/instance1.env\n   \
- Uses the configuration file /etc/vaultwarden/instance1.env for the upgrade.\n\n \
This will upgrade the vaultwarden installation to the latest version. \n \
A backup of the previous vaultwarden binary, config file and database will be in the vw_install_{timestamp} directory in the build path. \n"