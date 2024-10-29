#!/bin/bash
#
# Implements a library of Operating System (OS) related functions.
# Usage
#   Add the following two lines to your script before using any function:
#     source [path to logger.sh]
#     source [path to os.sh]
# Style Guide
#   https://google.github.io/styleguide/shellguide.html

# Functions

#######################################
# Add new commented entry in server hosts file.
# Arguments:
#   1) IP address to add
#   2) Corresponding Fully Qualified Domain Name to add
#   3) Corresponding entry comment to add
# Outputs:
#   Writes log to STDOUT.
#######################################
function os::add_hosts_file_entry() {
  local ip="$1"
  local fqdn="$2"
  local comment="$3"

  local -r HOSTS_FILE_PATH="/etc/hosts"

  logger::action "Adding entry for \"${fqdn}\" in \"${HOSTS_FILE_PATH}\"..."
  if ! grep -q "${fqdn}" "${HOSTS_FILE_PATH}"; then
    printf "# %s\n%s %s\n" "${comment}" "${ip}" "${fqdn}" >> "${HOSTS_FILE_PATH}"
  else
    logger::warn "Skipped: ${HOSTS_FILE_PATH} already contains entry for ${fqdn}."
  fi
}

#######################################
# Mount a data disk identified by its size.
# Since there is no way to set or predict the block device name associated to
# a data disk, we use the block device size to identify the data disk that
# needs to be mounted. Hence, this function will fail if none or more than one
# attached block devices match the size of data disk to mount.
# A file system (EXT4) is created on the mounted data disk if none exists.
# Globals:
# Arguments:
#   1) size of the disk to mount, a string as returned by the
#      "lsblk --output name,size" command.
#   2) data disk mount point, a path
# Outputs:
#   Writes normal log messages to STDOUT.
#   Writes error messages to STDERR.
#######################################
function os::mount_data_disk_by_size() {
  local data_disk_size="$1"
  local data_disk_mount_point_path="$2"

  local -r DEFAULT_FILE_SYSTEM_TYPE="ext4"
  local -r FSTAB_FILE_PATH="/etc/fstab"
  local -r TIMEOUT=60

  local data_disk_block_device_path
  local data_disk_block_device_name
  local data_disk_file_system_type
  local data_disk_file_system_uuid
  local elapsed_time

  logger::action "Retrieving data disk block device path using data disk size as index..."
  data_disk_block_device_name="$(lsblk --noheadings --output name,size | awk "{if (\$2 == \"${data_disk_size}\") print \$1}")"
  case $(echo "${data_disk_block_device_name}" | wc -w) in
    0)
      logger::error "No block device matches the given data disk size (${data_disk_size}). Aborting."
      exit 1
      ;;
    1)
      logger::info "Unique block device found: ${data_disk_block_device_name}"
      data_disk_block_device_path="/dev/${data_disk_block_device_name}"
      ;;
    *)
      logger::error "More than one block devices match the given data disk size (${data_disk_size}). Aborting."
      exit 1
      ;;
  esac

  logger::action "Creating file system on data disk block if none exists..."
  data_disk_file_system_type="$(lsblk --noheadings --output fstype "${data_disk_block_device_path}")"
  if [[ -z "${data_disk_file_system_type}" ]]; then
    logger::info "No file system detected on ${data_disk_block_device_path}."
    data_disk_file_system_type="${DEFAULT_FILE_SYSTEM_TYPE}"
    logger::action "Creating file system of type ${data_disk_file_system_type} on ${data_disk_block_device_path}..."
    mkfs.${data_disk_file_system_type} "${data_disk_block_device_path}"
  else
    logger::warn "Skipped: File system ${data_disk_file_system_type} already exist on ${data_disk_block_device_path}."
  fi

  logger::action "Retrieving data disk file system UUID..."
  # Bug Fix:  Experience demonstrated that the UUID of the new file system is not immediately
  #           available through lsblk, thus we wait and loop for up to 60 seconds to get it.
  elapsed_time=0
  data_disk_file_system_uuid=""
  while [[ -z "${data_disk_file_system_uuid}" && "${elapsed_time}" -lt "${TIMEOUT}" ]]; do
    logger::info "Waiting for 1 second..."
    sleep 1
    data_disk_file_system_uuid="$(lsblk --noheadings --output UUID "${data_disk_block_device_path}")"
    ((elapsed_time+=1))
  done
  if [[ -z "${data_disk_file_system_uuid}" ]]; then
    logger::error "Could not retrieve the data disk file system UUID within ${TIMEOUT} seconds. Aborting."
    exit 1
  else
    logger::info "Data disk file system UUID: ${data_disk_file_system_uuid}"
  fi

  logger::action "Creating data disk mount point at ${data_disk_mount_point_path}..."
  mkdir -p "${data_disk_mount_point_path}"

  logger::action "Updating ${FSTAB_FILE_PATH} file to automount the data disk using its UUID..."
  if grep -q "${data_disk_file_system_uuid}" "${FSTAB_FILE_PATH}"; then
    logger::warn "Skipped: already set up."
  else
    printf "UUID=%s\t%s\t%s\tdefaults,nofail\t0\t2\n" "${data_disk_file_system_uuid}" "${data_disk_mount_point_path}" "${data_disk_file_system_type}" >> "${FSTAB_FILE_PATH}" 
  fi

  logger::action "Mounting all drives..."
  mount -a
}
