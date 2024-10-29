#!/bin/bash
#
# Implements a library of MySQL related functions.
# Usage
#   Add the following two lines to your script before using any function:
#     source [path to logger.sh]
#     source [path to mysql.sh]
# Style Guide
#   https://google.github.io/styleguide/shellguide.html

# Constants
readonly MYSQL_USER_OPTIONS_FILE_PATH="${HOME}/.my.cnf"

# Functions

#######################################
# Create a MySQL database and credentials from passed arguments.
# The database and credentials are created if not existing.
# The credential's password is set/reset in all cases.
# Arguments:
#   The database server FQDN, a string.
#   The database administrator's username, a string.
#   The database administrator's password, a string.
#   The new database credentials username, a string.
#   The new database credentials password, a string.
#   The new database name, a string. Default to the new credentials username if not spectifed.
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::create_database_and_credentials() {

  # Parameters
  local database_server_fqdn="$1"
  local database_server_admin_username="$2"
  local database_server_admin_password="$3"
  local database_server_new_credentials_username="$4"
  local database_server_new_credentials_password="$5"
  local database_server_new_credentials_database="${6:-${database_server_new_credentials_username}}"

  mysql::create_user_options_file \
    "${database_server_admin_username}" \
    "${database_server_admin_password}" \
    "${database_server_fqdn}" \
    "3306" \
    "mysql"

  mysql::create_database_if_not_exists \
    "${database_server_new_credentials_database}"

  mysql::create_user_if_not_exists \
    "${database_server_new_credentials_username}" \
    "${database_server_new_credentials_password}"

  mysql::set_user_password \
    "${database_server_new_credentials_username}" \
    "${database_server_new_credentials_password}"

  mysql::grant_all_privileges \
    "${database_server_new_credentials_database}" \
    "${database_server_new_credentials_username}"

  mysql::delete_user_options_file
}

#######################################
# Create a MySQL database using passed arguments.
# Does nothing if the database already exists.
# Requires a valid MySQL options file in the current user's home directory.
# Arguments:
#   database: the name of the database to create
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::create_database_if_not_exists() {
  local database="$1"

  logger::info "Creating MySQL database if not existing..."
  logger::debug "$(mysql --execute "WARNINGS; CREATE DATABASE IF NOT EXISTS \`${database}\`;")"
}

#######################################
# Create a MySQL user using passed arguments.
# Requires a valid MySQL options file in the current user's home directory.
# Arguments:
#   username: the user's username to create
#   password: the user's password
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::create_user_if_not_exists() {
  local username="$1"
  local password="$2"

  logger::info "Creating MySQL database user if not existing..."
  logger::debug "$(mysql --execute "WARNINGS; CREATE USER IF NOT EXISTS \`${username}\` IDENTIFIED BY '${password}';")"
}

#######################################
# Create a MySQL options file in the curreny user's home directory.
# Sets [client] section options with passed arguments.
# Overwrites existing option file, if any.
# Globals:
#   MYSQL_USER_OPTIONS_FILE_PATH
# Arguments:
#   username: the MySQL user's usename
#   password: the MySQL user's password
#   host: the database server host name
#   port: the database server port number
#   database: the name of the user's default database
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::create_user_options_file() {
  local username="$1"
  local password="$2"
  local host="$3"
  local port="$4"
  local database="$5"

  logger::info "Creating MySQL options file: ${MYSQL_USER_OPTIONS_FILE_PATH}..."
  if [[ -f "${MYSQL_USER_OPTIONS_FILE_PATH}" ]]; then
    logger::warn "File already exists. Overwriting content."
  else
    touch "${MYSQL_USER_OPTIONS_FILE_PATH}"
  fi
  chmod 600 "${MYSQL_USER_OPTIONS_FILE_PATH}"
  cat <<EOF > "${MYSQL_USER_OPTIONS_FILE_PATH}"
[client]
host=${host}
port=${port}
user=${username}
password=${password}
database=${database}
EOF
}

#######################################
# Delete the current user's MySQL options file.
# Globals:
#   MYSQL_USER_OPTIONS_FILE_PATH
# Arguments:
#   None
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::delete_user_options_file() {

  logger::info "Deleting MySQL options file: ${MYSQL_USER_OPTIONS_FILE_PATH}..."
  if [[ -f "${MYSQL_USER_OPTIONS_FILE_PATH}" ]]; then
    rm -f "${MYSQL_USER_OPTIONS_FILE_PATH}"
  else
    logger::warn "MySQL options file not found."
  fi
}

#######################################
# Grant all privileges on MySQL database to a user using passed arguments.
# Requires a valid MySQL options file in the current user's home directory.
# Arguments:
#   database: the database that is the object of the grant
#   username: the username that should be granted privileges
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::grant_all_privileges() {
  local database="$1"
  local username="$2"

  logger::info "Granting all privileges on MySQL database objects to user..."
  logger::debug "$(mysql --execute "WARNINGS; GRANT ALL PRIVILEGES ON \`${database}\`.* TO \`${username}\`;")"
}

#######################################
# Set a MySQL user's password.
# Requires a valid MySQL options file in the current user's home directory.
# Arguments:
#   username: the user's username to create
#   password: the user's password
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::set_user_password() {
  local username="$1"
  local password="$2"

  logger::info "Setting MySQL user's password..."
  logger::debug "$(mysql --execute "WARNINGS; ALTER USER \`${username}\` IDENTIFIED BY '${password}'";)"
}

#######################################
# Wait until a given database service becomes available.
# Fail if the database service is not availble after a given duration.
# Arguments:
#   The database service host, a string.
#   The maximum waiting time in seconds, an integer. Default: 30.
#   The database service port, an integer. Default: 3306.
# Outputs:
#   Writes message to STDOUT.
#   Writes message to SDTERR upon failure.
#######################################
function mysql::wait_for_database_service_availability() {
  # Parameters
  local database_host="${1}"
  local maximum_wait="${2:-15}"
  local database_port="${3:-3306}"

  # Variables
  local wait_time

  logger::info "Pinging database service ${database_host}:${database_port} until readiness for a maximum of ${maximum_wait} seconds..."
  wait_time=0
  until mysqladmin ping --host "${database_host}" --port "${database_port}" --silent; do
    if [[ ${wait_time} -ge ${maximum_wait} ]]; then
      logger::error "The database service did not start within ${wait_time} s. Aborting."
      exit 1
    else
      logger::info "Waiting for the database service to start (${wait_time} s)..."
      sleep 1
      ((++wait_time))
    fi
  done
  logger::info "Database service is up and running."
}