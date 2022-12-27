
/*
output "VM1_Public_IP" {
  value       = length(azurerm_public_ip.VM1_PIP[0].ip_address)
  description = "Public IP of VM1."
}

output "VM2_Public_IP" {
  value       = length(azurerm_public_ip.VM2_PIP[0].ip_address)
  description = "Public IP of VM2."
}


output "VM3_Public_IP" {
   value       = length(azurerm_public_ip.VM3_PIP[0].ip_address)
  description = "Public IP of VM3."
}

output "VM4_Public_IP" {
   value       = length(azurerm_public_ip.VM4_PIP[0].ip_address)
  description = "Public IP of VM4."
}
*/

output "my_public_ip_addr" {
  value = local.ifconfig_co_json.ip
}