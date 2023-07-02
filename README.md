# Vaultwarden installation script

This script will install vaultwarden on a fresh debian or rhel based server.

It has been tested on Debian 11 & Rocky Linux 9.

The script is very heavily inspired by this gist https://gist.github.com/heinoldenhuis/f8164f73e5bff048e76fb4fff2e824e1 
by Hein Oldenhuis


## Usage

```bash
git clone https://github.com/Anuril/vwinst.git
cd vwinst
chmod +x vw_installer.sh
```

The Script needs at least 3 arguments:

```bash
./vw_installer.sh -d postgresql -w "vault.yourdomain.com" -u "vaultuser"
```

Additional arguments:

```bash
-d, --database DATABASE     Database name (postgresql or mysql)
-w, --website WEBSITE       Website name (No protocol)
-r, --reverseproxy [BOOL]   Configure nginx to run behind a reverse proxy (default: false, will request a certificate with certbot)
-s, --signupdomain DOMAIN   Domain which can sign up
-e, --enablesends [BOOL]    Enable/disable sends (default: false)
-i, --invitations [BOOL]    Enable/disable invitations (default: false)
-u, --localuser LOCALUSER   Local user name
-f, --forcewebversion VERSION Force a specific web version (default: latest) Might be necessary if the current version fails.
-c, --certbot [BOOL]        Enable/disable certbot (default: true)
-a, --admininterface [BOOL] Enable/disable admin interface (default: true)
-h, --help                  Show help"
```

## Example

```bash
./vw_installer.sh -d postgresql -w "vault.yourdomain.com" -u "vaultuser" -c "false" -r "true" -a "true" -e "true" -i "false" -s "yourdomain.com" -f "v2023.5.0"
```

## Security

- The script will create randomized vaultwarden username & passwords for the database.
- The script will create a randomized admin password for vaultwarden.
- The script will require you to specify a user that vaultwarden will run as.

## Disclaimer

- This script is provided as is, without any warranty or guarantee.
- This script assumes a clean install of Debian or RHEL based OS.
- This script is not affiliated with the vaultwarden project.
- This script is not affiliated with the vaultwarden docker image.