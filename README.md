# vWAN LAB - Terraform

Several variations of vWAN deployments that can be used in LAB

>Everything will be deployed in a single Resource Group which you can then delete to avoid further costs. Each vNET will host a Windows VM so you can test connectivity.

## Base topology created

![2vNET_HUB_Firewall_VPN](https://user-images.githubusercontent.com/101132018/185445495-040fae1b-d94a-4b39-b6c1-6f90c976fe6c.jpg)

Topology variations included:
- vHUB with S2S branch with VM's on each vNET (default - above diagram)
  - vHUB with S2S branch <ins>without</ins> VM's - Faster deployment
  - vHUB with S2S & Firewall <ins>without</ins> VM's - Faster deployment
- vHUB with Firewall and S2S branch with VM's on each vNET

## Requirements

Install az cli for Windows. Once installed, you should run "az login" via command prompt to log az cli into Azure, and then select your target subscription
```
az account set --subscription "<subId>" (replace <subId> with your real SubID GUID)
```

Install Terraform (Windows)

- Download the latest version of Terraform (Windows x64) https://www.terraform.io/downloads.html

- Copy the unzipped terraform.exe to anywhere within Windows PATH options (generally C:\Windows\system32).

- Re-open any CMD/PowerShell windows to reload Windows PATH.
Confirm Terraform is installed properly by running "terraform -v"


## Deployment

Open Powershell and go to the location where you've downloaded the files:
```
Variables.tf
HQ.tf
Branch.tf
```
Install the azurerm terraform module in that location. This will also upgrade your existing Terraform modules to be compatible, if necessary.
```
terraform init --upgrade
```
Create the plan to be deployed in Azure:
```
terraform plan -out main.tfplan
```
  * You'll be asked the region to deploy the HQ and Branch resources - you can determine the name of the region you would like to deploy by running the following:
  ```
    az account list-locations --query "sort_by([?not_null(metadata.geographyGroup)].{Geo:metadata.geographyGroup, Name:name}, &Geo)" -o table
  ```
  * Define home public IP to be allowed on the NSGs (giving the VM's Public IPs only access to the defined IP)
  * User & password for the VM access (Keep in mind Password requirements)


Apply the plan which will create the resources on your subscription.
```
terraform apply main.tfplan
```
Once all resources are created, validate them on Azure Portal. Connect with RDP to the public IPs of the VM’s and have fun testing connectivity.

Note: Windows VM’s need to open the OS firewall to allow ICMP
```
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4
```
When you’re done you can delete the Resource Group created on the Azure Portal and all resources within it will be deleted.
