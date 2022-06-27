var fs = require('fs')

var [nan,nan,key,delUrl,msiUrl,sa,sacon,scope,rg] = process.argv

console.log(sa)

/* 
console.log([nan,nan,key,delUrl,msiUrl,sa,sacon,scope,rg]) */


fs.writeFileSync('exportSettings.json',`{
"msi":"${msiUrl}?code=${key}",
"del":"${delUrl}?code=${key}",
"sa":"${sa}",
"connectionString":"${sacon}",
"webhook":"https://thx138.webhook.office.com/webhookb2/18cb141d-2119-4611-aa47-8bc4042c8020@033794f5-7c9d-4e98-923d-7b49114b7ac3/IncomingWebhook/a9bfff087f264d1ca337c8dc23babfd1/138ac68f-d8a7-4000-8d41-c10aa26a9097",
"scope":"${scope}",
"rg":"${rg}"
}`)

