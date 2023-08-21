#WSL or other Linux distro
G=$(az group list --tag 'azEnv=honeypot' --query "[].{name:name}" -o tsv) 

for res in $G
do
 echo "az group delete --id $res"
 az group delete --name $res --no-wait -y
done


