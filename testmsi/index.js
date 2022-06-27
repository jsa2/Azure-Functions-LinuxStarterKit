

const getToken = require('../src/token')


module.exports = async function (context, req) {
   
    console.log(process.env)
    
    var resource = req.query?.resource || "https://management.azure.com"

    var token = await getToken(resource).catch((error) =>
    {
        console.log('errorDas',error)

        context.res = {
            // status: 200, /* Defaults to 200 */
            body: error || 'no token'
        }
        return context.done()
    })

    console.log('this is supposed to be error')
    context.res = {
        // status: 200, /* Defaults to 200 */
        body: token || 'no token'
    };
}