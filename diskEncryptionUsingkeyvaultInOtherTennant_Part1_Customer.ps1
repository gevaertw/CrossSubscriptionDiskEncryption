# This script executes phase 1 of the disk encryption using a keyvault in another tennant.  This part is executed by the customer in the customer tennant

# Import parameters from parameters.json file
$parameters = Get-Content -Raw -Path '.\parameters.json' | ConvertFrom-Json

$customerSubscriptionName= $parameters.customerSubscriptionName
$customerRegionName=$parameters.customerRegionName
$customerRgName = $parameters.customerRgName
$customerEncryptionAssignedIdentityName = $parameters.customerEncryptionAssignedIdentityName
$customerEncryptionAppRegName = $parameters.customerEncryptionAppRegName
$customerEncryptionAppReplyUrl = $parameters.customerEncryptionAppReplyUrl

# Logon
# az Login
az account set --subscription $customerSubscriptionName

# create the RG
az group create  `
    --name $customerRgName `
    --location $customerRegionName

# 1.1 Create a new multi-tenant Azure AD application registration or start with an existing application registration. Note the application ID (client ID) of the application registration
az ad app create `
    --display-name $customerEncryptionAppRegName `
    --web-redirect-uris $customerEncryptionAppReplyUrl `
    --sign-in-audience AzureADMultipleOrgs
    
$customerAppRegClientId = az ad app list --display-name $customerEncryptionAppRegName --query [].appId --output tsv


# 1.2 Create a user-assigned managed identity (to be used as a Federated Identity Credential).
az identity create `
    --name $customerEncryptionAssignedIdentityName `
    --resource-group $customerRgName 

# $customerIdentityClientId = (az identity show --resource-group $customerRgName --name $customerEncryptionAssignedIdentityName --query clientId --output tsv)

# 1.3 Configure user-assigned managed identity as a federated identity credential on the application, so that it can impersonate the identity of the application.
# Define the resource group, identity name, and application ID

# Reset the application's credentials with the identity's client ID
az ad app credential reset `
    --id $customerAppRegClientId `
    --display-name "Federated Identity Credential" `
    --append
