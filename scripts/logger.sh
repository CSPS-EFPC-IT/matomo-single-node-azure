#!/bin/bash
#
# Library of logging functions.
# Usage
#   Add the following line to your script before using any function:
#     source [path to logger.sh]
# Style Guide
#   https://google.github.io/styleguide/shellguide.html


## Private functions

######################################
# Output a given message and level to console using the format:
# "[date] [time] | [message level] | [message]".
# This function is NOT meant to be called directly.
# Arguments:
#   The message to output to console, a string.
#   the message level, a string.
# Outputs:
#   Writes message to STDOUT or STDERR based on message level.
######################################
function output_message_lines() {
  # Parameters
  local message="$1"
  local level="$2"

  # Variables
  local message_timestamp

  # Get a time stamp.
  message_timestamp="$(date +"%Y-%m-%d %H:%M:%S (%Z)")"

  # Create an appropriate temporary file descriptor to output message to.
  if [[ "${level}" == "error" ]]; then
    # Use STDERR.
    exec 3>&2
  else
    # Use STDOUT.
    exec 3>&1
  fi

  # Loop through each line of the message.
  while IFS= read -r line; do
    echo "${message_timestamp} | ${level^^} | ${line}" >&3
  done <<< "${message}"

  # Drop the temporary file descriptor.
  exec 3>&-
}


## Public functions

#######################################
# Log a message using the ACTION format.
# Arguments:
#   The message to output to console, a string.
# Outputs:
#   Writes message to STDOUT.
#######################################
function logger::action() {
  # Parameters
  local message="$1"

  echo ""
  output_message_lines "${message}" "action"
}


######################################
# Output a debug message only if the Azure pipeline variable System.Debug is
# set to true.
# Arguments:
#   The message to output to console, a string.
# Globals:
#   System.Debug, Ref.: https://docs.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml#systemdebug
# Outputs:
#   Writes message to STDOUT.
######################################
function logger::debug() {

  # Parameters
  local message="$1"

  if [[ -n "${SYSTEM_DEBUG}" && "${SYSTEM_DEBUG}" == "true" ]]; then
    output_message_lines "${message}" "debug"
  fi
}

######################################
# Output an error message to console.
# Arguments:
#   The message to output to console, a string.
# Outputs:
#   Writes message to STDERR.
######################################
function logger::error() {

  # Parameters
  local message="$1"

  output_message_lines "${message}" "error"
}

######################################
# Output an informative message to console.
# Arguments:
#   The message to output to console, a string.
# Outputs:
#   Writes message to STDOUT.
######################################
function logger::info() {

  # Parameters
  local message="$1"

  output_message_lines "${message}" "info"
}

######################################
# Output a line of 80 dash character.
# Arguments:
#   None.
# Outputs:
#   Writes to STDOUT.
######################################
function logger::separator() {
  echo ""
  echo "--------------------------------------------------------------------------------"
  echo ""
}

#######################################
# Log a message using the TITLE format.
# Arguments:
#   The message to output to console, a string.
# Outputs:
#   Writes message to STDOUT.
#######################################
function logger::title() {

  # Parameters
  local message="$1"

  echo ""
  echo "###############################################################################"
  echo "${message}"
  echo "###############################################################################"
}

#######################################
# An alias for the warning function.
# Arguments:
#   The message to output to console, a string.
# Outputs:
#   Writes message to STDOUT.
#######################################
function logger::warn() {

  # Parameters
  local message="$1"

  logger::warning "${message}"
}

######################################
# Output a warning message to console.
# Arguments:
#   The message to output to console, a string.
# Outputs:
#   Writes messages to STDOUT.
######################################
function logger::warning() {

  # Parameters
  local message="$1"

  output_message_lines "${message}" "warning"
}
