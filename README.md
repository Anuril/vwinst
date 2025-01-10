[![Forks](https://img.shields.io/github/forks/anuril/vwinst.svg?style=flat-square&logo=github&logoColor=fff&color=005AA4)](https://github.com/anuril/vwinst/network/members)
[![Stars](https://img.shields.io/github/stars/anuril/vwinst.svg?style=flat-square&logo=github&logoColor=fff&color=005AA4)](https://github.com/anuril/vwinst/stargazers)
[![Issues Open](https://img.shields.io/github/issues/anuril/vwinst.svg?style=flat-square&logo=github&logoColor=fff&color=005AA4&cacheSeconds=300)](https://github.com/anuril/vwinst/issues)
[![Issues Closed](https://img.shields.io/github/issues-closed/anuril/vwinst.svg?style=flat-square&logo=github&logoColor=fff&color=005AA4&cacheSeconds=300)](https://github.com/anuril/vwinst/issues?q=is%3Aissue+is%3Aclosed)[![GitHub Discussions](https://img.shields.io/github/discussions/anuril/vwinst?style=flat-square&logo=github&logoColor=fff&color=953B00&cacheSeconds=300)](https://github.com/anuril/vwinst/discussions)
[![AGPL-3.0 Licensed](https://img.shields.io/github/license/anuril/vwinst.svg?style=flat-square&logo=vaultwarden&color=944000&cacheSeconds=14400)](https://github.com/anuril/vwinst/blob/main/LICENSE)
# Vaultwarden installation script

This script will install vaultwarden on a clean debian or rhel based server.

It has been tested on Debian 12

> [!IMPORTANT]
> **When using this installation script, please report any bugs or suggestions directly to us (see [Discussions](https://github.com/anuril/vwinst/discussions) or [Issues](https://github.com/anuril/vwinst/issues)) - DO NOT use the official Bitwarden support channels, and do not bother the vaultwarden team!**


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

> [!IMPORTANT]
 **WARNING:** Running this script on a system with existing data will potentially lead to dataloss. Make backups and use it at your own risk.

The Script needs at least 3 arguments:

```bash
sudo ./vw_installer.sh -d postgresql -w "vault.yourdomain.com" -u "vaultuser"
```

It is recommended to run this script as a non-root user with sudo privileges.

Additional arguments: (Excerpt from the help text, use -h to see the full help text)
```

Options (required):
  -d, --database <database>              Database type (postgresql or mariadb)
  -w, --website <website>                Website url (No protocol) f.ex: vault.mydomain.com
  -u, --localuser <localuser>            Local user name with which to run vaultwarden

Options (optional):
  -r, --reverseproxy <bool>              Set if Vaultwarden is behind a reverse proxy (default: false)
                                         If this is enabled, certbot will be disabled as it is assumed that the reverse proxy takes care of SSL.
  -s, --signupdomain "<domains>"                 Comma separated list of domains from which users can sign up
  -e, --enablesends <bool>               Enable/disable sends (default: false)
  -i, --invitations <bool>               Enable/disable invitations (default: false)
  -b, --builddir <path>                          Path to build directory (default: /usr/local/src)
  -w, --webversion <version>             Force a specific web version
  -c, --certbot <bool>                           Enable/disable certbot (default: false) - not recommended if DNS records don't yet point to this host)
  -a, --admininterface <bool>            Enable/disable admin interface (default: true)
  -h, --help                             Display this help text

Options (upgrading):
  -g, --upgrade <bool>                   Upgrade existing installation
  -C, --config <path>                    Path to configuration file
```

## Example (Installing)

```bash
 sudo ./vw_installer.sh -d postgresql -w vault.mydomain.com -u vaultwarden
```
   - Installs Vaultwarden without sends, invitations and certbot, but with admin interface.
```bash
 sudo ./vw_installer.sh -d postgresql -w vault.mydomain.com -u vaultwarden -r true -s "domain.com,site.com" -e true -i true -a false
 ```
   - Installs Vaultwarden with sends, invitations and certbot, but without admin interface.
   - Allows only users with Email adresses from domain.com and site.com to sign up.
   - Assumes that Vaultwarden is behind a reverse proxy.

## Examples (Upgrading):

### Make sure to backup your data before upgrading.

```bash
 sudo ./vw_installer.sh -g
```
   - Checks for an existing installation and upgrades it to the latest version.
   - Tries to use the existing configuration file, but you can specify a different one with the C flag.

## Example (Upgrading)

```bash
sudo ./vw_installer.sh -g -C /etc/vaultwarden/instance1.env

```
- Uses the configuration file /etc/vaultwarden/instance1.env for the upgrade.

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

## Upgrading

### Make sure to backup your data before upgrading.

You can upgrade vaultwarden by running the script with the -g flag. This will download the latest version of vaultwarden and install it.
The previous build will be renamed to vw_install_timestamp and the new build will be installed in the default location.
The script will also backup the database, configuration files and binaries before upgrading the installation.

- "If this script breaks your system, you get to keep both pieces." still applies.
- The upgrade script might make some assumptions about the existing installation which might not be true in your case, so please backup your data before upgrading.
- Here are some of the assumptions:
  - The vaultwarden installation has been done with this script or a previous version of it.
  - No other services are running on the server.
  - It's ok to update all dependencies to the latest version. (This might break other services)
  - Your web setup is working. (The script will not check if the web setup is working before upgrading)


## Honorable mentions

The script is very heavily inspired by this gist https://gist.github.com/heinoldenhuis/f8164f73e5bff048e76fb4fff2e824e1 by @heinoldenhuis 
which was an update for this https://gist.github.com/tavinus/59c314f4ccd70879db7f11074eacb6cc by @tavinusv 
