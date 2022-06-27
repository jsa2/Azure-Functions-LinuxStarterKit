[nan,nan,sa,key,msiUrl, scope] = process.argv

/* console.log([nan,nan,sa,key,msiUrl, scope]) */

  var localSettings = {
    "IsEncrypted": false,
    "Values": {
      "AzureWebJobsStorage": sa,
      "FUNCTIONS_WORKER_RUNTIME": "node",
      "FUNCTIONS_EXTENSION_VERSION": "~3",
      "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING":sa,
      "url":`${msiUrl}?code=${key}`,
      "scope":scope
    }
  }

var fs = require('fs')

/* console.log(localSettings) */

fs.writeFileSync('local.settings.json',JSON.stringify(localSettings))