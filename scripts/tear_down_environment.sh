#!/bin/bash
#
######################################
# Delete all Matomo Single Node resources, except for the Key Vault, the User
# Assigned Managed Identity and the Application Gateway Public IP, from a given
# Resource Group. This is typically run against non-production resource groups
# to save on infrastructure costs when an environment is no longer needed.
# Globals:
#   None.
# Arguments:
#   The resource group name containing the resources to delete, a string.
#   A resource name search token used to match the name of the resources to delete, a string.
# Outputs:
#   Writes error messages to stderr.
#   Writes trace messages to stdout.
######################################

function main() {

  # Input parameters with default value.
  declare -Ax parameters=( \
    [--resource-group-name]="" \
  )

  # Variables
  local application_gateway_ids
  local backup_item_ids
  local bastion_names
  local disk_ids
  local index
  local log_analytics_workspace_names
  local mysql_flexible_server_ids
  local network_interface_card_ids
  local network_security_group_ids
  local private_dns_zone_names
  local public_ip_ids
  local recovery_service_vault_ids
  local storage_account_ids
  local subindex
  local virtual_network_ids
  local vm_ids
  local vnet_link_names

  # Map input parameter values.
  echo "Parsing input parameters..."
  while [[ $# -gt 0 ]]; do
    case $1 in
      --resource-group-name)
        if [[ $# -lt 2 ]]; then
          echo "Input parameter \"$1\" requires a value. Aborting."
          exit 1
        fi
        parameters[$1]="$2"
        shift 2
        ;;
      *)
        echo "Unknown input parameter: \"$1\"."
        echo "Usage: $0 ${!parameters[*]}"
        exit 1
        ;;
    esac
  done

  # Check for missing input parameters.
  for key in "${!parameters[@]}"; do
    if [[ -z "${parameters[${key}]}" ]]; then
      echo "Missing input parameter: \"${key}\". Aborting."
      echo "Usage: $0 ${!parameters[*]}"
      exit 1
    fi
    echo "Input parameter value: ${key} = \"${parameters[${key}]}\"."
  done

  echo "Installing az cli extensions..."
  az extension add \
    --name bastion \
    --only-show-errors \
    --upgrade

  echo "Deleting Virtual Machines, if any..."
  vm_ids="$(az vm list \
      --only-show-errors \
      --output tsv \
      --query "[].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${vm_ids}" ]; then
    echo "No Virtual Machine Found. Skipping."
  else
    index=0
    for vm_id in ${vm_ids}; do
      ((++index))
      echo "(${index}) Deleting ${vm_id}..."
      az vm delete \
        --ids "${vm_id}" \
        --only-show-errors \
        --output none \
        --yes
    done
  fi

  echo "Deleting Disks, if any..."
  disk_ids="$(az disk list \
      --only-show-errors \
      --output tsv \
      --query "[].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${disk_ids}" ]; then
    echo "No Disk Found. Skipping."
  else
    index=0
    for disk_id in ${disk_ids}; do
      ((++index))
      echo "(${index}) Deleting ${disk_id}..."
      az disk delete \
        --ids "${disk_id}" \
        --only-show-errors \
        --output none \
        --yes
    done
  fi

  echo "Deleting Network Interface Cards, if any..."
  network_interface_card_ids="$(az network nic list \
      --only-show-errors \
      --output tsv \
      --query "[].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${network_interface_card_ids}" ]; then
    echo "No Network Interface Card Found. Skipping."
  else
    index=0
    for network_interface_card_id in ${network_interface_card_ids}; do
      ((++index))
      echo "(${index}) Deleting ${network_interface_card_id}..."
      az network nic delete \
        --ids "${network_interface_card_id}" \
        --only-show-errors \
        --output none
    done
  fi

  echo "Deleting Storage Accounts, if any..."
  storage_account_ids="$(az storage account list \
      --only-show-errors \
      --output tsv \
      --query "[].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${storage_account_ids}" ]; then
    echo "No Storage Account found. Skipping."
  else
    index=0
    for storage_account_id in ${storage_account_ids}; do
      ((++index))
      echo "(${index}) Deleting ${storage_account_id}..."
      az storage account delete \
        --ids "${storage_account_id}" \
        --only-show-errors \
        --output none \
        --yes
    done
  fi

  echo "Deleting MySQL Flexible Server, if any..."
  mysql_flexible_server_ids="$(az mysql flexible-server list \
      --only-show-errors \
      --output tsv \
      --query "[].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${mysql_flexible_server_ids}" ]; then
    echo "No MySQL Flexible Server Found. Skipping."
  else
    index=0
    for mysql_flexible_server_id in ${mysql_flexible_server_ids}; do
      ((++index))
      echo "(${index}) Deleting ${mysql_flexible_server_id}..."
      az mysql flexible-server delete \
        --ids "${mysql_flexible_server_id}" \
        --only-show-errors \
        --output none \
        --yes
    done
  fi

  echo "Deleting Private DNS Zone, if any..."
  private_dns_zone_names="$(az network private-dns zone list \
      --only-show-errors \
      --output tsv \
      --query "[].name" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${private_dns_zone_names}" ]; then
    echo "No Private DNS Zone Found. Skipping."
  else
    index=0
    for private_dns_zone_name in ${private_dns_zone_names}; do
      ((++index))

      # Delete all Virtual Network Links first as Private DNS Zone can't be
      # deleted when linked to Virtual Networks.
      echo "(${index}) Deleting Private DNS Zone Virtual Network Links, if any..."
      vnet_link_names="$(az network private-dns link vnet list \
        --only-show-errors \
        --output tsv \
        --query "[].name" \
        --resource-group "${parameters[--resource-group-name]}" \
        --zone-name "${private_dns_zone_name}" \
        | xargs  \
      )"
      iteration_count=0
      for vnet_link_name in ${vnet_link_names}; do
        (( ++iteration_count ))
        echo "(${index}.${iteration_count}) Deleting ${vnet_link_name}..."
        az network private-dns link vnet delete \
          --name "${vnet_link_name}" \
          --only-show-errors \
          --resource-group "${parameters[--resource-group-name]}" \
          --yes \
          --zone-name "${private_dns_zone_name}"
      done

      echo "(${index}) Deleting ${private_dns_zone_name}..."
      az network private-dns zone delete \
        --name "${private_dns_zone_name}" \
        --only-show-errors \
        --output none \
        --resource-group "${parameters[--resource-group-name]}" \
        --yes
    done
  fi

  echo "Deleting Bastion Service, if any..."
  bastion_names="$(az network bastion list \
      --only-show-errors \
      --output tsv \
      --query "[].name" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${bastion_names}" ]; then
    echo "No Bastion Service Found. Skipping."
  else
    index=0
    for bastion_name in ${bastion_names}; do
      ((++index))
      echo "(${index}) Deleting ${bastion_name}..."
      az network bastion delete \
        --name "${bastion_name}" \
        --only-show-errors \
        --output none \
        --resource-group "${parameters[--resource-group-name]}" \
        --yes
    done
  fi

  echo "Deleting Application Gateways, if any..."
  application_gateway_ids="$(az network application-gateway list \
      --only-show-errors \
      --output tsv \
      --query "[].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${application_gateway_ids}" ]; then
    echo "No Application Gateway Found. Skipping."
  else
    index=0
    for application_gateway_id in ${application_gateway_ids}; do
      ((++index))
      echo "(${index}) Deleting ${application_gateway_id}..."
      az network application-gateway delete \
        --ids "${application_gateway_id}" \
        --only-show-errors \
        --output none
    done
  fi

  echo "Deleting Application Gateway WAF policies, if any..."
  application_gateway_web_application_firewall_policy_ids="$(az network application-gateway waf-policy list \
      --only-show-errors \
      --output tsv \
      --query "[].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${application_gateway_web_application_firewall_policy_ids}" ]; then
    echo "No Application Gateway WAF Policies Found. Skipping."
  else
    index=0
    for application_gateway_web_application_firewall_policy_id in ${application_gateway_web_application_firewall_policy_ids}; do
      ((++index))
      echo "(${index}) Deleting ${application_gateway_web_application_firewall_policy_id}..."
      az network application-gateway waf-policy delete \
        --ids "${application_gateway_web_application_firewall_policy_id}" \
        --only-show-errors \
        --output none
    done
  fi

  ####################

  echo "Deleting Virtual Networks, if any..."
  virtual_network_ids="$(az network vnet list \
      --only-show-errors \
      --output tsv \
      --query "[].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${virtual_network_ids}" ]; then
    echo "No Virtual Network found. Skipping."
  else
    index=0
    for virtual_network_id in ${virtual_network_ids}; do
      ((++index))
      echo "(${index}) Deleting ${virtual_network_id}..."
      az network vnet delete \
        --ids "${virtual_network_id}" \
        --only-show-errors \
        --output none
    done
  fi

  echo "Deleting Network Security Groups, if any..."
  network_security_group_ids="$(az network nsg list \
      --only-show-errors \
      --output tsv \
      --query "[].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${network_security_group_ids}" ]; then
    echo "No Network Security Group Found. Skipping."
  else
    index=0
    for network_security_group_id in ${network_security_group_ids}; do
      ((++index))
      echo "(${index}) Deleting ${network_security_group_id}..."
      az network nsg delete \
        --ids "${network_security_group_id}" \
        --only-show-errors \
        --output none
    done
  fi

  echo "Deleting Public IPs other then Application Gateway Public IP, if any..."
  public_ip_ids="$(az network public-ip list \
      --only-show-errors \
      --output tsv \
      --query "[?!contains(name,'-AG-')].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${public_ip_ids}" ]; then
    echo "No Public Ip Found. Skipping."
  else
    index=0
    for public_ip_id in ${public_ip_ids}; do
      ((++index))
      echo "(${index}) Deleting ${public_ip_id}..."
      az network public-ip delete \
        --ids "${public_ip_id}" \
        --only-show-errors \
        --output none
    done
  fi

  echo "Deleting Recovery Service Vaults, if any..."
  recovery_service_vault_ids="$(az backup vault list \
      --only-show-errors \
      --output tsv \
      --query "[].id" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${recovery_service_vault_ids}" ]; then
    echo "No Recovery Service Vault Found. Skipping."
  else
    index=0
    for recovery_service_vault_id in ${recovery_service_vault_ids}; do
      ((++index))
      echo "(${index}) Processing ${recovery_service_vault_id}..."

      echo "(${index}) Disabling Soft Delete feature..."
      az backup vault backup-properties set \
        --ids "${recovery_service_vault_id}" \
        --only-show-errors \
        --output none \
        --soft-delete-feature-state Disable

      echo "(${index}) Retrieving Backup Items, if any..."
      backup_item_ids="$(az backup item list \
          --only-show-errors \
          --output tsv \
          --query "[].id" \
          --resource-group "${parameters[--resource-group-name]}" \
          --vault-name "$(basename "${recovery_service_vault_id}")" \
        )"
      if [ -z "${backup_item_ids}" ]; then
        echo "(${index}) No Backup Item found. Skipping."
      else
        echo "(${index}) Disabling Backup Item's protection..."
        subindex=0
        for backup_item_id in ${backup_item_ids}; do
          ((++subindex))
          echo "(${index}.${subindex}) Processing ${backup_item_id}..."
          az backup protection disable \
            --delete-backup-data true \
            --ids "${backup_item_id}" \
            --only-show-errors \
            --output none \
            --yes
        done
      fi

      echo "(${index}) Deleting Recovery Service Vault..."
      az backup vault delete \
        --force \
        --ids "${recovery_service_vault_id}" \
        --only-show-errors \
        --output none \
        --yes
    done
  fi

  echo "Deleting Log Analytics Workspaces, if any..."
  log_analytics_workspace_names="$(az monitor log-analytics workspace list \
      --only-show-errors \
      --output tsv \
      --query "[].name" \
      --resource-group "${parameters[--resource-group-name]}" \
    )"
  if [ -z "${log_analytics_workspace_names}" ]; then
    echo "No Log Analytics Workspace Found. Skipping."
  else
    index=0
    for log_analytics_workspace_name in ${log_analytics_workspace_names}; do
      ((++index))
      echo "(${index}) Deleting ${log_analytics_workspace_name}..."
      az monitor log-analytics workspace delete \
        --force "true" \
        --only-show-errors \
        --output none \
        --resource-group "${parameters[--resource-group-name]}" \
        --workspace-name "${log_analytics_workspace_name}" \
        --yes
    done
  fi
}

main "$@"
