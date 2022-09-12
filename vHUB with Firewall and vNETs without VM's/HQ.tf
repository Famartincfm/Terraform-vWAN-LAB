################################
# Provider Details
################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.60.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

################################
# Resource Group
################################

resource "azurerm_resource_group" "resourcegroup" {
  name     = var.ResourceGroupName
  location = var.HQ_location

}

################################
# Virtual Networks & Subnets
################################

# Vnet 1
resource "azurerm_virtual_network" "vNET_1" {
  name                = "vNET_1"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  address_space       = ["10.1.0.0/16"]
}
#Subnets
resource "azurerm_subnet" "vNET_1_Sub1" {
  name                 = "vNET_1_Sub1"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vNET_1.name
  address_prefixes     = ["10.1.1.0/24"]
}
resource "azurerm_subnet" "vNET_1_Sub2" {
  name                 = "vNET_1_Sub2"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vNET_1.name
  address_prefixes     = ["10.1.2.0/24"]
}


# Vnet 2
resource "azurerm_virtual_network" "vNET_2" {
  name                = "vNET_2"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  address_space       = ["10.2.0.0/16"]
}

#Subnet
resource "azurerm_subnet" "vNET_2_Sub1" {
  name                 = "vNET_2_Sub1"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vNET_2.name
  address_prefixes     = ["10.2.1.0/24"]
}

################################
# NSG for Subnet 1 & 2
################################

resource "azurerm_network_security_group" "HQ_NSG" {
  name                = "HQNSG"
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  security_rule {
    access                                     = "Allow"
    description                                = "Allow from External IP"
    destination_address_prefix                 = "*"
    destination_port_range                     = "*"
    direction                                  = "Inbound"
    name                                       = "externalCidr"
    priority                                   = 100
    protocol                                   = "*"
    source_address_prefix                      = local.cidr
    source_port_range                          = "*"
  }
}

# Apply NSG to Subnets
resource "azurerm_subnet_network_security_group_association" "nsg_1_Sub1" {
  subnet_id                 = azurerm_subnet.vNET_1_Sub1.id
  network_security_group_id = azurerm_network_security_group.HQ_NSG.id
}

resource "azurerm_subnet_network_security_group_association" "nsg_1_Sub2" {
  subnet_id                 = azurerm_subnet.vNET_1_Sub2.id
  network_security_group_id = azurerm_network_security_group.HQ_NSG.id
}

resource "azurerm_subnet_network_security_group_association" "nsg_2_Sub1" {
  subnet_id                 = azurerm_subnet.vNET_2_Sub1.id
  network_security_group_id = azurerm_network_security_group.HQ_NSG.id
}


################################
# Virtual WAN & Virtual HUB
################################


resource "azurerm_virtual_wan" "HQvWAN" {
  name                = "HQvWAN"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
}

resource "azurerm_virtual_hub" "HUB_HQ" {
  name                = "Hub_HQ"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  virtual_wan_id      = azurerm_virtual_wan.HQvWAN.id
  address_prefix      = "10.100.0.0/23"
}

# Connect VNET 1 & 2 to HUB
resource "azurerm_virtual_hub_connection" "vNET_1-HUB_HQ" {
  name                      = "vNET_1-HUB_HQ"
  virtual_hub_id            = azurerm_virtual_hub.HUB_HQ.id
  remote_virtual_network_id = azurerm_virtual_network.vNET_1.id
}

resource "azurerm_virtual_hub_connection" "vNET_2-HUB_HQ" {
  name                      = "vNET_2-HUB_HQ"
  virtual_hub_id            = azurerm_virtual_hub.HUB_HQ.id
  remote_virtual_network_id = azurerm_virtual_network.vNET_2.id
}


data "azurerm_virtual_hub" "HUB_HQ" {
  name = "HUB_HQ"
  resource_group_name = azurerm_resource_group.resourcegroup.name

  depends_on = [azurerm_virtual_hub.HUB_HQ]
}

#HQ HUB Firewall
resource "azurerm_firewall" "Hub_HQ_Firewall" {
  name                = "Hub_HQ_Firewall"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  sku_name = "AZFW_Hub"
  sku_tier = "Premium"  
  
   virtual_hub {
      virtual_hub_id = data.azurerm_virtual_hub.HUB_HQ.id
  }
}


#HUB VPN Gateway
resource "azurerm_vpn_gateway" "VPNGW-HUB-HQ" {
  location            = azurerm_resource_group.resourcegroup.location
  name                = "HUB_HQ_GW"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  virtual_hub_id      = azurerm_virtual_hub.HUB_HQ.id
}


#Branch Site definition. This includes Site & Link
resource "azurerm_vpn_site" "BranchSite" {
  name                = "BranchSite"
  location            = var.Branch_location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  virtual_wan_id      = azurerm_virtual_wan.HQvWAN.id

  link {
    name       = "Branch_VPN_Link"
    ip_address = tolist(azurerm_virtual_network_gateway.GW_Branch.bgp_settings[0].peering_addresses[0].tunnel_ip_addresses)[0]
    bgp {
      asn             = azurerm_virtual_network_gateway.GW_Branch.bgp_settings[0].asn
      peering_address = tolist(azurerm_virtual_network_gateway.GW_Branch.bgp_settings[0].peering_addresses[0].default_addresses)[0]
      }
  }
}

# Connect the site to vWAN hub
resource "azurerm_vpn_gateway_connection" "Branch_VPNConnection" {
  name               = "Branch_VPNConnection"
  vpn_gateway_id     = azurerm_vpn_gateway.VPNGW-HUB-HQ.id
  remote_vpn_site_id = azurerm_vpn_site.BranchSite.id

  vpn_link {
    name             = "Branch_VPN_Link"
    vpn_site_link_id = azurerm_vpn_site.BranchSite.link[0].id
    shared_key       = local.shared-key
    bgp_enabled      = true
  }
}

