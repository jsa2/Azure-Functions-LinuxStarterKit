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
"scope":"${scope}",
"rg":"${rg}"
}`)

