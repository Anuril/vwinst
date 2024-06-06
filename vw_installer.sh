#!/bin/bash
# Installer script for Vaultwarden 
# Author & Copyright: Christoph Schläpfer <chris+github@cleverly.ch>
# Version: 1.0.0
# Date: 2023-07-02
# License: AGPL3
# Heavily inspired by this GIST https://gist.github.com/heinoldenhuis/f8164f73e5bff048e76fb4fff2e824e1 by Hein Oldenhuis

# Source the utilities script
source utils.sh
source install.sh
source upgrade.sh
# Check for the operating system family
os_family=$(cat /etc/*-release | grep '^ID=')
os_version=$(cat /etc/*-release | grep '^VERSION_ID=' | sed "s/VERSION_ID=\"//g" | sed "s/\"//g")
username="$SUDO_USER"
script_user=$(id -un $UID)
logfile="$inst_dir/install.log"
inst_dir=$(pwd)
my_ip=$(curl -s ifconfig.me)

if [ "$(id -u)" -eq 0 ]; then
    if [ $(ps -o comm= -p $(ps -o ppid= -p $$)) = "sudo" ]; then
        # Log the command line arguments
        echo "$(date '+%Y-%m-%d %H:%M:%S')> User $username running Vaultwarden installer with this command:" >> $logfile
        echo "# $0 $@" >> $logfile
        echo "$(date '+%Y-%m-%d %H:%M:%S')> OS Family: $os_family, OS Version: $os_version" >> $logfile
    else
        # Running as root and not via sudo
        echo "This script should be run as a non-root user with sudo privileges"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> This script should be run as a non-root user with sudo privileges" >> $logfile
        exit 1
    fi
else
    # Not running as root
    echo "Please run this script with sudo privileges"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Please run this script with sudo privileges" >> $logfile
    exit 1
fi

# Set default values
database=""
website=""
localuser=""
certbot=false
reverseproxy=false
admininterface=true
enablesends=false
upgrade=false
build_directory="/usr/local/src"
signupdomain=""
invitations=false
forcewebversion=""
config_file=''


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
        -g|--upgrade)
            upgrade="$2"
            shift # past argument
            shift # past value
        ;;
        -C|--config)
            config_file="$2"
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
        -b|--builddir)
            build_directory="$2"
            shift # past argument
            shift # past value
        ;;
        -h|--help)
            echo -e $help_string
            exit 0
        ;;
        *)    # unknown option
            echo "Unknown option: $1"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> Unknown option: $1" >> $logfile
            exit 1
        ;;
    esac
done


if $upgrade; then
    # Check current instance config
    echo "Checking for current instance configuration"
    echo "$(date '+%Y-%m-%d %H:%M:%S')> Checking for current instance configuration" >> $logfile
    #if config_file is set, use that, otherwise check the default location
    if [[ -n $config_file ]]; then
        echo "Using config file $config_file"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Using config file $config_file" >> $logfile
        upgrade_vaultwarden $config_file
    elif [[ -f /etc/vaultwarden/vaultwarden.env ]]; then
        echo "Current instance found"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> Current instance configuration found." >> $logfile
        upgrade_vaultwarden "/etc/vaultwarden/vaultwarden.env"
    else
        echo "No current instance found"
        echo "$(date '+%Y-%m-%d %H:%M:%S')> No current instance found" >> $logfile
        # Ask the user to provide the path to vaultwarden.env file
        echo "Please provide the path to the vaultwarden.env file"
        read -p "Path to vaultwarden.env file: " env_file
        if [[ -f $env_file ]]; then
            echo "File found"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> File found" >> $logfile
            upgrade_vaultwarden $env_file
        else
            echo "File not found"
            echo "$(date '+%Y-%m-%d %H:%M:%S')> File not found" >> $logfile
            # Ask if the user wants to install a new instance instead
            echo "Do you want to install a new instance instead?"
            read -p "Yes/No: " new_instance
            if [[ $new_instance == "Yes" || $new_instance == "yes" ]]; then
                install_vaultwarden
            else
                echo "Exiting"
                echo "$(date '+%Y-%m-%d %H:%M:%S')> Exiting" >> $logfile
                exit 0
            fi
        fi
    fi
else
    # Run the installation
    install_vaultwarden
fi

