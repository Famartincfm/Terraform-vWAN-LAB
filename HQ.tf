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

provider "azurerm" {
  features {}
}

################################
# Resource Group
################################

resource "azurerm_resource_group" "resourcegroup" {
  name     = var.AResourceGroupName
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
    source_address_prefix                      = "${local.ifconfig_co_json.ip}/32"
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
# Virtual Machine Network
################################

#PublicIP - to connect over RDP
resource "azurerm_public_ip" "VM1_PIP" {
  count = "${var.vm_Username != ""  ? 1 : 0}"
  name                = "VM1_PIP"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  allocation_method   = "Dynamic"
}


#NetworkInterface
resource "azurerm_network_interface" "VM1_NIC" {
  count = "${var.vm_Username != ""  ? 1 : 0}"
  name                = "VM1_NIC"
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "VM1NIC"
    subnet_id                     = azurerm_subnet.vNET_1_Sub1.id
    private_ip_address_allocation = "Static"
	  private_ip_address            = "10.1.1.5"
    public_ip_address_id = azurerm_public_ip.VM1_PIP[0].id ## Associate public IP
  }
}

#PublicIP - to connect over RDP
resource "azurerm_public_ip" "VM2_PIP" {
  count = "${var.vm_Username != ""  ? 1 : 0}"
  name                = "VM2_PIP"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  allocation_method   = "Dynamic"
}


#NetworkInterface
resource "azurerm_network_interface" "VM2_NIC" {
  count = "${var.vm_Username != ""  ? 1 : 0}"
  name                = "VM2_NIC"
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "VM2NIC"
    subnet_id                     = azurerm_subnet.vNET_2_Sub1.id
    private_ip_address_allocation = "Static"
	  private_ip_address            = "10.2.1.5"
    public_ip_address_id = azurerm_public_ip.VM2_PIP[0].id ## Associate public IP
  }
}



################################
# Virtual Machine
################################


resource "azurerm_windows_virtual_machine" "VM1" {
 count = "${var.vm_Username != ""  ? 1 : 0}"
  name                = "VM1"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  size                = var.vmSize
  admin_username      = var.vm_Username
  admin_password      = var.vm_password

  network_interface_ids = [
      azurerm_network_interface.VM1_NIC[0].id,
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


resource "azurerm_windows_virtual_machine" "VM2" {
 count = "${var.vm_Username != ""  ? 1 : 0}"
  name                = "VM2"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  size                = var.vmSize
  admin_username      = var.vm_Username
  admin_password      = var.vm_password

  network_interface_ids = [
      azurerm_network_interface.VM2_NIC[0].id,
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

################################
# vHUB AzFirewall
################################

data "azurerm_virtual_hub" "HUB_HQ" {
  name = "HUB_HQ"
  resource_group_name = azurerm_resource_group.resourcegroup.name

  depends_on = [azurerm_virtual_hub.HUB_HQ]
}

resource "azurerm_firewall" "Hub_HQ_Firewall" {
  count = "${var._AzFW == "yes" ? 1 : 0}"
  name                = "Hub_HQ_Firewall"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  sku_name = "AZFW_Hub"
  sku_tier = "Premium"  
  
   virtual_hub {
      virtual_hub_id = data.azurerm_virtual_hub.HUB_HQ.id
  }
}

################################
# vHUB P2S GW
################################


resource "azurerm_vpn_server_configuration" "P2S_Config" {
  count = "${var._P2SGW == "yes" ? 1 : 0}"
  name                     = "P2S_Config"
  resource_group_name      = azurerm_resource_group.resourcegroup.name
  location                 = azurerm_resource_group.resourcegroup.location
  vpn_authentication_types = ["Certificate"]

  client_root_certificate {
    name             = "Root-CA"
    public_cert_data = <<EOF
MIIDuzCCAqOgAwIBAgIQCHTZWCM+IlfFIRXIvyKSrjANBgkqhkiG9w0BAQsFADBn
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSYwJAYDVQQDEx1EaWdpQ2VydCBGZWRlcmF0ZWQgSUQg
Um9vdCBDQTAeFw0xMzAxMTUxMjAwMDBaFw0zMzAxMTUxMjAwMDBaMGcxCzAJBgNV
BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
Y2VydC5jb20xJjAkBgNVBAMTHURpZ2lDZXJ0IEZlZGVyYXRlZCBJRCBSb290IENB
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvAEB4pcCqnNNOWE6Ur5j
QPUH+1y1F9KdHTRSza6k5iDlXq1kGS1qAkuKtw9JsiNRrjltmFnzMZRBbX8Tlfl8
zAhBmb6dDduDGED01kBsTkgywYPxXVTKec0WxYEEF0oMn4wSYNl0lt2eJAKHXjNf
GTwiibdP8CUR2ghSM2sUTI8Nt1Omfc4SMHhGhYD64uJMbX98THQ/4LMGuYegou+d
GTiahfHtjn7AboSEknwAMJHCh5RlYZZ6B1O4QbKJ+34Q0eKgnI3X6Vc9u0zf6DH8
Dk+4zQDYRRTqTnVO3VT8jzqDlCRuNtq6YvryOWN74/dq8LQhUnXHvFyrsdMaE1X2
DwIDAQABo2MwYTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAdBgNV
HQ4EFgQUGRdkFnbGt1EWjKwbUne+5OaZvRYwHwYDVR0jBBgwFoAUGRdkFnbGt1EW
jKwbUne+5OaZvRYwDQYJKoZIhvcNAQELBQADggEBAHcqsHkrjpESqfuVTRiptJfP
9JbdtWqRTmOf6uJi2c8YVqI6XlKXsD8C1dUUaaHKLUJzvKiazibVuBwMIT84AyqR
QELn3e0BtgEymEygMU569b01ZPxoFSnNXc7qDZBDef8WfqAV/sxkTi8L9BkmFYfL
uGLOhRJOFprPdoDIUBB+tmCl3oDcBy3vnUeOEioz8zAkprcb3GHwHAK+vHmmfgcn
WsfMLH4JCLa/tRYL+Rw/N3ybCkDp00s0WUZ+AoDywSl0Q/ZEnNY0MsFiw6LyIdbq
M/s/1JRtO3bDSzD9TazRVzn2oBqzSa8VgIo5C1nOnoAKJTlsClJKvIhnRlaLQqk=
EOF
  }
}

resource "azurerm_point_to_site_vpn_gateway" "P2S_GW" {
  count = "${var._P2SGW == "yes" ? 1 : 0}"
  name                        = "P2S-vpn-gateway"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  virtual_hub_id              = data.azurerm_virtual_hub.HUB_HQ.id
  vpn_server_configuration_id = azurerm_vpn_server_configuration.P2S_Config[0].id
  scale_unit                  = 1
  connection_configuration {
    name = "P2S-gateway-config"

    vpn_client_address_pool {
      address_prefixes = [
        "192.168.0.0/24"
      ]
    }
  }
}

################################
# vHUB S2S GW
################################


resource "azurerm_vpn_gateway" "VPNGW-HUB-HQ" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  location            = azurerm_resource_group.resourcegroup.location
  name                = "HUB_HQ_GW"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  virtual_hub_id      = azurerm_virtual_hub.HUB_HQ.id
}

################################
# Branch 1
################################

#Branch Site definition. This includes Site & Link
resource "azurerm_vpn_site" "BranchSite" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  name                = "BranchSite"
  location            = var.Remote_branch_location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  virtual_wan_id      = azurerm_virtual_wan.HQvWAN.id

  link {
    name       = "Branch_VPN_Link"
    ip_address = tolist(azurerm_virtual_network_gateway.GW_Branch[0].bgp_settings[0].peering_addresses[0].tunnel_ip_addresses)[0]
    bgp {
      asn             = azurerm_virtual_network_gateway.GW_Branch[0].bgp_settings[0].asn
      peering_address = tolist(azurerm_virtual_network_gateway.GW_Branch[0].bgp_settings[0].peering_addresses[0].default_addresses)[0]
      }
  }
}

# Connect the site to vWAN hub
resource "azurerm_vpn_gateway_connection" "Branch_VPNConnection" {
  count = "${var.VHUB_IPsec == "2" || var.VHUB_IPsec == "1" ? 1 : 0}"
  name               = "Branch_VPNConnection"
  vpn_gateway_id     = azurerm_vpn_gateway.VPNGW-HUB-HQ[count.index].id
  remote_vpn_site_id = azurerm_vpn_site.BranchSite[count.index].id

  vpn_link {
    name             = "Branch_VPN_Link"
    vpn_site_link_id = azurerm_vpn_site.BranchSite[count.index].link[0].id
    shared_key       = local.shared-key
    bgp_enabled      = true
  }
}

################################
# Branch 2
################################

#Branch Site definition. This includes Site & Link
resource "azurerm_vpn_site" "BranchSite2" {
  count = "${var.VHUB_IPsec == "2" ? 1 : 0}"
  name                = "BranchSite2"
  location            = var.Remote_branch_location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  virtual_wan_id      = azurerm_virtual_wan.HQvWAN.id

  link {
    name       = "Branch2_VPN_Link"
    ip_address = tolist(azurerm_virtual_network_gateway.GW_Branch2[0].bgp_settings[0].peering_addresses[0].tunnel_ip_addresses)[0]
    bgp {
      asn             = azurerm_virtual_network_gateway.GW_Branch2[0].bgp_settings[0].asn
      peering_address = tolist(azurerm_virtual_network_gateway.GW_Branch2[0].bgp_settings[0].peering_addresses[0].default_addresses)[0]
      }
  }
}

# Connect the site to vWAN hub
resource "azurerm_vpn_gateway_connection" "Branch2_VPNConnection" {
  count = "${var.VHUB_IPsec == "2" ? 1 : 0}"
  name               = "Branch2_VPNConnection"
  vpn_gateway_id     = azurerm_vpn_gateway.VPNGW-HUB-HQ[count.index].id
  remote_vpn_site_id = azurerm_vpn_site.BranchSite2[count.index].id

  vpn_link {
    name             = "Branch2_VPN_Link"
    vpn_site_link_id = azurerm_vpn_site.BranchSite2[count.index].link[0].id
    shared_key       = local.shared-key2
    bgp_enabled      = true
  }
}

################################
# vHUB2
################################

resource "azurerm_virtual_hub" "HUB_HQ2" {
  count = "${var.__HUB2 == "yes" ? 1 : 0}"
  name                = "Hub_HQ2"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  virtual_wan_id      = azurerm_virtual_wan.HQvWAN.id
  address_prefix      = "10.200.0.0/23"
}
