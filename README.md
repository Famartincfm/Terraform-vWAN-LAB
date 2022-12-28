# Virtual WAN LAB - Terraform

Variations of Virtual WAN deployment where you choose what to deploy and test.

>Everything will be deployed in a single Resource Group which you can then delete to avoid further costs. 
Optionally each vNET will host a Windows VM so you can test connectivity.

## Network topology

![vWAN](https://user-images.githubusercontent.com/62115929/209672848-1fc9343f-3bda-4866-83b3-3e30c2ce0fa2.jpg)

### Optional Resources

- One or two S2S Remote branch offices (If none is selected it won't deploy any S2S GW on the HQ_Hub as well)
- Virtual Machines (You can deploy the above design without any VMs)
- Azure Firewall
- P2S GW
- 2nd Hub inside the vWAN

You can choose which resources to deploy from above (or none) decreasing/increasing the deployment time accordingly. Hub_HQ and connected vNETs will always be deployed.

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

Select your deployment option and open Powershell on the location where you've downloaded the files:
```
HQ.tf
Variables.tf
Branch.tf
Branch2.tf
Outputs.tf (Uncomment to get visibility on VM's public IPs if VMs are deployed)
```
Install the azurerm terraform module in that location. This will also upgrade your existing Terraform modules to be compatible, if necessary.
```
terraform init --upgrade
```
Create the plan to be deployed in Azure:
```
terraform plan -out main.tfplan
```
  * Enter the Resource Group Name where everything will be deployed.
  * Enter the HQ and Branch resources location - Determine the name of the region with below PS:
  ```
    az account list-locations --query "sort_by([?not_null(metadata.geographyGroup)].{Geo:metadata.geographyGroup, Name:name}, &Geo)" -o table
  ```
  * Define how many IPsecs you want (0, 1 or 2) - This will deploy the remote branches (or not).
  * Select if you want Azure Firewall, P2S or another Hub in the vWAN. 
  * User & password for the VM access (Keep in mind Password requirements and if if left blank it won't deploy any VMs)

Example:

Apply the plan which will create the resources on your subscription.
```
terraform apply main.tfplan
```
Note: Your Public IP will automatically be added to the subnets NSG to only allow you access.

Once all resources are created, validate them on Azure Portal. Connect with RDP to the public IPs of the VM’s and have fun testing connectivity :)


Note: Windows VM’s need to open the OS firewall if you want to allow ICMP
```
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4
```
When you’re done you can delete the Resource Group created on the Azure Portal and all resources within it will be deleted.

Have fun!
