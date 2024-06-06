# Vaultwarden installation script

This script will install vaultwarden on a clean debian or rhel based server.

It has been tested on Debian 12

*WARNING:* Running this script on a system with existing data will probably lead to dataloss. Use it at your own risk.

## Usage

You will need git and sudo to be installed.

```bash
sudo apt-get install git sudo
```
or 
```bash
sudo yum install git sudo
```

Then clone the repository and make the script executable:

```bash
git clone https://github.com/Anuril/vwinst.git
cd vwinst
chmod +x vw_installer.sh
```

The Script needs at least 3 arguments:

```bash
sudo ./vw_installer.sh -d postgresql -w "vault.yourdomain.com" -u "vaultuser"
```

It is recommended to run this script as a non-root user with sudo privileges.

Additional arguments:
```bash

Options (required):
 -d, --database <database>       Database type (postgresql or mysql)
 -w, --website <website>         Website url (No protocol) f.ex: vault.mydomain.com
 -u, --localuser <localuser>     Local user name with which to run vaultwarden

Options (optional):
 -r, --reverseproxy <bool>       Set if Vaultwarden is behind a reverse proxy (default: false)
                                 If this is enabled, certbot will be disabled as it is assumed that the reverse proxy takes care of SSL.
 -s, --signupdomain "<domains>"  Comma separated list of domains from which users can sign up
 -e, --enablesends <bool>        Enable/disable sends (default: false)
 -i, --invitations <bool>        Enable/disable invitations (default: false)
 -b, --builddir <path>           Path to build directory (default: /usr/local/src)
 -g, --upgrade <bool>            Upgrade existing installation
 -w, --webversion <version>      Force a specific web version
 -c, --certbot <bool>            Enable/disable certbot (default: false) - not recommended if DNS records don\'t yet point to this host)
 -a, --admininterface <bool>     Enable/disable admin interface (default: true)
 -h, --help                      Display full help text
```

## Example

```bash
./vw_installer.sh -d postgresql -w "vault.yourdomain.com" -u "vaultuser" -c "false" -r "true" -a "true" -e "true" -i "false" -s "yourdomain.com" -f "v2024.5.0"
```

## Security

- The script will create randomized vaultwarden username & passwords for the database.
- The script will create a randomized admin password and hash it with argon2 for vaultwarden.
- Vaultwarden will run as a separate user.
- Vaultwarden will run isolated by using systemd hardening features.

## Disclaimer

- This script is provided as is, without any warranty or guarantee.
- This script assumes a clean install of Debian or RHEL based OS.
- This script is not affiliated with the vaultwarden project.
- This script is not affiliated with the vaultwarden docker image.
- This script is not affiliated with the vaultwarden organization.
- This script is not affiliated with the Bitwarden organization.
- If this script breaks your system, you get to keep both pieces.
- Use this script at your own risk.
- No backup - no mercy.


## Honorable mentions

The script is very heavily inspired by this gist https://gist.github.com/heinoldenhuis/f8164f73e5bff048e76fb4fff2e824e1 by @heinoldenhuis 
which was an update for this https://gist.github.com/tavinus/59c314f4ccd70879db7f11074eacb6cc by @tavinusv 
