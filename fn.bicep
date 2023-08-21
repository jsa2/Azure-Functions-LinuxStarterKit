
param appName string 
param roleDefinitionResourceId string
param rand string
param storageAccountName string
param storageAccountType string = 'Standard_LRS'
param logAnalyticsWorkspaceName string
param packageUri string

param stgContrib string = '/providers/Microsoft.Authorization/roleDefinitions/86e8f5dc-a6e9-4c67-9d15-de283e8eac25'
param queRole string = '/providers/Microsoft.Authorization/roleDefinitions/974c5e8b-45b9-4653-ba55-5f855dd0fb88'
param location string = resourceGroup().location

param runtime string = 'node'

var functionAppName = appName
var hostingPlanName = appName

var storageAccountName2= 'scaling${uniqueString(guid(rand))}azfn'
var functionWorkerRuntime = runtime

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName 
}

resource storageAccount2 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName2
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties:{
    sku: {
      name: 'PerNode'
    }
    retentionInDays: int(60)
    workspaceCapping: {
      dailyQuotaGb: int(1)
  }
}
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2021-06-01' = {
  parent: storageAccount2
  name: 'default'
  properties: {}
}

resource diagnosticsBlob 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobService
  name: 'diagnostics02'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        categoryGroup:'allLogs'
        enabled: true
      }
    ]
  }
}

resource fileDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: fileService
  name: 'diagnostics00'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        categoryGroup:'allLogs'
        enabled: true
      }
    ]
  }
}



resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__${storageAccountName}'
          value: storageAccount.name
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName2};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount2.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
        {
          name:'AzureWebJobsStorage__blobServiceUri'
          value:'https://${storageAccountName}.blob.${environment().suffixes.storage}'
        }
        {
          name:'WEBSITE_RUN_FROM_PACKAGE'
          value:packageUri
        }
        {
          name:'AzureWebJobsSecretStorageType'
          value:'blob'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
      ]
      ftpsState: 'disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

resource app_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: guid('laws2')
  properties: {
    workspaceId:  logAnalytics.id 
    logs:[
      {
        category:'FunctionAppLogs'
        enabled:true
      }
    ]
  }
  scope: functionApp
}


output principalId string = functionApp.identity.principalId
// Assume we have an app service with a System Assigned managed service identity

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid('${rand}1')
  properties: {
    roleDefinitionId: roleDefinitionResourceId
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid('${rand}2')
  properties: {
    roleDefinitionId: stgContrib
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}


resource roleAssignment3 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid('${rand}3')
  properties: {
    roleDefinitionId: queRole
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
