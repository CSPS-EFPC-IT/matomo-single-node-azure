#!/bin/bash
#
# Implements a library of Apache2 related functions.
# Usage
#   Add the following two lines to your script before using any function:
#     source [path to logger.sh]
#     source [path to apache2.sh]
# Style Guide
#   https://google.github.io/styleguide/shellguide.html

# Functions

#######################################
# Harden Apache2 Webserver settings.
# Arguments:
#   Apache2 security configuration file to update, a file path.
# Outputs:
#   Writes normal log messages to STDOUT.
#   Writes error messages to STDERR.
#######################################
function apache2::harden() {
  local config_file_path="$1"

  apache2::update_config_file "ServerTokens" "Prod" "${config_file_path}"
  apache2::update_config_file "ServerSignature" "Off" "${config_file_path}"
}

#######################################
# Update the value of existing and enabled parameter in an Apache2 config file.
# Arguments:
#   1) Parameter to set, text string.
#   2) Value to set, text string.
#   3) Apache2 config file to update, file path.
# Outputs:
#   Writes normal log messages to STDOUT.
#   Writes error messages to STDERR.
#######################################
function apache2::update_config_file() {
  local parameter="$1"
  local value="$2"
  local config_file_path="$3"

  logger::action "Setting \"${parameter}\" to \"${value}\" in \"${config_file_path}\"..."

  # Check if one and only one line match the search criteria.
  case $(grep -c "^[[:blank:]]*${parameter}[[:blank:]].*$" "${config_file_path}") in
    0)
      logger::error "No line matched the search criteria. Aborting."
      exit 1
      ;;
    1)
      logger::info "One line matched the search criteria. Updating it..."
      ;;
    *)
      logger::error "More than one line matched the search criteria. Aborting."
      exit 1
      ;;
  esac

  # Perform substitution while maintaining code indentation.
  sed -i -E "s|^([[:blank:]]*)${parameter}[[:blank:]].*$|\1${parameter} ${value}|g" "${config_file_path}"
}
