#!/bin/bash
#
# Implements a library of PHP related functions.
# Usage
#   Add the following two lines to your script before using any function:
#     source [path to logger.sh]
#     source [path to php.sh]
# Style Guide
#   https://google.github.io/styleguide/shellguide.html

# Functions

#######################################
# Update and enable an existing parameter in a PHP config file.
# Arguments:
#   1) Parameter to set, text string.
#   2) Value to set, text string.
#   3) PHP file to update, file path
# Outputs:
#   Writes log messages to STDOUT.
#   Writes error messages to STDERR.
#######################################
function php::update_config_file() {
  local parameter="$1"
  local value="$2"
  local config_file_path="$3"

  local regex

  logger::action "Setting \"${parameter}\" to \"${value}\" in \"${config_file_path}\"..."

  # Check if one and only one line match the search criteria.
  regex="^;?${parameter}[[:blank:]]*=.*$"
  case $(grep -c -E "${regex}" "${config_file_path}") in
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

  # Perform substitution.
  sed -i -E "s|${regex}|${parameter} = ${value}|" "${config_file_path}"
}