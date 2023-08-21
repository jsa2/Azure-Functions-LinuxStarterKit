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
az deployment group create --resource-group $rg --template-file appLogs.bicep --parameters logAnalyticsWorkspaceName=$laws functionAppName=$fnName

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
