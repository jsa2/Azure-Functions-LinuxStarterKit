# Azure Functions Starter Kit Node.js on Linux 

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
✅ Bash shell script | Tested with WSL2 (Ubuntu) on Windows 10 | [CLI script](#cli-script)
✅ [p7zip](https://www.7-zip.org/) | p7zip is  used to create the zip deployment package for package deployment | ``sudo apt-get install p7zip-full`` 
✅ AZCLI | Azure Services installation |``curl -sL https://aka.ms/InstallAzureCLIDeb \| sudo bash``
✅ Node.js runtime 14 | Used in Azure Function, and to create local function config |[install with NVM](https://github.com/nvm-sh/nvm#install--update-script)
✅ Azure Function Core Tools and VScode with Azure Functions extension  | if you want to add new templates) to this function and debug locally |[Install the Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=v3%2Clinux%2Ccsharp%2Cportal%2Cbash%2Ckeda#v2)



## Installation

1. Deploy via [CLI script](#cli-script)
2. Run `` func host start --javascript `` to test you can use managed identity locally. Managed identity is used to get information about the Azure Resource Group it's deployed on via cloud
![img](https://securecloud188323504.files.wordpress.com/2021/09/image-48.png?w=1024)


### CLI script
The CLI script below will use current subscription context to setup the solution after user has performed 

Ensure you have selected a single subscription context
``` AZ LOGIN; az account set --subscription {subscriptionID} ``` 
```shell
npm install
#az login --use-device-code
#az account set --subscription 78020cde-0dd8-4ac6-a6d4-21bac00fb343
#Define starting variables
rnd=$RANDOM
fnName=fn-starterKit-$rnd
rg=RG-FN-$rnd
location=westeurope
# You can ignore the warning "command substitution: ignored null byte in input"
storageAcc=storage$(shuf -zer -n10  {a..z})
# Your Public IP address
IPRestriction=82.181.97.241

# Create Resource Group (retention tag is just example, based on another service)
az group create -n $rg \
-l $location \
--tags="retention=30d"

# Create storageAcc Account 
saId=$(az storage account create -n $storageAcc  -g $rg --kind storageV2 -l $location -t Account --sku Standard_LRS  -o tsv --query "id")

saConstring=$(az storage account show-connection-string -g $rg  -n  $storageAcc -o tsv --query "connectionString")

#Create Scope for managed identity for Azure Reader in the resourceGroup where its deployed
scope=$(echo $saId | cut -d "/" -f2,3,4,5)

## Create Function App
az functionapp create \
--functions-version 3 \
--consumption-plan-location $location \
--name $fnName \
--os-type linux \
--resource-group $rg \
--runtime node \
--assign-identity \
--role reader \
--scope $scope \
--storage-account $storageAcc
#
sleep 10

# Additional ID for enabling specific scope and managed identity separately 
# wsid=$(az storage account show -g $rg  -n  $storageAcc -o tsv --query "id")
# scope=$(echo $wsid | cut -d "/" -f1,2,3)
# Enable Managed Identity and required permissions for key vault and monitor
#identity=$(az functionapp identity assign -g  $rg  -n $fnName --role contributor --scope $scope -o tsv --query "principalId")

az functionapp config access-restriction add --name $fnName \
--resource-group $rg \
--ip-address $IPRestriction \
--priority 1

# Set to read-only, list variables here you want to be also part of cloud deployment
az functionapp config appsettings set \
--name $fnName \
--resource-group $rg \
--settings scope=$scope  WEBSITE_RUN_FROM_PACKAGE=1 

#Create ZIP package 
7z a -tzip deploy.zip . -r -mx0 -xr\!*.git -xr\!*.vscode 

# Force triggers by deployment and restarts
unset RES
i=0
while [ -z "$RES" ] ; do
((i++))
echo "attempting to sync triggers $i/6"
az functionapp deployment source config-zip -g $rg -n $fnName --src deploy.zip
sleep 5
az functionapp restart --name $fnName --resource-group $rg 
sleep 20
keys=$(az functionapp keys list -g $rg -n $fnName -o tsv --query functionKeys) 
msiFn=$(az functionapp function show -g $rg -n $fnName --function-name testmsi -o tsv --query invokeUrlTemplate)
echo "looking for template $msiFn"
RES=$(curl -s "$msiFn"?code="$keys&resource=https://management.azure.com" )
echo "$RES"
 if [[ $i -eq 6 ]]; then
    break  
    fi
done

#
rm deploy.zip


node createConf.js $saConstring $keys $msiFn $scope

# git add .; git commit -m "exports"; git push

```
## After testing
```
az group delete \
--resource-group $rg 
```


## License
Copyright 2021 Joosua Santasalo

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
