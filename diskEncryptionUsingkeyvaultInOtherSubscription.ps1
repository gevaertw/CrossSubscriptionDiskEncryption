#get som secrets from an external file, not published on github, create your own file :)
$secretParamamters = Get-Content -Raw -Path '.\secrets.json' | ConvertFrom-Json
$secretParamamters.parameters


# experiments on disk encrytion
$tagList= @("CostCenter=DiskEncryptionExperiments","Environment=DEV01")
$sourceSubscriptionName=$secretParamamters.sourceSubscriptionName
$destinationSubscriptionName= $secretParamamters.destinationSubscriptionName
$sourceSubscriptionName="ME-MngEnvMCAP376337-wgevaert-1"
$destinationSubscriptionName="ME-MngEnvMCAP376337-wgevaert-2"
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

$vmName = $vmNamePrefix + "01"

$keyVaultName = "kv-diskEncWG124892"
$diskEncryptionKeyName = "diskEncryptionKey01"
$diskEncryptionSetName = "diskEncryptionSet01"



# Logon
# az Login
az account set --subscription $sourceSubscriptionName

# create the RG
az group create --name $keyVaultrgName --location $regionName --tag $tagList

# create the keyvault
az keyvault create `
    --name $keyVaultName `
    --location $regionName `
    --resource-group $keyVaultrgName `
    --tags $tagList `
    --sku 'premium' `
    --enable-rbac-authorization true `
    --enable-purge-protection true `
    --retention-days 7 `
    --enabled-for-deployment true `
    --enabled-for-disk-encryption true `
    --enabled-for-template-deployment true `
    --no-self-perms false

$keyVaultID=$(az keyvault show --resource-group $keyVaultrgName --name $keyVaultName --query id --output tsv)


#give yourself permissions on the keyvault
#### $keyVaultrgName=$(az resource list --name $keyVaultName --query "[].resourceGroup" --output tsv)
$azureCurrentLoggedOnUserID=$(az ad signed-in-user show --query id --output tsv)
$azureCurrentLoggedOnUserUPN=$(az ad signed-in-user show --query userPrincipalName --output tsv)

az role assignment create --role "Key vault Administrator" --assignee $azureCurrentLoggedOnUserUPN --scope $keyVaultID

# creates a disk encryption key in the keyVault
az keyvault key create --vault-name $keyVaultName --name $diskEncryptionKeyName --protection software

# get the URL of the key
$keyVaultKeyUrl = az keyvault key show --vault-name $keyVaultName --name $diskEncryptionKeyName --query [key.kid] --output tsv


<# 
# Azure Disk Encryption encrypt the data disk using a keyvault in another subscription: DOES NOT WORK, IS NOT SUPORTED
az vm encryption enable `
    --disk-encryption-keyvault $keyVaultID `
    --subscription $destinationSubscriptionName `
    --name $vmName `
    --resource-group $VMrgName `
    --key-encryption-key $diskEncryptionKeyName `
    --volume-type DATA
 #>

## Server-Side Encryption (SSE) with Customer Managed Keys (CMK) for managed disks
az disk-encryption-set create `
    --name $diskEncryptionSetName `
    --location $regionName `
    --resource-group $VMrgName `
    --tags $tagList `
    --key-url $keyVaultKeyUrl `
    --enable-auto-key-rotation false


# create an identity for the disk set to access the key
$desIdentity = az disk-encryption-set show -n $diskEncryptionSetName --resource-group $VMrgName --query [identity.principalId] --output tsv

# sets access on the keyvault for the identity
<# az keyvault set-policy `
    --name $keyVaultName `
    --resource-group $rgName `
    --object-id $desIdentity `
    --key-permissions wrapkey unwrapkey get #>


az role assignment create  `
    --role "Key Vault Crypto Service Encryption User"  `
    --assignee-object-id $desIdentity  `
    --scope $keyVaultID
    
    
# Encrypt the disks of a VM using the disk set
## Get all disks from a VM
$VMID = az vm show -d --resource-group $VMrgName --name $vmName --query id --output tsv
$osDiskName = az vm show --id $VMID --query "storageProfile.osDisk.name" --output tsv

$VMDataDiskIDObj = az vm show --id $VMID --query "storageProfile.dataDisks[].managedDisk.id" --output json | ConvertFrom-Json
$VMDataDiskIDList = @($VMDataDiskIDObj)

# Stop the VM
az vm deallocate --id $VMID

#Encrypt the OS disk
az disk update  `
    --name $osDiskName  `
    --resource-group $VMrgName  `
    --encryption-type EncryptionAtRestWithCustomerKey  `
    --disk-encryption-set $diskEncryptionSetName

#Encrypt all data disks
$sourceVMDataDiskIDObj = az vm show --id $VMID --query "storageProfile.dataDisks[].managedDisk.id" --output json | ConvertFrom-Json
$sourceVMDataDiskIDList = @($sourceVMDataDiskIDObj)
foreach ($sourceVMDataDiskID in $sourceVMDataDiskIDList)
{
    $sourceVMDataDiskName = az disk show --id $sourceVMDataDiskID --query "name" --output tsv
    az disk update `
        --name $sourceVMDataDiskName `
        --resource-group $VMrgName `
        --encryption-type EncryptionAtRestWithCustomerKey `
        --disk-encryption-set $diskEncryptionSetName
}