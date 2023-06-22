#get som secrets from an external file, not published on github, create your own file :)
$secretParamamters = Get-Content -Raw -Path '.\secrets.json' | ConvertFrom-Json
$secretParamamters.parameters


# experiments on disk encrytion
$tagList= @("CostCenter=DiskEncryptionExperiments","Environment=DEV01")
$sourceSubscriptionName=$secretParamamters.sourceSubscriptionName
$destinationSubscriptionName= $secretParamamters.destinationSubscriptionName
$keyVaultrgName="diskEncryptionExperimentKeys"
$VMrgName="diskEncryptionExperimentVMs"
$regionName="northeurope"
$vmNamePrefix="RHELVM"
$vmImage="RedHat:RHEL:8-lvm-gen2:8.5.2022032206" #see vmimages on how to get this urn / vmImage
$adminUserName= $secretParamamters.adminUserName
$dataDiskNamePrefix="DataDisk"
$dataDiskSize=128
$bootdiagStorage="sabootdiag486643485"
$vNetName="vnet-diskEncryptionExperiment"
$vNetAddressSpace="10.1.0.0/16"
$bastionAddressPrefix="10.1.254.0/24"
$vmSubnetName="snet-VM"
$vmAddressPrefix="10.1.0.0/24"
$bastionPublicIPName="pip-Bastion"
$bastionName="bas-fastDeploy"
$keyVaultName = "kv-diskEncWG124892"
$diskEncryptionKeyName = "diskEncryptionKey01"
$diskEncryptionSetName = "diskEncryptionSet01"

az account set --subscription $destinationSubscriptionName

# create the RG
az group create --name $VMrgName --location $regionName --tag $tagList

# create the vNet
az network vnet create `
    --name $vNetName `
    --tags $tagList `
    --resource-group $VMrgName `
    --location $regionName `
    --address-prefix $vNetAddressSpace

#create VM subnet
az network vnet subnet create `
    --name $vmSubnetName `
    --resource-group $VMrgName `
    --vnet-name $vNetName `
    --address-prefixes $vmAddressPrefix

#create bastion subnet in vnet
az network vnet subnet create `
    --name AzureBastionSubnet `
    --resource-group $VMrgName `
    --vnet-name $vNetName `
    --address-prefixes $bastionAddressPrefix

#Bastion needs a public IP
az network public-ip create `
    --resource-group $VMrgName `
    --tags $tagList `
    --name $bastionPublicIPName `
    --sku Standard `
    --location $regionName

#Create The bastion
az network bastion create `
    --name $bastionName `
    --tags $tagList `
    --public-ip-address $bastionPublicIPName `
    --resource-group $VMrgName `
    --vnet-name $vNetName `
    --location $regionName `
    --enable-tunneling true `
    --sku Standard

#create boot diag sa
az storage account create `
    --name $bootdiagStorage `
    --tags $tagList `
    --resource-group $VMrgName `
    --location $regionName `
    --sku Standard_LRS

#create the VM
$vmName = $vmNamePrefix + "01"
Write-Host $vmNameaz vm create `
  --resource-group $VMrgName `
  --tags $tagList `
  --name $vmName `
  --image $vmImage `
  --admin-username $adminUserName `
  --generate-ssh-keys `
  --security-type TrustedLaunch `
  --vnet-name $vNetName `
  --subnet $vmSubnetName `
  --boot-diagnostics-storage $bootdiagStorage `
  --public-ip-address '""'

#add a NEW disk to the vm
$dataDiskName =  $vmName + $dataDiskNamePrefix + "01"
az vm disk attach `
    --resource-group $VMrgName `
    --vm-name $vmName `
    --name $dataDiskName `
    --size-gb $dataDiskSize `
    --sku Premium_LRS `
    --new
