#!/bin/bash
# This script must be run as root (ex.: sudo sh [script_name])

# exit when any command fails
set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command failed with exit code $?."' EXIT

# Helper functions
function echo_title {
    echo ""
    echo "###############################################################################"
    echo "$1"
    echo "###############################################################################"
}

function echo_action {
    echo ""
    echo "ACTION - $1 "
}

function echo_info {
    echo "INFO   - $1"
}

function echo_error {
    echo "ERROR  - $1"
}

###############################################################################
echo_title "Starting $0 on $(date)."
###############################################################################

###############################################################################
echo_title 'Process input parameters.'
###############################################################################
echo_action 'Initializing expected parameters array...'
declare -A parameters=( [dataDiskSize]= \
                        [dataDiskMountPointPath]= \
                        [dbServerAdminPassword]= \
                        [dbServerAdminUsername]= \
                        [dbServerFqdn]= \
                        [dbServerMatomoDbName]= \
                        [dbServerMatomoPassword]= \
                        [dbServerMatomoUsername]= \
                        [dbServerName]= \
                        [smtpServerFqdn]= \
                        [smtpServerPrivateIp]=)
sortedParameterList=$(echo ${!parameters[@]} | tr " " "\n" | sort | tr "\n" " ");
echo_info "Done."

echo_action "Mapping input parameter values and checking for extra parameters..."
while [[ ${#@} -gt 0 ]];
do
    key=$1
    value=$2

    ## Test if the parameter key start with "-" and if the parameter key (without the first dash) is in the expected parameter list.
    if [[ ${key} =~ ^-.*$ && ${parameters[${key:1}]+_} ]]; then
        parameters[${key:1}]="$value"
    else
        echo_error "Unexpected parameter: $key"
        extraParameterFlag=true;
    fi

    # Move to the next key/value pair or up to the end of the parameter list.
    shift $(( 2 < ${#@} ? 2 : ${#@} ))
done
echo_info "Done."

echo_action "Checking for missing parameters..."
for p in $sortedParameterList; do
    if [[ -z ${parameters[$p]} ]]; then
        echo_error "Missing parameter: $p."
        missingParameterFlag=true;
    fi
done
echo_info "Done."

# Abort if missing or extra parameters.
if [[ $extraParameterFlag == "true" || $missingParameterFlag == "true" ]]; then
    echo_error "Execution aborted due to missing or extra parameters."
    usage="USAGE: $(basename $0)"
    for p in $sortedParameterList; do
        usage="${usage} -${p} \$${p}"
    done
    echo_error "${usage}";
    exit 1;
fi

echo_action 'Printing input parameter values for debugging purposes...'
for p in $sortedParameterList; do
    echo_info "$p = \"${parameters[$p]}\""
done
echo_info "Done."

###############################################################################
echo_title "Set internal parameters."
###############################################################################
echo_action "Setting useful variables..."
apache2DefaultDocumentRootDirPath="/var/www/html"
apache2ConfEnabledSecurityFilePath="/etc/apache2/conf-enabled/security.conf"
apache2SitesEnabledDefaultFilePath="/etc/apache2/sites-enabled/000-default.conf"
apache2User="www-data"
hostsFilePath="/etc/hosts"
installDirPath="$(pwd)"
matomoDocumentRootDirPath="${parameters[dataDiskMountPointPath]}/matomo"
phpIniFilePath="/etc/php/7.2/apache2/php.ini"
echo_info "Done."

###############################################################################
echo_title "Upgrade server."
###############################################################################
echo_action "Updating server package index files before the upgrade..."
apt-get update
echo_info "Done."

echo_action "Upgrading all installed server packages to their latest version and apply available security patches..."
apt-get upgrade -y
echo_info "Done."

###############################################################################
echo_title "Mount Matomo File System Disk."
###############################################################################
echo_action 'Retrieving the data disk block path using the data disk size as index...'
dataDiskBlockPath=/dev/$(lsblk --noheadings --output name,size | awk "{if (\$2 == \"${parameters[dataDiskSize]}\") print \$1}")
echo_info "Data disk block path found: $dataDiskBlockPath"
echo_info "Done."

echo_action 'Creating a file system in the data disk block if none exists...'
dataDiskFileSystemType=$(lsblk --noheadings --output fstype $dataDiskBlockPath)
if [ -z $dataDiskFileSystemType ]; then
    echo_info "No file system detected on $dataDiskBlockPath."
    dataDiskFileSystemType=ext4
    echo_action "Creating file system of type $dataDiskFileSystemType on $dataDiskBlockPath..."
    mkfs.$dataDiskFileSystemType $dataDiskBlockPath
    echo_info "Done."
else
    echo_info "Skipped: File system $dataDiskFileSystemType already exist on $dataDiskBlockPath."
fi

echo_action 'Retrieving data disk file System UUID...'
# Bug Fix:  Experience demonstrated that the UUID of the new file system is not immediately 
#           available through lsblk, thus we wait and loop for up to 60 seconds to get it.
elapsedTime=0
dataDiskFileSystemUuid=""
while [ -z "$dataDiskFileSystemUuid" -a "$elapsedTime" -lt "60" ]; do
    echo_info "Waiting for 1 second..."
    sleep 1
    dataDiskFileSystemUuid=$(lsblk --noheadings --output UUID ${dataDiskBlockPath})
    ((elapsedTime+=1))
done
echo_info "Data disk file system UUID: $dataDiskFileSystemUuid"
echo_info "Done."

echo_action "Creating Matomo File System mount point..."
mkdir -p ${parameters[dataDiskMountPointPath]}
echo_info "${parameters[dataDiskMountPointPath]} directory created."
echo_info "Done."

fstabFilePath=/etc/fstab
echo_action "Updating $fstabFilePath file to automount the data disk using its UUID..."
if ! grep -q "$dataDiskFileSystemUuid" $fstabFilePath; then
    printf "UUID=${dataDiskFileSystemUuid}\t${parameters[dataDiskMountPointPath]}\t${dataDiskFileSystemType}\tdefaults,nofail\t0\t2\n" >> $fstabFilePath
    echo_info "Done."
else
    echo_info "Skipped: already set up."
fi

echo_action 'Mounting all drives...'
mount -a
echo_info "Done."

###############################################################################
echo_title "Download and extract Matomo files."
###############################################################################
# Ref.: https://builds.matomo.org/
if [ -d ${moodleDocumentRootDirPath} ]; then
    echo_action "Matomo already installed. Skipping."
else
    echo_action "Downloading Matomo 3.11 tar file..."
    wget https://builds.matomo.org/matomo-3.11.0.tar.gz
    echo_info "Done."

    echo_action "Extracting Matomo tar file..."
    tar zxf matomo-3.11.0.tar.gz -C ${parameters[dataDiskMountPointPath]}
    echo_info "Done."
fi

###############################################################################
echo_title "Install tools."
###############################################################################
echo_action "Installing mysql-client..."
apt-get install --yes --quiet mysql-client-5.7
echo_info "Done."

###############################################################################
echo_title "Install Matomo dependencies."
###############################################################################
echo_action "Installing apache2 packages..."
apt-get install --yes --quiet apache2 libapache2-mod-php
echo_info "Done."

echo_action "Installing php packages..."
apt-get install --yes --quiet php-cli php-mysql php-xml php-mbstring php-json php-gd

echo_info "Done."

###############################################################################
echo_title "Clean up server."
###############################################################################
echo_action "Removing server packages that are no longer needed."
apt-get autoremove -y
echo_info "Done."

###############################################################################
echo_title "Setup SMTP Relay."
###############################################################################
echo_action "Adding SMTP Relay Private IP address in ${hostsFilePath}..."
if ! grep -q "${parameters[smtpServerFqdn]}" $hostsFilePath; then
    echo -e "\n# Redirect SMTP Server FQDN to Private IP Address.\n${parameters[smtpServerPrivateIp]}\t${parameters[smtpServerFqdn]}" >> $hostsFilePath
    echo_info "Done."
else
    echo_info "Skipped: ${hostsFilePath} file already set up."
fi

###############################################################################
echo_title "Update PHP config."
###############################################################################
echo_action "Updating upload_max_filesize and post_max_size settings in ${phpIniFilePath}..."
sed -i "s/upload_max_filesize.*/upload_max_filesize = 2048M/" $phpIniFilePath
sed -i "s/post_max_size.*/post_max_size = 2048M/" $phpIniFilePath
echo_info "Done."

###############################################################################
echo_title "Update Apache config."
###############################################################################
echo_action "Updating Apache default site DocumentRoot property in ${apache2SitesEnabledDefaultFilePath}..."
if ! grep -q "${matomoDocumentRootDirPath}" $apache2SitesEnabledDefaultFilePath; then
    escapedApache2DefaultDocumentRootDirPath=$(sed -E 's/(\/)/\\\1/g' <<< ${apache2DefaultDocumentRootDirPath})
    escapedMatomoDocumentRootDirPath=$(sed -E 's/(\/)/\\\1/g' <<< ${matomoDocumentRootDirPath})
    sed -i -E "s/DocumentRoot[[:space:]]*${escapedApache2DefaultDocumentRootDirPath}/DocumentRoot ${escapedMatomoDocumentRootDirPath}/g" $apache2SitesEnabledDefaultFilePath
    echo_info "Done."
else
    echo_info "Skipped. DocumentRoot already properly set."
fi

echo_action "Updating Apache ServerSignature and ServerToken directives in ${apache2ConfEnabledSecurityFilePath}..."
sed -i "s/^ServerTokens[[:space:]]*\(Full\|OS\|Minimal\|Minor\|Major\|Prod\)$/ServerTokens Prod/" $apache2ConfEnabledSecurityFilePath
sed -i "s/^ServerSignature[[:space:]]*\(On\|Off\|EMail\)$/ServerSignature Off/" $apache2ConfEnabledSecurityFilePath
echo_info "Done."

echo_action 'Setting permissions ...'
chown -R ${apache2User}:root ${matomoDocumentRootDirPath}
chmod -R 775 ${matomoDocumentRootDirPath}
echo_info "Done."

echo_action "Restarting Apache2..."
service apache2 restart
echo_info "Done."

###############################################################################
echo_title "Create Matomo database user if not existing."
###############################################################################
echo_action "Saving database connection parameters to file..."
mysqlConnectionFilePath=${workingDir}/mysql.connection
touch ${mysqlConnectionFilePath}
chmod 600 ${mysqlConnectionFilePath}
cat <<EOF > ${mysqlConnectionFilePath}
[client]
host=${parameters[dbServerFqdn]}
user=${parameters[dbServerAdminUsername]}@${parameters[dbServerName]}
password="${parameters[dbServerAdminPassword]}"
EOF
echo_info "Done."

echo_action "Creating and granting privileges to database user ${parameters[dbServerMatomoUsername]}..."
mysql --defaults-extra-file=${mysqlConnectionFilePath} <<EOF
DROP USER IF EXISTS "${parameters[dbServerMatomoUsername]}";
CREATE USER "{parameters[dbServerMatomoUsername]}" IDENTIFIED BY '${parameters[dbServerMatomoPassword]}';
GRANT ALL PRIVILEGES ON ${parameters[dbServerMatomoDbName]}.* TO ${parameters[dbServerMatomoUsername]};
FLUSH PRIVILEGES;
exit
EOF
echo_info "Done."

###############################################################################
echo_title "Matomo Post installation process."
###############################################################################

# echo_action "Setting up Moodle Crontab..."
# crontabEntry="* * * * * sudo -u ${apache2User} php ${moodleDocumentRootDirPath}/admin/cli/cron.php > /dev/null"
# if [ -z "$(crontab -l | grep --fixed-strings "$crontabEntry")" ]; then
#     crontab -l | { cat; echo "$crontabEntry"; } | crontab -
#     echo_info "Done."
# else
#     echo_info "Skipped: crontab already set up."
# fi

###############################################################################
echo_title "Finishing $0 on $(date)."
###############################################################################
trap - EXIT