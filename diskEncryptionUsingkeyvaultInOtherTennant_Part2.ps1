# This script executes phase 1 of the disk encryption using a keyvault in another tennant.  This part is executed by the customer

#get some secrets from an external file, not published on github, create your own file :)
$secretParamamters = Get-Content -Raw -Path '.\secrets.json' | ConvertFrom-Json
$parameters = Get-Content -Raw -Path '.\parameters.json' | ConvertFrom-Json


# experiments on disk encrytion
#$tagList= @("CostCenter=DiskEncryptionExperiments","Environment=DEV01")
$kmaasSubscriptionName=$secretParamamters.kmaasSubscriptionName
$customerSubscriptionName= $secretParamamters.customerSubscriptionName
$keyVaultrgName=$parameters.keyVaultrgName
$regionName=$parameters.regionName
$keyVaultName = $parameters.keyVaultName
$diskEncryptionKeyName = $parameters.diskEncryptionKeyName
$diskEncryptionSetName = $parameters.diskEncryptionSetName



# Logon
# az Login
az account set --subscription $kmaasSubscriptionName

# 2.2 create the keyvault
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

# create a key in the keyVault
az keyvault key create --vault-name $keyVaultName --name $diskEncryptionKeyName --protection software

# get the URL of the key
$keyVaultKeyUrl = az keyvault key show --vault-name $keyVaultName --name $diskEncryptionKeyName --query [key.kid] --output tsv



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
    
 