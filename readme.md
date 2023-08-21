# Azure Functions Starter Kit Node.js on Linux 


## Major update
- Uses managed Identity instead connection string for [``AzureWebJobsStorage``](https://learn.microsoft.com/en-us/azure/azure-functions/functions-app-settings#azurewebjobsstorage)
  - Finding the correct settings was bit harder than I anticipated. Bunch of helpful resources were added to the end regarding this search
  - Some discussions raise the lack of MSI support for the scaling storage account (scaling plans) [``WEBSITE_CONTENTAZUREFILECONNECTIONSTRING``](https://learn.microsoft.com/en-us/azure/azure-functions/functions-app-settings#website_contentazurefileconnectionstring) but this storage account does not store Functions keys like ``AzureWebJobsStorage`` in
- Sets up the Azure RBAC for storage based on supporting multiple function types (timer,trigger etc)
- Enables logging for Function related storage accounts and the function itself (this is to monitor security events)




**Accessing code and secrets after deployment**

Code and Function secrets are only available in the blob storage and accessable only by the managed identity of the function (unless defined otherwise)

[``fn.bicep``](/fn.bicep)
```
//Bicep
{
  name:'AzureWebJobsStorage__blobServiceUri'
  value:'https://${storageAccountName}.blob.${environment().suffixes.storage}'
}
{
  name:'WEBSITE_RUN_FROM_PACKAGE'
  value:packageUri
}
{
  name: 'AzureWebJobsStorage__${storageAccountName}'
  value: storageAccount.name
}
```


## Solution description
This solution enables a quick way to deploy and work Linux based Azure Functions locally and cloud:
- Deploys starter-kit zip-deploy using Azure CLI
- Enables managed identity locally via IP-restricted endpoint exposed on the cloud version of the function

![img](https://securecloud188323504.files.wordpress.com/2021/09/image-47.png)

## Disclaimer
Read [License](#license)


## Deployment video

<a href="https://videopress.com/embed/0Wn0owI2" title="Link Title"><img src="https://securecloud188323504.files.wordpress.com/2021/09/image-49.png?w=1024" alt="Alternate Text" /></a>


## Table of contents
- [Azure Functions Starter Kit Node.js on Linux](#azure-functions-starter-kit-nodejs-on-linux)
  - [Solution description](#solution-description)
  - [Disclaimer](#disclaimer)
  - [Deployment video](#deployment-video)
  - [Table of contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [CLI script](#cli-script)
  - [After testing](#after-testing)
  - [License](#license)


## Prerequisites 

Requirement | description | Install 
-|-|-
✅ Bash shell | Tested with WSL2 (Ubuntu) on Windows 10 
✅ [p7zip](https://www.7-zip.org/) | p7zip is  used to create the zip deployment package for package deployment | ``sudo apt-get install p7zip-full``
✅ AZCLI | Azure Services installation |``curl -sL https://aka.ms/InstallAzureCLIDeb \| sudo bash; az extension add --name storage-preview``
✅ Node.js runtime 14 | Used in Azure Function, and to create local function config |[install with NVM](https://github.com/nvm-sh/nvm#install--update-script)
✅ Azure Function Core Tools and VScode with Azure Functions extension  | if you want to add new templates) to this function and debug locally |[Install the Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=v3%2Clinux%2Ccsharp%2Cportal%2Cbash%2Ckeda#v2)
✅ JQ | parsing the output from bicep in bash | ``sudo apt install jq`` 




## Installation

1. Deploy via [CLI script](#cli-script)
2. Run `` func host start --javascript `` to test you can use managed identity locally. Managed identity is used to get information about the Azure Resource Group it's deployed on via cloud
![img](https://securecloud188323504.files.wordpress.com/2021/09/image-48.png?w=1024)


### CLI script
The CLI script below will use current subscription context to setup the solution after user has performed 

Ensure you have selected a single subscription context
``` AZ LOGIN; az account set --subscription {subscriptionID} ``` 
```shell
# Remove existing deployment package
rm deploy.zip

# Install required npm packages
npm install

# Generate random strings for naming
rnd=$(env LC_CTYPE=C tr -cd 'a-f0-9' < /dev/urandom | head -c 10)
rnd2=$(env LC_CTYPE=C tr -cd 'a-f0-9' < /dev/urandom | head -c 4)

# Define Azure resources names and locations
fnName=fnapp-generic-$rnd2
rg=RG-FN-$fnName
location=westeurope
IPRestriction=$(curl -s ifconfig.me)
storageAcc=privstorage$rnd
laws=lawsingestehoney
azEnv=honeypot
me=$(az rest -u https://graph.microsoft.com/v1.0/me | jq .id -r)
AZURE_STORAGE_AUTH_MODE=login
packageStore='function-releases'

# Create Resource Group with tags
az group create -n $rg -l $location --tags="azEnv=$azEnv"

# Create Storage account
saId=$(az storage account create -n $storageAcc  -g $rg --kind storageV2 -l $location -t Account --sku Standard_LRS  -o tsv --query "id" --allow-blob-public-access "false")

# Assign Storage Blob Data Owner role
az role assignment create --assignee $me --role "Storage Blob Data Owner" --scope $saId 

# Define source for the package
src="https://$storageAcc.blob.core.windows.net/$packageStore/zip/deploy.zip"

# Create ZIP package
7z a -tzip deploy.zip . -r -mx0 -xr\!*.git -xr\!*.vscode -xr\!local.settings.json

# Create storage container
az storage container create -n $packageStore --account-name $storageAcc --auth-mode login

# Upload the ZIP package to the storage
az storage blob directory upload -c $packageStore --account-name $storageAcc -s "deploy.zip" -d zip 

# Update storage account settings
az storage account update --name $storageAcc --resource-group $rg --allow-shared-key-access false

# Define role definition ID
roleDefId="/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b"

# Deploy using bicep templates
outputData=$(az deployment group create --resource-group $rg --template-file fn.bicep --parameters roleDefinitionResourceId=$roleDefId rand=$rnd appName=$fnName storageAccountName=$storageAcc logAnalyticsWorkspaceName=$laws packageUri=$src)

# Extract storage account details
saId2=$(echo $outputData  | jq .properties.outputResources[6].id -r)
saConstring=$(az storage account show-connection-string -g $rg  --id $saId2 -o tsv --query "connectionString")

# Update function app settings
az functionapp config access-restriction add --name $fnName --resource-group $rg --ip-address $IPRestriction --priority 1

# Retrieve function keys and invoke URL
keys=$(az functionapp keys list -g $rg -n $fnName -o tsv --query functionKeys) 
msiFn=$(az functionapp function show -g $rg -n $fnName --function-name testmsi -o tsv --query invokeUrlTemplate)

# Make a request to the function
echo "looking for template $msiFn"?code="$keys&resource=https://management.azure.com"
curl -s "$msiFn"?code="$keys&resource=https://management.azure.com" 

# Run the configuration script
node createConf.js $saConstring $keys $msiFn $scope

```
## After testing
```
az group delete \
--resource-group $rg --no-wait -y
```


## resources

I draw some examples and inspiration from the following sources 

https://learn.microsoft.com/en-us/azure/azure-functions/functions-identity-based-connections-tutorial#use-managed-identity-for-azurewebjobsstorage

https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference?tabs=blob#connecting-to-host-storage-with-an-identity

https://stackoverflow.com/questions/66480199/enable-diagnostic-settings-for-storage-account-using-armtemplate

https://learn.microsoft.com/en-us/azure/azure-functions/functions-identity-based-connections-tutorial#use-managed-identity-for-azurewebjobsstorage

-https://techcommunity.microsoft.com/t5/apps-on-azure-blog/use-managed-identity-instead-of-azurewebjobsstorage-to-connect-a/bc-p/3739810

https://learn.microsoft.com/en-us/answers/questions/1162721/how-to-secure-access-to-host-storage-account-for-f

https://learn.microsoft.com/en-us/azure/azure-functions/functions-app-settings

https://github.com/Azure/bicep/discussions/8435#discussioncomment-3694406  

https://blog.vincentboots.nl/secure-azurewebjobstorage-in-azure-functions-647e56d32727


## License
Copyright 2023 Joosua Santasalo

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
