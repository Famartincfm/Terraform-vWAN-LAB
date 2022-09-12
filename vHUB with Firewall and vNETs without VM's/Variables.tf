
################################
# Input Variables & Locals (calculated vars)
################################

variable "ResourceGroupName" {
  type = string
  description = "Enter the Resource Group Name you would like to use"
}

variable "HQ_location" {
  type = string
  description = "Enter the region you would like to install the HQ resources"
}

variable "Branch_location" {
  type = string
  description = "Enter the region you would like to install the Branch resources"
}

variable "IPAddress" {
  type = string
  description = "Enter your home IP address. If you do not know it you can go to https://whatismyipaddress.com/. For example: 1.2.3.4"
  validation {
    condition = can(regex("\\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\b", var.IPAddress))
	error_message = "Could not parse IP address. Please ensure the IP is a valid IPv4 IP address."
  }
}

  locals {
  cidr = "${cidrhost("${var.IPAddress}/24", 0)}/24"
  }