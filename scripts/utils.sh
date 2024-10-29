#!/bin/bash
#
# Implements a library of miscelleneous utility functions.
# Usage
#   Add the following two lines to your script before using any function:
#     source [path to logger.sh]
#     source [path to utils.sh]
# Style Guide
#   https://google.github.io/styleguide/shellguide.html

#######################################
# Parse and set script parameters into associative array.
# Globals:
#   parameters: An associative array for script parameters.
# Arguments:
#   The whole script command line ($@) where:
#     parameter keys are prefix with "--"
#     parameter key and value are separated by with space(s).
#   Ex.: myscript --parm1 value1 --parm2 value2
# Outputs:
#   Writes normal log messages to STDOUT.
#   Writes error messages to STDERR.
# Returns:
#   0 on success
#   1 on failure
#######################################
function utils::parse_parameters() {
  local -r KEY_PREFIX="--"
  local -r KEY_REGEX_PATTERN="^${KEY_PREFIX}.*$"

  local key
  local missing_parameter_flag
  local sorted_keys
  local unexpected_parameter_flag
  local usage
  local value

  logger::action "Mapping input parameter values and checking for unexpected parameters..."
  unexpected_parameter_flag=false
  while [[ ${#@} -gt 0 ]]; do
    key=$1
    value=$2

    # Test if the parameter key start with the KEY_PREFIX and if the parameter
    # key without the PARAMETERS_PREFIX is in the expected parameter list.
    if [[ "${key}" =~ $KEY_REGEX_PATTERN && ${parameters[${key:${#KEY_PREFIX}}]+_} ]]; then
      parameters[${key:${#KEY_PREFIX}}]="${value}"
    else
      logger::error "Unexpected parameter: ${key}"
      unexpected_parameter_flag=true
    fi

    # Move to the next key/value pair or up to the end of the parameter list.
    shift $(( 2 < ${#@} ? 2 : ${#@} ))
  done

  logger::action "Checking for missing parameters..."
  sorted_keys=$(echo "${!parameters[@]}" | tr " " "\n" | sort | tr "\n" " ");
  missing_parameter_flag=false
  for key in ${sorted_keys}; do
    if [[ -z "${parameters[${key}]}" ]]; then
      logger::error "Missing parameter: ${key}."
      missing_parameter_flag=true
    fi
  done

  # Abort if missing or extra parameters.
  usage="USAGE: $(basename "$0")"
  if [[ "${unexpected_parameter_flag}" == "true" || "${missing_parameter_flag}" == "true" ]]; then
    logger::error "Execution aborted due to missing or extra parameters."
    for key in ${sorted_keys}; do
      usage="${usage} ${KEY_PREFIX}${key} \$${key}"
    done
    logger::error "${usage}";
    exit 1;
  fi

  logger::action "Printing input parameter values for debugging purposes..."
  for key in ${sorted_keys}; do
    logger::info "${key} = \"${parameters[${key}]}\""
  done

  logger::action "Locking down parameters array..."
  readonly parameters
}

#######################################
# Set EXIT trap to echo failed command and its exit code.
# Globals:
#   $BASH_COMMAND
#   last_command
#   current_command
# Outputs:
#   Writes last command and exit code to STDERR.
#######################################
function utils::set_exit_trap() {
  # Exit script when any command fails
  set -e
  # Keep track of the last executed command
  trap 'last_command=${BASH_COMMAND}' DEBUG
  # Echo an error message before exiting
  # shellcheck disable=SC2154
  trap 'echo "\"${last_command}\" command failed with exit code $?." >&2' EXIT
}

#######################################
# Counter part of set_exit_trap.
#######################################
function utils::unset_exit_trap() {
  # Remove DEBUG and EXIT trap
  trap - DEBUG
  trap - EXIT
  # Allow script to continue on error.
  set +e
}
