#!/bin/bash
# Installer script for Vaultwarden 
# Author & Copyright: Christoph Schläpfer <chris+github@cleverly.ch>
# Version: 1.0.0
# Date: 2023-07-02
# License: GPL3
# Heavily inspired by this GIST https://gist.github.com/heinoldenhuis/f8164f73e5bff048e76fb4fff2e824e1 by Hein Oldenhuis



# Check for the operating system family
os_family=$(cat /etc/*-release | grep '^ID=')
os_version=$(cat /etc/*-release | grep '^VERSION_ID=' | sed "s/VERSION_ID=\"//g" | sed "s/\"//g")
username=$(whoami)
build_directory="/usr/local/src"
inst_dir=$(pwd)
help_string="Usage: \
myscript [-d|--database (mysql, postgresql, sqlite)] \
[-w|--website (FQDN to reach your vault, no protocol)] \
[-r|--reverseproxy (Vaultwarden is behind a reverse proxy)] \
[-s|--signupdomain (Provide a domain which can sign up)] \
[-e|--enablesends (Enable vaultwarden sends)] \
[-i|--invitations (Enable vaultwarden invitations)] \
[-u|--localuser (User to run Vaultwarden with)] \
[-f|--forcewebversion (Force a specific web version)] \
[-c|--certbot (Enable Let's encrypt - not recommended if DNS records don't yet point to this host)] \
[-a|--admininterface (Enable Admininterface)] \
[-h|--help]"

# Set default values
database=""
website=""
localuser=""
certbot=true
reverseproxy=false
admininterface=true
enablesends=false
signupdomain=""
invitations=false
forcewebversion=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d|--database)
            database="$2"
            shift # past argument
            shift # past value
        ;;
        -w|--website)
            website="$2"
            shift # past argument
            shift # past value
        ;;
        -r|--reverseproxy)
            reverseproxy="$2"
            shift # past argument
            shift # past value
        ;;
        -s|--signupdomain)
            signupdomain="$2"
            shift # past argument
            shift # past value
        ;;
        -e|--enablesendsignup)
            enablesends="$2"
            shift # past argument
            shift # past value
        ;;
        -i|--invitations)
            invitations="$2"
            shift # past argument
            shift # past value
        ;;
        -u|--localuser)
            localuser="$2"
            shift # past argument
            shift # past value
        ;;
		-f|--forcewebversion)
			forcewebversion="$2"
			shift # past argument
			shift # past value
		;;
        -c|--certbot)
            certbot="$2"
            shift # past argument
            shift # past value
        ;;
        -a|--admininterface)
            admininterface="$2"
            shift # past argument
            shift # past value
        ;;
        -h|--help)
            echo "Usage: ./script.sh [OPTIONS]"
            echo "Options:"
            echo "  -d, --database DATABASE     Database name (postgresql or mysql)"
            echo "  -w, --website WEBSITE       Website name (No protocol)"
            echo "  -r, --reverseproxy [BOOL]   Enable/disable reverse proxy (default: false)"
            echo "  -s, --signupdomain DOMAIN   Domain which can sign up"
            echo "  -e, --enablesends [BOOL]    Enable/disable sends (default: false)"
            echo "  -i, --invitations [BOOL]    Enable/disable invitations (default: false)"
            echo "  -u, --localuser LOCALUSER   Local user name"
			echo "  -f, --forcewebversion VERSION Force a specific web version"
            echo "  -c, --certbot [BOOL]        Enable/disable certbot (default: true)"
            echo "  -a, --admininterface [BOOL] Enable/disable admin interface (default: true)"
            echo "  -h, --help                  Show help"
            exit 0
        ;;
        *)    # unknown option
            echo "Unknown option: $1"
            exit 1
        ;;
    esac
done

# Check required parameters
if [[ -z $database ]]; then
    echo "Database name is required"
    echo $help_string
    exit 1
fi

if [[ -z $website ]]; then
    echo "Website name is required"
    echo $help_string
    exit 1
fi

if [[ -z $localuser ]]; then
    echo "Local user name is required"
    echo $help_string
    exit 1
fi

# Determine the package manager command to use
if [ "$os_family" == "ID=\"centos\"" ] || [ "$os_family" == "ID=\"fedora\"" ] || [ "$os_family" == "ID=\"rocky\"" ] || [ "$os_family" == "ID=\"rhel\"" ]; then
    if [[ "$os_version" < "7" ]]; then
        echo "OS Version not supported: $os_family version $os_version"
        exit 1
    fi
    # Use YUM package manager to install dependencies
    sudo dnf config-manager --enable crb
    sudo yum install -y git nano bc curl wget bind-utils pkg-config openssl openssl-devel libXtst-devel glibc-devel epel-release nginx flex-devel libpq-devel
    sudo yum groupinstall -y "Development Tools"
    
	# Install node 18
	curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    
    if [ $certbot = "true" ]; then
        sudo yum install -y certbot python3-certbot-nginx mod_ssl gnupg2 ca-certificates
    fi
    pkg_mgr="sudo yum install -y"
    pkg_mgr_name="yum"
	$pkg_mgr "nodejs"
elif [ "$os_family" == "ID=ubuntu" ] || [ "$os_family" == "ID=debian" ]; then
    # Use APT package manager
    sudo apt-get update
    sudo apt-get install -y git nano curl wget htop pkg-config openssl libssl-dev build-essential libpq-dev nginx libxtst-dev libc6-dev
    if [ "$os_family" == "ID=debian" ]; then
	if [[ "$os_version">"11.00" ]]; then
	    sudo apt-get install -y libssl3
	fi
    else
	sudo apt-get install -y libssl1.1
    fi
    
	# Install node 18
	curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - 
	
    # if vaultwarden is not behind a reverse proxy, install nginx
    if [ $reverseproxy = "false" ]; then
        certbot=false
    fi
    
    if [ $certbot = "true" ]; then
        sudo apt-get install -y certbot python3-certbot-nginx gnupg2 ca-certificates
    fi
    pkg_mgr="sudo apt-get install -y"
    pkg_mgr_name="apt"
	$pkg_mgr "nodejs"
else
    # Unknown operating system
    echo "Error: This script currently runs on debian and red hat derived systems. We detected $os_family version $os_version"
    exit 1
fi
my_ip=$(curl -s ifconfig.me)

# Check if the current user has permission to create a directory in /usr/local/source
echo "Checking permissions in /usr/local/src"
if [[ -w "$build_directory" ]]; then
    cd "$build_directory"
    mkdir 'vw_install'
    cd 'vw_install'
    build_path="$build_directory/vw_install"
else
    cd $HOME
    mkdir 'vw_install'
    cd 'vw_install'
    build_path="$HOME/vw_install"
fi

# Install Rust with rustup
cd $build_path
rustpath=$(which rustc)
if [ -z $rustpath ]; then
    echo "Installing rust with rustup."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    echo 'export PATH=~/.cargo/bin:$PATH' >> ~/.bashrc
    export PATH=~/.cargo/bin:$PATH
    rustpath=$(which rustc)
    if [ -z $rustpath ]; then
        echo "Installing rust with rustup failed."
        exit 1
    fi
fi

# Install NodeJS
sudo npm -g install npm@7

if [ -z $(npm --version) ]; then
    echo "Installing npm with $pkr_mgr failed."
    exit 1
fi
if ! output=$(sudo npm i npm@latest -g); then
    echo "Upgrading npm & dependencies failed."
    exit 1
fi
sudo npm install husky


# Build & Install Vaultwarden
echo "Building Vaultwarden..."
echo $(pwd)
if [ -f "$build_path/vaultwarden/target/release/vaultwarden" ]; then
    echo "Vaultwarden already built. Continuing from here"
    vaultwarden_path="$build_path/vaultwarden"
else
    sudo git clone https://github.com/dani-garcia/vaultwarden
    cd vaultwarden
    cargo clean && cargo build --features $database --release
    if [ -f "$build_path/vaultwarden/target/release/vaultwarden" ]; then
        echo "Built Vaultwarden successfully"
        vaultwarden_path="$build_path/vaultwarden"
    else
        echo "Building Vaultwarden failed. See errors above."
        exit 1
    fi
fi


echo "Download and install web-vault component"
echo "Checking for newest Patch"
cd "$build_path"
sudo git clone "https://github.com/dani-garcia/bw_web_builds.git" "vaultpatches"
cd "vaultpatches/patches"

echo $forcewebversion
# if forcewebversion has a value, use that version
if [ $forcewebversion != "" ]; then
	newest_patch_number=$forcewebversion
	newest_patch_file="$newest_patch_number.patch"
else
	# if forcewebversion is empty, try to use the latest version
	latest_v=$(git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' https://github.com/dani-garcia/bw_web_builds | tail --lines=1 | cut --delimiter='/' --fields=3)
	newest_patch_number=latest_v=${latest_v%\^\{\}}

fi



echo "Patch No: $newest_patch_number will be applied"

cd "$build_path"
sudo wget "https://github.com/dani-garcia/bw_web_builds/releases/download/$newest_patch_number/bw_web_$newest_patch_number.tar.gz"
sudo tar -xzf "bw_web_$newest_patch_number.tar.gz"

sudo cp -a web-vault "$vaultwarden_path/target/release/"


sudo cp $vaultwarden_path/target/release/vaultwarden /usr/bin/vaultwarden
sudo chmod +x /usr/bin/vaultwarden
sudo useradd -m -d /var/lib/vaultwarden $localuser
sudo mkdir /var/lib/vaultwarden/data
sudo cp -R $vaultwarden_path/target/release/web-vault /var/lib/vaultwarden/
sudo chown -R $localuser:$localuser /var/lib/vaultwarden

# Install databases
dbuser="vaultw_$(openssl rand -hex 6)"
# make the variable dbuser lowercase
dbuser=$(echo "$dbuser" | tr '[:upper:]' '[:lower:]')
dbpass="$(openssl rand -hex 24)"
rootdbpass="vaultw_$(openssl rand -hex 24)"

if [ $database = 'mysql' ]; then
    $pkg_mgr mariadb-server
    dbport=3306
	sudo mysql -u root <<_EOF_
	DELETE FROM mysql.user WHERE User='';
	DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
	DROP DATABASE IF EXISTS test;
	DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
	CREATE USER '$dbuser'@'%' IDENTIFIED BY '$dbpass';
	CREATE DATABASE vaultwarden;
	USE vaultwarden;
	GRANT ALL PRIVILEGES ON vaultwarden TO '$dbuser'@'%';
	FLUSH PRIVILEGES;
_EOF_
    sudo mysqladmin password "$rootdbpass"
    elif [ $database = 'postgresql' ]; then
    dbport=5432
    if [ $pkg_mgr_name = 'yum' ]; then
        $pkg_mgr postgresql-server
    else
        $pkg_mgr postgresql
    fi
    sudo -u postgres createdb vaultwarden
    sudo -u postgres createuser $dbuser
    sudo -u postgres psql postgres -c "GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO $dbuser;"
    sudo -u postgres psql postgres -c "ALTER USER $dbuser PASSWORD '$dbpass';"
fi
sudo mkdir "$build_path/installer"
sudo cp "$inst_dir/installer/vaultwarden.example" "$build_path/installer/vaultwarden.service"
sed -i "s/DBSTRING1/After=network.target $database.service/" "$build_path/installer/vaultwarden.service"
sed -i "s/DBSTRING2/Requires=$database.service/" "$build_path/installer/vaultwarden.service"
sed -i "s/LOCALUSERREPL/$localuser/" "$build_path/installer/vaultwarden.service"


# Install vaultwarden service
sudo cp "$build_path/installer/vaultwarden.service" /etc/systemd/system/vaultwarden.service
sudo chmod -x /etc/systemd/system/vaultwarden.service
# replace $localuser and $localgroup variables in vaultwarden.service




# if vaultwarden is not behind a reverse proxy, create the webserver config (if $reverseproxy = false)
if [ $reverseproxy = "false" ]; then
    sudo cp "$inst_dir/installer/web-config.example" "$build_path/installer/$website.config"
    sed -i "s/bitwarden.mydomain.com/$website/g" "$build_path/installer/$website.config"
    
    sudo cp "$build_path/installer/$website.config" "/etc/nginx/sites-enabled/"
    sudo systemctl restart nginx.service
    if [ $certbot = "true"]; then
        if [ my_ip != $(dig $website +short) ]; then
            echo "Provided Website URL does not resolve to this server."
            echo "Can't continue with let'sencrypt"
            exit 1
        else
            sudo certbot --nginx -d $website
        fi
    fi
    
    connect_domain="https://$website"
    connect_url="https://$website"
    # else prepare the connection url string
else
    connect_domain="https://$website"
    connect_url="http://$website:8000"
    sudo cp "$inst_dir/installer/web-config-rp.example" "$build_path/installer/$website.config"
    sed -i "s/bitwarden.mydomain.com/$website/" "$build_path/installer/$website.config"
    sudo cp "$build_path/installer/$website.config" "/etc/nginx/sites-enabled/$website.config"
    sudo systemctl restart nginx.service
fi
if [ $admininterface = "true" ]; then
    admintoken=$(openssl rand -hex 64)
fi
# Create Vaultwarden config:
sudo cp "$inst_dir/installer/vaultwarden.env.example" "$build_path/installer/vaultwarden.env"
# create sed search string for the domain
echo "" >> "$build_path/installer/vaultwarden.env"
echo "DOMAIN=$connect_domain" >> "$build_path/installer/vaultwarden.env"
echo "DATABASE_URL=$database://$dbuser:$dbpass@127.0.0.1:$dbport/vaultwarden" >> "$build_path/installer/vaultwarden.env"
echo "SIGNUPS_DOMAINS_WHITELIST=$signupdomain" >> "$build_path/installer/vaultwarden.env"
echo "ADMIN_TOKEN=$admintoken" >> "$build_path/installer/vaultwarden.env"
echo "INVITATIONS_ALLOWED=$invitations" >> "$build_path/installer/vaultwarden.env"
echo "SENDS_ALLOWED=$enablesends" >> "$build_path/installer/vaultwarden.env"
echo "vim: syntax=ini" >> "$build_path/installer/vaultwarden.env"
#admintoken=''
admintokenstring=''
sudo cp "$build_path/installer/vaultwarden.env" /etc/vaultwarden.env
sudo systemctl daemon-reload
sudo systemctl start vaultwarden.service
sudo systemctl enable vaultwarden.service


# Confirm that the software package was installed successfully
if [ $? -eq 0 ]; then
    echo "Success: Software package installed successfully"
else
    echo "Error: Failed to install software package"
    exit 1
fi

echo "###################################################"
echo "#       Vaultwarden installed successfully        #"
echo "###################################################"
echo "# You can now reach your instance under:          #"
echo "~~~ $connect_url ~~~"
echo "# Please note down these important values:        #"
echo "# Database name: vaultwarden                      #"
echo "# Database user: $dbuser                  #"
echo "# Database pass: $dbpass #"
echo "# Service user: $localuser                        #"
if [ $admininterface = "true" ]; then
    echo "# Admin token:                                #"
    echo ""
    echo "$admintoken"
    echo ""
fi
echo "#                                                 #"
echo "###################################################"
echo ""
echo "You might need to restart your server to make sure all services are running correctly."
admintoken=''
