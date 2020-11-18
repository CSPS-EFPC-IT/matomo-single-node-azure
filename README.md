# matomo-single-node-azure
Provisions Azure resources required to run Matomo using a single Web server and PaaS database.

# Description
This project deploys the following Azure resources:
- Virtual Network and its Subnets
- Network Security Groups
- Application Gateway and its Public IP
- Virtual Machine and its OS/Data Disks and Network Card
- Mysql Database
- Recovery Service Vault and its Daily Backup Policy and Protected Item (VM backup)
- Bastion and its Public IP

And installs the following software (up to their latest available patch level for the linux distro) on the virtual machine:
- Ubuntu 18.04
- Mysql client 5.7
- Apache2 2.4
- PHP-CLI 7.2
- PHP 7.2 modules
  - php7.2-gd
  - php7.2-json
  - php7.2-mbstring
  - php7.2-mysql
  - php7.2-xml
- libmaxminddb

# Prerequisites
## Tools
1. An Azure Client (a.k.a. "az cli")
1. A Git client
1. A text editor

## Azure Ressources
1. An Azure subscription.
1. A target resource group.
1. A Key Vault with a properly signed SSL/TLS Certificate for the new moodle instance.
1. A User Assigned Managed Identity (UAMI).

## Azure Permissions
1. Permission to manage (CRUD) resources in the target resource group.
1. GET permission on the Key Vault Secrets granted to the User Assigned Managed Identity. This will allow the Application Gateway to retrieve the SSL/TLS certificate private key from the Key Vault using the UAMI .

## Other Dependencies
1. Optional - An SMTP server.
1. Optional - A custom domain name for the new moodle instance.

# Usage
1. Clone this projet.
1. Create a new file named *armTemplates/azureDeploy.parameters.json* based on the *armTemplates/azureDeploy.parameters.example.json* file.
1. Edit the new _azureDeploy.parameters.json_ file to your liking.
1. Authenticate your Azure Client to your Azure subscription by running the `az login` command and following the instructions.
1. Adapt and run the following commands (on linux):\
`deploymentName="MoodleManualDeployment"`\
`resourceGroupName="[Your resource Group name]"`\
`templateFile="armTemplate/azureDeploy.json"`\
`parameterFile="armTemplates/azureDeploy.parameters.json"`\
`az deployment group create --name $deploymentName --resource-group $resourceGroupName --template-file $templateFile --parameter @$parameterFile --verbose`

# Useful References
- The database setup by this project enforces TLS/SSL connections. See [HOW DO I SETUP MATOMO TO SECURELY CONNECT TO THE DATABASE USING MYSQL SSL?](https://matomo.org/faq/how-to-install/faq_26273/) for details about how to finalize Matomo installation. Once the initial setup is completed, add the following lines to your [matomo installation folder]/config/config.ini.php:
```
; Database SSL Options START
; Turn on or off SSL connection to database, possible values for enable_ssl: 1 or 0
enable_ssl = 1
; Direct path to server CA file, CA bundle supported (required for ssl connection)
ssl_ca =
; Direct path to client cert file (optional)
ssl_cert =
; Direct path to client key file (optional)
ssl_key =
; Direct path to CA cert files directory (optional)
ssl_ca_path = /etc/ssl/certs
; List of one or more ciphers for SSL encryption, in OpenSSL format (optional)
ssl_cipher =
; Whether to skip verification of self signed certificates (optional, only supported
; w/ specific PHP versions, and is mostly for testing purposes)
ssl_no_verify =
; Database SSL Options END
```

Enjoy!