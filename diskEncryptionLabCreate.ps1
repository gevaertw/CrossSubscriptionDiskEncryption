# get paramteres from json files
$secretParameters = Get-Content -Raw -Path '.\secrets.json' | ConvertFrom-Json
$parameters = Get-Content -Raw -Path '.\parameters.json' | ConvertFrom-Json

$customerSubscriptionName = $secretParameters.customerSubscriptionName
$adminUserName = $secretParameters.adminUserName
$customerLabRgName = $parameters.customerLabRgName
$tagList = $parameters.tagList
$regionName = $parameters.regionName
$vmNamePrefix = $parameters.vmNamePrefix
$vmImage = $parameters.vmImage
$dataDiskNamePrefix = $parameters.dataDiskNamePrefix
$dataDiskSize = $parameters.dataDiskSize
$bootdiagStorage = $parameters.bootdiagStorage + (Get-Random -Minimum 0000 -Maximum 9999).ToString()
$vNetName = $parameters.vNetName
$vNetAddressSpace = $parameters.vNetAddressSpace
$vmSubnetName = $parameters.vmSubnetName
$vmAddressPrefix = $parameters.vmAddressPrefix
$bastionPublicIPName = $parameters.bastionPublicIPName
$bastionName = $parameters.bastionName
$bastionAddressPrefix = $parameters.bastionAddressPrefix


az account set --subscription $customerSubscriptionName

# create the RG
az group create --name $customerLabRgName --location $regionName --tag $tagList

# create the vNet
az network vnet create `
    --name $vNetName `
    --resource-group $customerLabRgName `
    --location $regionName `
    --address-prefix $vNetAddressSpace

#create VM subnet
az network vnet subnet create `
    --name $vmSubnetName `
    --resource-group $customerLabRgName `
    --vnet-name $vNetName `
    --address-prefixes $vmAddressPrefix
<# # Optional Bastion stuff comment it out if not needed
#create bastion subnet in vnet
az network vnet subnet create `
    --name AzureBastionSubnet `
    --resource-group $customerLabRgName `
    --vnet-name $vNetName `
    --address-prefixes $bastionAddressPrefix

## Bastion needs a public IP
az network public-ip create `
    --resource-group $customerLabRgName `
    --name $bastionPublicIPName `
    --sku Standard `
    --location $regionName

## Create The bastion
az network bastion create `
    --name $bastionName `

    --public-ip-address $bastionPublicIPName `
    --resource-group $customerLabRgName `
    --vnet-name $vNetName `
    --location $regionName `
    --enable-tunneling true `
    --sku Standard #>

#create boot diag sa
az storage account create `
    --name $bootdiagStorage `
    --resource-group $customerLabRgName `
    --location $regionName `
    --sku Standard_LRS

#create the VM
$vmName = $vmNamePrefix + "01"
Write-Host $vmName
az vm create `
    --resource-group $customerLabRgName `
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
$dataDiskName = $vmName + $dataDiskNamePrefix + "01"
az vm disk attach `
    --resource-group $customerLabRgName `
    --vm-name $vmName `
    --name $dataDiskName `
    --size-gb $dataDiskSize `
    --sku Premium_LRS `
    --new
