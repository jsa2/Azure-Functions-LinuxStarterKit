

const { axiosClient } = require('../src/axioshelpers')
const getToken = require('../src/token')

module.exports = async function (context, req) {

    var res = 'https://management.azure.com'

    var token = await getToken(res).catch((error) =>
    {
        console.log(error)
        return context.done()
    })


    var data = await axiosClient({
        url:`${res}/subscriptions?api-version=2019-08-01`,
        method:"get",
        headers:{
            authorization: "Bearer " + token.access_token
        }
    }).catch((error) => {
        console.log(error?.response?.data)


        return context.res = {
            status: 404, /* Defaults to 200 */
            body: {
                err:error?.response?.data
            }
        };

    })
    console.log(data?.data)

   return context.res = {
        status: 200, /* Defaults to 200 */
      body:data?.data
    };
}