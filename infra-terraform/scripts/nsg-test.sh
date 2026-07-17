RG=rg-boa-workload-dev-eus2
AKS=aks-boa-dev-eus2

# node subnet id
SUBNET=$(az aks show -g $RG -n $AKS --query "agentPoolProfiles[0].vnetSubnetId" -o tsv); echo "$SUBNET"

# NSG attached to it
NSG=$(az network vnet subnet show --ids "$SUBNET" --query "networkSecurityGroup.id" -o tsv); echo "$NSG"

# inbound rules — look for allow on 80 / 30133 AND any DENY at a lower priority number
az network nsg rule list --ids "$NSG" \
  --query "[?direction=='Inbound'].{prio:priority,access:access,proto:protocol,src:sourceAddressPrefix,dport:destinationPortRange,name:name}" \
  -o table
