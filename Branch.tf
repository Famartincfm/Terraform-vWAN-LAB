################################
# Branch vNET
################################

# Vnet 
resource "azurerm_virtual_network" "vNET_3" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  name                = "vNET_3"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = var.Remote_branch_location
  address_space       = ["172.16.0.0/16"]
}

#Subnet
resource "azurerm_subnet" "vNET_3_Sub1" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  name                 = "vNET_3_Sub1"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vNET_3[count.index].name
  address_prefixes     = ["172.16.1.0/24"]
}

# Gateway subnet for VPN Gateway
resource "azurerm_subnet" "vNET_3_GW_Sub" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vNET_3[count.index].name
  address_prefixes     = ["172.16.100.0/24"]
}

################################
# NSG for Subnet 3
################################

resource "azurerm_network_security_group" "BranchNSG" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  name                = "BranchNSG"
  location            = var.Remote_branch_location
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
    source_address_prefix                      = "${local.ifconfig_co_json.ip}/32"
    source_port_range                          = "*"
  }
}

# Apply NSG to Subnets
resource "azurerm_subnet_network_security_group_association" "nsg_3_Sub1" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  depends_on = [azurerm_network_security_group.BranchNSG]
  subnet_id                 = azurerm_subnet.vNET_3_Sub1[count.index].id
  network_security_group_id = azurerm_network_security_group.BranchNSG[0].id
}


################################
# Virtual Machine Network
################################

#PublicIP - to connect over RDP
resource "azurerm_public_ip" "VM3_PIP" {
count = "${var.vm_Username != "" && var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"  
  name                = "VM3_PIP"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = var.Remote_branch_location
  allocation_method   = "Dynamic"
}


#NetworkInterface
resource "azurerm_network_interface" "VM3_NIC" {
  count = "${var.vm_Username != "" && var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"  
  name                = "VM3_NIC"
  location            = var.Remote_branch_location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "VM3NIC"
    subnet_id                     = azurerm_subnet.vNET_3_Sub1[count.index].id
    private_ip_address_allocation = "Static"
	  private_ip_address            = "172.16.1.5"
    public_ip_address_id = azurerm_public_ip.VM3_PIP[0].id ## Associate public IP
  }
}


################################
# Virtual Machine
################################


resource "azurerm_windows_virtual_machine" "VM3" {
 
count = "${var.vm_Username != "" && var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"  
  name                = "VM3"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = var.Remote_branch_location
  size                = var.vmSize
  admin_username      = var.vm_Username
  admin_password      = var.vm_password

  network_interface_ids = [
      azurerm_network_interface.VM3_NIC[0].id,
  ]

  os_disk {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
      disk_size_gb = 32
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter-smalldisk"
    version   = "latest"
  }
}

################################
# VPN GW
################################

locals {
  shared-key = "123456"
  branch_asn = 65400
}

# Public IP for VPN Gateway (branch)
resource "azurerm_public_ip" "GW_Branch_PIP" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  name                = "GW_Branch_PIP"
  location            = var.Remote_branch_location
  resource_group_name  = azurerm_resource_group.resourcegroup.name

  allocation_method = "Dynamic"
  #tags              = var.tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "GW_Branch" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  location            = var.Remote_branch_location
  name                = "GW_Branch"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  vpn_type            = "RouteBased"
  generation          = "Generation1"
  sku                 = "VpnGw1"
  type                = "Vpn"
  enable_bgp          = true
  active_active       = false
  bgp_settings {
    asn = local.branch_asn
  }
  ip_configuration {
    public_ip_address_id = azurerm_public_ip.GW_Branch_PIP[0].id
    subnet_id            = azurerm_subnet.vNET_3_GW_Sub[count.index].id
  }
}

# Local network gateway (LNG) to define the vWAN HQ Hub VPN
#tunnel_ips - The list of tunnel public IP addresses which belong to the pre-defined VPN Gateway IP configuration.
#default_ips - The list of default BGP peering addresses which belong to the pre-defined VPN Gateway IP configuration
resource "azurerm_local_network_gateway" "HQ_HUB_VPN" {

  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  address_space       = ["10.0.0.0/8"]
  gateway_address     = tolist(azurerm_vpn_gateway.VPNGW-HUB-HQ[0].bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]
  location            = var.Remote_branch_location
  name                = "HQ_HUB_VPN"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  bgp_settings {
    asn                 = azurerm_vpn_gateway.VPNGW-HUB-HQ[0].bgp_settings[0].asn
    bgp_peering_address = tolist(azurerm_vpn_gateway.VPNGW-HUB-HQ[0].bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0]
  }
}

# VPN Connection
resource "azurerm_virtual_network_gateway_connection" "Branch-to-HubHQ" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  name                = "Branch-to-HubHQ"
  location            = var.Remote_branch_location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  type       = "IPsec"
  enable_bgp = true

  virtual_network_gateway_id = azurerm_virtual_network_gateway.GW_Branch[0].id
  local_network_gateway_id   = azurerm_local_network_gateway.HQ_HUB_VPN[0].id

  shared_key = local.shared-key
}