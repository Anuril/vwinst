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
 -d, --database <database> \t         Database type (postgresql or mysql) \n \
 -w, --website <website> \t           Website url (No protocol) f.ex: vault.mydomain.com  \n \
 -u, --localuser <localuser> \t       Local user name with which to run vaultwarden \n \n\
Options (optional): \n \
 -r, --reverseproxy <bool> \t         Set if Vaultwarden is behind a reverse proxy (default: false) \n\
 \t\t\t\t                             If this is enabled, certbot will be disabled as it is assumed that the reverse proxy takes care of SSL.\n \
 -s, --signupdomain \"<domains>\"\t   Comma separated list of domains from which users can sign up \n \
 -e, --enablesends <bool> \t          Enable/disable sends (default: false) \n \
 -i, --invitations <bool> \t          Enable/disable invitations (default: false) \n \
 -b, --builddir <path> \t\t           Path to build directory (default: /usr/local/src) \n \
 -w, --webversion <version> \t        Force a specific web version \n \
 -c, --certbot <bool>  \t\t           Enable/disable certbot (default: false) - not recommended if DNS records don't yet point to this host) \n \
 -a, --admininterface <bool> \t       Enable/disable admin interface (default: true) \n \
 -h, --help \t\t\t                     Display this help text \n \n \n\
Options (upgrading): \n \
 -g, --upgrade <bool> \t\t            Upgrade existing installation\n \
 -C, --config <path> \t\t             Path to configuration file\n\n \
Examples: \n \
user@server:~\$ ./vw_installer.sh -d postgresql -w vault.mydomain.com -u vaultwarden \n  \
- Installs Vaultwarden without sends, invitations and certbot, but with admin interface.\n\n \
user@server:~\$ ./vw_installer.sh -d postgresql -w vault.mydomain.com -u vaultwarden -r true -s \"domain.com,site.com\" -e true -i true -a false \n  \
- Installs Vaultwarden with sends, invitations and certbot, but without admin interface. \n \
- Allows only users with Email adresses from domain.com and site.com to sign up. \n \
- Assumes that Vaultwarden is behind a reverse proxy.\n\n\
Upgrading: \n \
If you want to upgrade an existing installation, you can run the script with the -g flag. \n\n \
user@server:~\$ ./vw_installer.sh -g \n\n \

This will upgrade the vaultwarden installation to the latest version. \n \
A backup of the previous vaultwarden binary, config file and database will be in the users home directory. \n"