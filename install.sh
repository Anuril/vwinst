#!/bin/bash
# Functionality to install Vaultwarden 
# Author & Copyright: Christoph Schläpfer <chris+github@cleverly.ch>
# Version: 1.1.0
# Date: 2024-06-06
# License: AGPL3

function check_required_parameters {
    # Check required parameters
    if [[ -z "$database" ]]; then
        echo "Error: Database type not provided."
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Error: Database type not provided. It is required" >> $logfile
        echo -e "$help_string"
        exit 1
    fi
    # Check if the database type is supported
    if [[ "$database" != "postgresql" ]] && [[ "$database" != "mariadb" ]]; then
        echo "Error: Database type $database is not supported."
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Error: Database type $database is not supported" >> $logfile
        echo -e "$help_string"
        exit 1
    fi
   
    if [[ -z "$website" ]]; then
        echo "Error: Website name is required"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Error: Website name is required" >> $logfile
        echo -e "$help_string"
        exit 1
    fi
   
    if [[ -z "$localuser" ]]; then
        echo "Error: Local user name is required"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Error: Local user name is required" >> $logfile    
        echo -e "$help_string"
        exit 1
    fi
}

function install_dependencies {
    # Install dependencies based on the operating system family
    if [ "$os_family" == "ID=\"centos\"" ] || [ "$os_family" == "ID=\"fedora\"" ] || [ "$os_family" == "ID=\"rocky\"" ] || [ "$os_family" == "ID=\"rhel\"" ]; then
        if [[ "$os_version" < "7" ]]; then
            echo "OS Version not supported: $os_family version $os_version"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> OS Version not supported: $os_family version $os_version" >> $logfile
            exit 1
        fi
        # Use YUM package manager to install dependencies
        dnf config-manager --enable crb
        yum install -y git nano bc curl wget bind-utils pkg-config openssl openssl-devel libXtst-devel glibc-devel epel-release nginx flex-devel libpq-devel 
        yum groupinstall -y "Development Tools"
        
        # Install node 18
        curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
        
        if [[ $certbot = "true" ]]; then
            yum install -y certbot python3-certbot-nginx mod_ssl gnupg2 ca-certificates
        fi
        # create alias for the package manager command to use later
        pkg_mgr="yum install -y"
        $pkg_mgr nodejs
        postgres_pkg="postgresql-server"
    elif [ "$os_family" == "ID=ubuntu" ] || [ "$os_family" == "ID=debian" ]; then
        # if debian version is below 10 or ubuntu version is below 20.04, exit
        if [[ "$os_family" == "ID=debian" && "$os_version" < "10" ]] || [[ "$os_family" == "ID=ubuntu" && "$os_version" < "20.04" ]]; then
            echo "OS Version not supported: $os_family version $os_version"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> OS Version not supported: $os_family version $os_version" >> $logfile
            exit 1
        fi
        # if debian version is below 11, print a warning
        if [ "$os_family" == "ID=debian" ] && [[ "$os_version" < "11" ]]; then
            echo "Warning: Debian version $os_version is not officially supported"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> Warning: Debian version $os_version is not officially supported" >> $logfile
        fi
           
        apt-get update
        apt-get install -y git nano curl wget htop pkg-config openssl libssl-dev build-essential libpq-dev nginx libxtst-dev libc6-dev argon2
        # If apt-get install fails, exit
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install dependencies"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> Error: Failed to install dependencies" >> $logfile
            exit 1
        fi

        if [ "$os_family" == "ID=debian" ] && [[ "$os_version" > "11.00" ]]; then
            apt-get install -y libssl3
        else
            apt-get install -y libssl1.1
        fi
        
        # Install node 18 repository
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - 
        apt-get update
        
        # If vaultwarden is not behind a reverse proxy, install nginx
        if [ $reverseproxy = "true" ]; then
            certbot=false
            echo "$(date '+%Y-%m-%d %H:%M:%S')> Reverse proxy enabled. Disabling certbot" >> $logfile
        fi
        
        if [ $certbot = "true" ]; then
            apt-get install -y certbot python3-certbot-nginx gnupg2 ca-certificates
            # if apt-get install fails, exit
            if [ $? -ne 0 ]; then
                echo "Error: Failed to install certbot"
                echo "$(date '+%Y-%m-%d %H:%M:%S')> Error: Failed to install certbot" >> $logfile
                exit 1
            fi
        fi
        pkg_mgr="apt-get install -y"
        postgres_pkg="postgresql"
        $pkg_mgr nodejs
    else
        # Unknown operating system
        echo "Error: This script currently runs on debian and red hat derived systems. We detected $os_family version $os_version"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Error: This script currently runs on debian and red hat derived systems. We detected $os_family version $os_version" >> $logfile
        exit 1
    fi
}

function create_build_env {
    # Check if the current user has permission to create a directory in /usr/local/source
    echo "Checking permissions in /usr/local/src"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Checking permissions in /usr/local/src" >> $logfile
    if [[ -w "$build_directory" ]]; then
        cd "$build_directory"
        mkdir 'vw_install'
        cd 'vw_install'
        build_path="$build_directory/vw_install"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> User has permissions in /usr/local/src, using $build_path" >> $logfile
    else
        cd $HOME
        mkdir 'vw_install'
        cd 'vw_install'
        build_path="$HOME/vw_install"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> User does not have permissions in /usr/local/src, using $build_path" >> $logfile
    fi
}

function install_rust {
    # Install Rust with rustup
    cd $build_path
    rustpath=$(which rustc)
    if [ -z $rustpath ]; then
        echo "Installing rust with rustup."
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Installing rust with rustup" >> $logfile
        echo "This may take a while..."
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        echo 'export PATH=~/.cargo/bin:$PATH' >> ~/.bashrc
        export PATH=~/.cargo/bin:$PATH
        rustpath=$(which rustc)
        if [ -z $rustpath ]; then
            echo "Installing rust with rustup failed."
            echo "$(date '+%Y-%m-%d %H:%M:%S')> rustc not found in path, maybe the installation with rustup failed" >> $logfile
            exit 1
        fi
    fi
}

function install_nodejs {
    # Install NodeJS
    echo "Installing NodeJS"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Installing NodeJS" >> $logfile

    if [ -z $(npm --version) ]; then
        echo "Installing npm with $pkr_mgr failed."
        echo "$(date '+%Y-%m-%d %H:%M:%S')> npm not found, maybe the installation failed" >> $logfile
        exit 1
    fi
    npm -g install npm@7
    if ! output=$(npm i npm@latest -g); then
        echo "Upgrading npm & dependencies failed."
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Upgrading npm & dependencies failed" >> $logfile
        exit 1
    fi

    # Install Dependencies
    npm install husky

}

function build_vaultwarden {
    echo "Checking if Vaultwarden is already built..."
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Checking if Vaultwarden is already built" >> $logfile

    if [ -f "$build_path/vaultwarden/target/release/vaultwarden" ]; then
        echo "Vaultwarden already built. Continuing from here"
        vaultwarden_path="$build_path/vaultwarden"
    else
        echo "Building Vaultwarden..."
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Building Vaultwarden..." >> $logfile
        git clone https://github.com/dani-garcia/vaultwarden
        cd vaultwarden
        git fetch --tags
        latest_tag=$(git describe --tags `git rev-list --tags --max-count=1`)
        git checkout $latest_tag
        cargo clean && cargo build --features $database --release
        if [ -f "$build_path/vaultwarden/target/release/vaultwarden" ]; then
            echo "Built Vaultwarden successfully"
            vaultwarden_path="$build_path/vaultwarden"
        else
            echo "Building Vaultwarden failed. See errors above."
            exit 1
        fi
    fi
}

function apply_web_patch {
    echo "Download and install web-vault component"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Download and install web-vault component" >> $logfile
    cd "$build_path"
    git clone "https://github.com/dani-garcia/bw_web_builds.git" "vaultpatches"

    # if forcewebversion has a value, use that version
    if [ -n "$forcewebversion" ]; then
        echo "Forcing web version $forcewebversion"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Forcing web version $forcewebversion" >> $logfile
        newest_patch_number=$forcewebversion
        newest_patch_file="$newest_patch_number.patch"
    else
        # if forcewebversion is empty, try to use the latest version
        echo "Checking for the latest patch version"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Checking for the latest patch version" >> $logfile
        cd "vaultpatches/patches"
        latest_v=$(git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' https://github.com/dani-garcia/bw_web_builds | tail --lines=1 | cut --delimiter='/' --fields=3)
        newest_patch_number=${latest_v%\^\{\}}
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Latest patch version is $newest_patch_number" >> $logfile
    fi

    echo "Patch No: $newest_patch_number will be used"

    cd "$build_path"
    wget "https://github.com/dani-garcia/bw_web_builds/releases/download/$newest_patch_number/bw_web_$newest_patch_number.tar.gz"
    tar -xzf "bw_web_$newest_patch_number.tar.gz"

    cp -a web-vault "$vaultwarden_path/target/release/"
}

function install_database {
    # Install database Server
    dbuser="vaultw_$(openssl rand -hex 6)"
    # make the variable dbuser lowercase
    dbuser=$(echo "$dbuser" | tr '[:upper:]' '[:lower:]')
    dbpass="$(openssl rand -hex 24)"
    rootdbpass="vaultw_$(openssl rand -hex 24)"

    if [ $database = 'mariadb' ]; then
        $pkg_mgr mariadb-server default-libmysqlclient-dev
        dbport=3306
        mysql -u root < $build_path/installer/preparemysql.sql
        mysqladmin password "$rootdbpass"
        dbstring="mysql"
    elif [ $database = 'postgresql' ]; then
        dbport=5432
        $pkg_mgr $postgres_pkg
        sudo -u postgres createdb vaultwarden
        sudo -u postgres createuser $dbuser
        sudo -u postgres psql postgres -d vaultwarden -c "GRANT ALL ON SCHEMA public TO $dbuser;"
        sudo -u postgres psql postgres -c "GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO $dbuser;"
        sudo -u postgres psql postgres -c "ALTER USER $dbuser PASSWORD '$dbpass';"
        dbstring="postgresql"
    fi
}

function install_vaultwarden {
    # Check required parameters
    check_required_parameters

    # Install Package dependencies
    install_dependencies

    my_ip=$(curl -s ifconfig.me)

    # Create build environment
    create_build_env

    # Install Rust
    install_rust

    # Install NodeJS
    install_nodejs

    # Install database
    install_database

    # Build & Install Vaultwarden
    build_vaultwarden

    # Apply web patch
    apply_web_patch
    
    # Archive the release and install it
    echo "Archive the release and installing it"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Archive the release and installing it" >> $logfile

    mkdir -p $build_path/releaseversion/$newest_patch_number
    cp -a $vaultwarden_path/target/release/vaultwarden $build_path/releaseversion/$newest_patch_number
    cp -r $vaultwarden_path/target/release/web-vault $build_path/releaseversion/$newest_patch_number

    # Install Vaultwarden
    cp $vaultwarden_path/target/release/vaultwarden /usr/bin/vaultwarden
    chmod +x /usr/bin/vaultwarden
    
    mkdir -p /var/lib/vaultwarden/data
    cp -R $vaultwarden_path/target/release/web-vault /var/lib/vaultwarden/

    # Create service user
    useradd -m -d /var/lib/vaultwarden $localuser

    # Set permissions
    chown -R $localuser:$localuser /var/lib/vaultwarden

    # Prepare the service file
    mkdir "$build_path/installer"
    cp "$inst_dir/installer/vaultwarden.example" "$build_path/installer/vaultwarden.service"
    
    sed -i "s/DBSTRING1/After=network.target $database.service/" "$build_path/installer/vaultwarden.service"
    sed -i "s/DBSTRING2/Requires=$database.service/" "$build_path/installer/vaultwarden.service"
    sed -i "s/LOCALUSERREPL/$localuser/" "$build_path/installer/vaultwarden.service"

    # Install vaultwarden service
    cp "$build_path/installer/vaultwarden.service" /etc/systemd/system/vaultwarden.service
    chmod -x /etc/systemd/system/vaultwarden.service

    # if vaultwarden is not behind a reverse proxy, create the webserver config (if $reverseproxy = false)
    if [ $reverseproxy = "false" ]; then
        cp "$inst_dir/installer/web-config.example" "$build_path/installer/$website.config"
        sed -i "s/bitwarden.mydomain.com/$website/g" "$build_path/installer/$website.config"
        
        cp "$build_path/installer/$website.config" "/etc/nginx/sites-enabled/"
        systemctl restart nginx.service
        if [ $certbot = "true"]; then
            if [ my_ip != $(dig $website +short) ]; then
                echo "Provided Website URL does not resolve to this server."
                echo "Can't continue with let'sencrypt"
                exit 1
            else
                certbot --nginx -d $website
            fi
        fi
       
        connect_domain="https://$website"
        connect_url="https://$website"
        
    else
        # else prepare the connection url string for nginx to provide access to the web-vault running on port 8000
        connect_domain="https://$website"
        connect_url="http://$website"
        cp "$inst_dir/installer/web-config-rp.example" "$build_path/installer/$website.config"
        sed -i "s/bitwarden.mydomain.com/$website/" "$build_path/installer/$website.config"
        cp "$build_path/installer/$website.config" "/etc/nginx/sites-enabled/$website.config"
        rm /etc/nginx/sites-enabled/default
        systemctl restart nginx.service
    fi
    # Create the admin token
    if [ $admininterface = "true" ]; then
        admintoken=$(openssl rand -hex 32)
        secrethash=$(echo -n $admintoken | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)
        # Save the plaintext token to a file in the users home directory
        echo $admintoken > $HOME/vaultwarden_admin_token.txt
        chown $localuser:$localuser $HOME/vaultwarden_admin_token.txt
        chmod 600 $HOME/vaultwarden_admin_token.txt

    fi
   
    # Create Vaultwarden config file:
    cp "$inst_dir/installer/vaultwarden.env.example" "$build_path/installer/vaultwarden.env"
    # create sed search string for the domain
    echo "" >> "$build_path/installer/vaultwarden.env"
    echo "DOMAIN=$connect_domain" >> "$build_path/installer/vaultwarden.env"
    echo "DATABASE_URL=$dbstring://$dbuser:$dbpass@127.0.0.1:$dbport/vaultwarden" >> "$build_path/installer/vaultwarden.env"
    echo "SIGNUPS_DOMAINS_WHITELIST=$signupdomain" >> "$build_path/installer/vaultwarden.env"
    echo "ADMIN_TOKEN=$secrethash" >> "$build_path/installer/vaultwarden.env"
    echo "INVITATIONS_ALLOWED=$invitations" >> "$build_path/installer/vaultwarden.env"
    echo "SENDS_ALLOWED=$enablesends" >> "$build_path/installer/vaultwarden.env"
    secrethash=''
    # Install the config file
    mkdir /etc/vaultwarden
    cp "$build_path/installer/vaultwarden.env" /etc/vaultwarden/vaultwarden.env

    # Start the service
    echo "Starting the services"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Starting services" >> $logfile
    systemctl daemon-reload
    systemctl restart $database.service
    systemctl enable vaultwarden.service --now
    systemctl restart nginx.service
    sleep 20
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Services started" >> $logfile
    # Confirm that Vaultwarden was installed successfully
    echo "Checking if Vaultwarden is running at $connect_url"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Checking if Vaultwarden is running at $connect_url" >> $logfile
    curl $connect_url | grep Vaultwarden > /dev/null
    
    if [ $? -eq 0 ]; then
    echo -e "\
#########################################################################\n\
# \t \t Vaultwarden installed successfully \t \t \t#\n\
# \t \t ================================== \t \t#\n\
#\t \t \t \t \t \t \t \t \t#\n\
#-----------------------------------------------------------------------#\n\
# Access your vault here: $connect_url$(printf -- ' '%.s $(seq -s ' ' $((46-${#connect_url}))))#\n\
#-----------------------------------------------------------------------#\n\
#\t \t \t \t \t \t \t \t \t#\n\
# \t \tPlease note down these important values:\t \t#\n\
# \t \t========================================\t \t#\n\
#\t \t \t \t \t \t \t \t \t#\n\
# Vaultwarden Service: \t \t \t \t \t \t \t#\n\
# * Vaultwarden Service user: $localuser \t \t \t \t#\n\
# * Vaultwarden Binary: /usr/bin/vaultwarden \t \t \t \t#\n\
# * Vaultwarden working directory: /var/lib/vaultwarden \t \t#\n\
#\t \t \t \t \t \t \t \t \t#"
    if [ $admininterface = "true" ]; then
        echo -e "\
# * Vaultwarden Admin password: \t \t \t \t \t#\n\
#   $admintoken \t#"
    fi
    echo -e "\
#\t \t \t \t \t \t \t \t \t#\n\
# ${database^} Database: \t \t \t \t \t \t \t#\n\
# * Database Server root user password: \t \t \t \t#\n\
#   $rootdbpass \t \t#\n\
#\t \t \t \t \t \t \t \t \t#\n\
# * Database name: vaultwarden \t \t \t \t \t \t#\n\
# * Database user: $dbuser \t \t \t \t \t#\n\
# * Database pass: $dbpass \t#"

    echo -e "#\t \t \t \t \t \t \t \t \t#\n\
#########################################################################\n\n\
You might need to restart your server to make sure all services are running correctly."

    admintoken=''
    # Save the installed version to a file
    echo "vw_version=$latest_tag" > $release_file
    echo "bw_version=$newest_patch_number" > $release_file
    else
        echo "Error: Failed to install vaultwarden"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Error: Failed to install vaultwarden" >> $logfile
        admintoken=''
        exit 1
    fi

    
}