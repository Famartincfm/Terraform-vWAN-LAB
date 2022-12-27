################################
# Input Variables & Locals (calculated vars)
################################

variable "AResourceGroupName" {
  type = string
  description = "Enter the Resource Group Name you would like to use"
}

variable "HQ_location" {
  type = string
  #default = "westeurope"
  description = "Enter the region you would like to install the HQ resources"
}

variable "Remote_branch_location" {
  type = string
  description = "Enter the region you would like to install the Branch resources "
}

variable "VHUB_IPsec" {
type = string
  description = "Do you wish to deploy 1 IPSec branch or 2 IPsec branches in the HQvHUB ? Select '1' or '2' or '0' for **NO** branch"
  validation {
    condition   = lower(var.VHUB_IPsec) == "1" || lower(var.VHUB_IPsec) == "2" || lower(var.VHUB_IPsec) == "0"
    error_message = "Please enter '1' or '2' or '0'"
  }
}

variable "_AzFW" {
type = string
  description = "Do you wish to deploy a Azure Firewall in the HQ vHUB? (yes/no)"
  validation {
    condition   = lower(var._AzFW) == "yes" || lower(var._AzFW) == "no"
    error_message = "Please enter 'yes' or 'no'." 
  }
}

variable "_P2SGW" {
type = string
  description = "Do you wish to deploy a P2S GW in the HQ vHUB? (yes/no)"
  validation {
    condition   = lower(var._P2SGW) == "yes" || lower(var._P2SGW) == "no"
    error_message = "Please enter 'yes' or 'no'." 
  }
}

variable "__HUB2" {
type = string
  description = "Do you wish to deploy a 2nd vHub in the vWAN? (yes/no)"
  validation {
    condition   = lower(var.__HUB2) == "yes" || lower(var.__HUB2) == "no"
    error_message = "Please enter 'yes' or 'no'." 
  }
}

#Fetching public IP
data "http" "my_public_ip" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  ifconfig_co_json = jsondecode(data.http.my_public_ip.response_body)
}

variable "vmSize" {
  description = "VM SKU Size"
  default = "Standard_DS2_v2"
}

variable "vm_Username" {
  description = "VM administrator username (Check VM Username Requirements!) - Note: Leave empty string to NOT create any VMs"
  type        = string
  sensitive   = true
}
variable "vm_password" {
  description = "VM administrator password (Check VM Password Requirements!) - Note: Leave empty string to NOT create any VMs"
  type        = string
  sensitive   = true
}

