#!/bin/bash
# Functionality to install Vaultwarden 
# Author & Copyright: Christoph Schläpfer <chris+github@cleverly.ch>
# Version: 1.0.0
# Date: 2024-06-06
# License: AGPL3

function check_build_env
{
    # Check if the current user has permission to create a directory in /usr/local/source
    echo "Checking build environment /usr/local/src"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Checking permissions in /usr/local/src" >> $logfile
    if [[ -w "$build_directory" ]]; then
        cd "$build_directory"
        # check if the directory exists - and if yes, move it to a backup
        if [ -d "vw_install" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S')> Backing up existing build environment" >> $logfile
            versionstr=$(date '+%Y%m%d%H%M%S')
            mv "vw_install" "vw_install_$versionstr"
            previous_build="$build_directory/vw_install_$versionstr"

        fi
        mkdir 'vw_install'
        cd 'vw_install'
        build_path="$build_directory/vw_install"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> User has permissions in /usr/local/src, using $build_path" >> $logfile
    else
        cd $HOME
        if [ -d "vw_install" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S')> Backing up existing build environment" >> $logfile
            mv "vw_install" "vw_install_$(date '+%Y%m%d%H%M%S')"
        fi
        mkdir 'vw_install'
        cd 'vw_install'
        build_path="$HOME/vw_install"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> User does not have permissions in /usr/local/src, using $build_path" >> $logfile
    fi
}


function parse_config
{
    # Parse the configuration file
    if [ -f $1 ]; then
        # Make a copy of the configuration file
        cp $1 $1.bak_$(date '+%Y%m%d%H%M%S')

        # Extract the DATABASE_URL
        DATABASE_URL=$(grep -oP '(?<=^DATABASE_URL=)[^\r\n]*' $1 | tr -d '\r')

        # Parse the components
        DB_TYPE=$(echo "$DATABASE_URL" | awk -F: '{print $1}')
        DB_USER=$(echo "$DATABASE_URL" | awk -F[/:@] '{print $4}')
        DB_PASSWORD=$(echo "$DATABASE_URL" | awk -F[/:@] '{print $5}')
        DB_HOST=$(echo "$DATABASE_URL" | awk -F[/:@] '{print $6}')
        DB_PORT=$(echo "$DATABASE_URL" | awk -F[/:@] '{print $7}')
        DB_NAME=$(echo "$DATABASE_URL" | awk -F[/:@] '{print $8}')

        # Read the website URL from the configuration file
        website=$(grep BASE_URL $1 | awk -F= '{print $2}')

        # use the database type to determine the database client tool to use for backup
        case $DB_TYPE in
            "mysql")
                db_client="mysqldump"
                dbstring="mysql"
                ;;
            "postgresql")
                db_client="pg_dump"
                dbstring="postgresql"
                ;;
            *)
                echo "Unsupported database type: $DB_TYPE"
                echo "$(date '+%Y-%m-%d %H:%M:%S')> Unsupported database type: $DB_TYPE" >> $logfile
                exit 1
                ;;
        esac

        # Check if the database client tool is installed
        echo "Found database type: $DB_TYPE"
        echo "Checking if database client tool $db_client is installed"
        if ! command -v $db_client &> /dev/null; then
            echo "Database client tool $db_client not found"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> Database client tool $db_client not found" >> $logfile
            exit 1
        fi

        # Check if the systemd service exists
        service_name="vaultwarden.service"
        if systemctl list-unit-files | grep -q "^$service_name"; then
            echo "The $service_name service exists."
            if systemctl is-active --quiet $service_name; then
                echo "$(date '+%Y-%m-%d %H:%M:%S')> The $service_name service is running, stopping and masking it" >> $logfile
                systemctl stop $service_name
                systemctl mask $service_name
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S')> The $service_name service exists, but is not running. Masking it." >> $logfile
                systemctl mask $service_name

            fi
            # Find the unit file location
            unit_file=$(systemctl show "$service_name" --property=FragmentPath | cut -d= -f2)
            if [ -n "$unit_file" ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S')> Systemd unit file location: $unit_file" >> $logfile
                # Find the user the service is running as
                localuser=$(grep User $unit_file | awk -F= '{print $2}'| tr -d '\r')
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S')> Unit file not found for $service_name." >> $logfile
            fi
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S')> The $service_name service does not exist." >> $logfile
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Configuration file not found" >> $logfile
        echo "Configuration file not found, aborting..."
        exit 1
    fi
}

function backup_database 
{
    # Backup the database
    echo "Backing up the database"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Backing up the database" >> $logfile
    case $DB_TYPE in
        "mysql")
            echo "Backing up MySQL database"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> Backing up MySQL database" >> $logfile
            $db_client -u $DB_USER -p$DB_PASSWORD -h $DB_HOST -P $DB_PORT $DB_NAME > "$previous_build/$DB_NAME-$versionstr".sql
            ;;
        "postgresql")
            echo "Backing up PostgreSQL database"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> Backing up PostgreSQL database" >> $logfile
            export PGPASSWORD=$DB_PASSWORD
            $db_client -U $DB_USER -h $DB_HOST -p $DB_PORT -d $DB_NAME > "$previous_build/$DB_NAME-$versionstr".sql
            ;;
        *)
            echo "Unsupported database type: $DB_TYPE"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> Unsupported database type: $DB_TYPE" >> $logfile
            exit 1
            ;;
    esac
}

function upgrade_vaultwarden {
    parse_config $1
    # Update dependencies 
    install_dependencies
    my_ip=$(curl -s ifconfig.me)

    # Check if there is a previous build environment
    check_build_env

    # Upgrade rust
    install_rust

    # Upgrade nodejs
    install_npm_w_deps

    # backup database
    backup_database

    # build vaultwarden
    build_vaultwarden

    # Apply web patch
    apply_web_patch

    # Archive the release and install it
    echo "Archive the release and installing it"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Archive the release and installing it" >> $logfile

    mkdir -p $build_path/releaseversion/$newest_patch_number
    cp -a $vaultwarden_path/target/release/vaultwarden $build_path/releaseversion/$newest_patch_number
    cp -r $vaultwarden_path/target/release/web-vault $build_path/releaseversion/$newest_patch_number

    # Archive the previous binaries and web-vault 
    # Check if the previous build environment contains a releaseversion directory
    if [ -d $previous_build/releaseversion ]; then
        echo "Archiving the previous release"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Archiving the previous release" >> $logfile
        mkdir -p $previous_build/releaseversion/vaultwarden.binary
    fi
    cp -a /usr/bin/vaultwarden $previous_build/releaseversion/vaultwarden.binary
    cp -r /var/lib/vaultwarden/web-vault $previous_build/releaseversion/web-vault

    # Install Vaultwarden
    cp $vaultwarden_path/target/release/vaultwarden /usr/bin/vaultwarden
    chmod +x /usr/bin/vaultwarden
    
    mkdir -p /var/lib/vaultwarden/data

    cp -R $vaultwarden_path/target/release/web-vault /var/lib/vaultwarden/

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

    # check if $1 is /etc/vaultwarden/vaultwarden.env, if no, copy it to /etc/vaultwarden/vaultwarden.env
    if [ "$1" != "/etc/vaultwarden/vaultwarden.env" ]; then
        mkdir /etc/vaultwarden
        # remove carriage returns and empty lines from older versions of this script
        sed -e 's/\r$//' -e '/^$/d' "$1" > /etc/vaultwarden/vaultwarden.env
        
        # remove the old configuration file
        rm $1
    else
        # remove carriage returns and empty lines from older versions of this script
        sed -e 's/\r$//' -e '/^$/d' "$1" > /etc/vaultwarden/vaultwarden.env.cleaned
        mv /etc/vaultwarden/vaultwarden.env.cleaned /etc/vaultwarden/vaultwarden.env
    fi
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
# \t \t Vaultwarden updated successfully \t \t \t#\n\
# \t \t ================================== \t \t#\n\
#\t \t \t \t \t \t \t \t \t#\n\
#-----------------------------------------------------------------------#\n\
# Access your vault here: $connect_url$(printf -- ' '%.s $(seq -s ' ' $((46-${#connect_url}))))#\n\
#-----------------------------------------------------------------------#\n\
#\t \t \t \t \t \t \t \t \t#"

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