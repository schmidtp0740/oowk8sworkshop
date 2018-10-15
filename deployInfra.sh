#!/bin/bash

# ----------- Collect OCID values from $HOME/.oci/config ----------------

export TENANCYOCID=$(cat $HOME/.oci/config | grep tenancy= | sed -e 's/tenancy=//')

export USEROCID=$(cat $HOME/.oci/config | grep user= | sed -e 's/user=//')

export FINGERPRINT=$(cat $HOME/.oci/config | grep fingerprint= | sed -e 's/fingerprint=//')

export REGION=$(cat $HOME/.oci/config | grep region= | sed -e 's/region=//')

echo "Enter compartment-id: "
read COMPARTMENTOCID


if [ $REGION = "us-ashburn-1" ]
then
    OCIR="iad.ocir.io"
elif [ $REGION = "us-phoenix-1" ]
then
    OCIR="phx.ocir.io"
fi

# # ---------- Gather details for OCIR --------------

echo "Collect credentials to push docker image to Oracle Cloud Infrastructure Registry (OCIR) "

TENANCY=$(oci iam compartment get --compartment-id "${TENANCYOCID}" --query "data.name" |  sed 's/"//g')

if [ "${TENANCY}" == "" ]
then
  echo "need to complete ~/.oci/config file"
  exit
else
  echo "Tenancy name: ${TENANCY}"
fi

USERNAME=$(oci iam user get --user-id "${USEROCID}" --query "data.name" |  sed 's/"//g')

if [ "${USERNAME}" == "" ]
then
  echo "need to complete ~/.oci/config file"
  exit 
else
  echo "Username: ${USERNAME}"
fi

export DB_PASSWORD="Str0ng@W1nner"

export AUTHTOKEN=$(oci iam auth-token create --description "token for OCIR" --user-id "${USEROCID}"  --query "data.token" |  sed 's/"//g')

if [ "${AUTHTOKEN}" == "" ]
then
  echo "need to complete ~/.oci/config file"
  exit 
else
  echo "auth token: ${AUTHTOKEN}"
fi


# ------------ Creating Oracle DB -----------------


echo "Creating Oracle Autonomous Database"

source deployOracleDB.sh &

# TODO
# need username/ password/ connectionstring
# wallet has credentials has connection string 
# extract connection string 
# export CONNECTIONSTRING=$(oci db autonomous-database get --autonomous-database-id "${oci_db}" --query "data.\"connection-strings\".high" |  sed 's/"//g' )


# -------------- OCIR Networking Prereqs -----------

# Deploy a vcn
echo "Creating VCN"
export oci_vcn_ocid=$(oci network vcn create --compartment-id "${COMPARTMENTOCID}" --cidr-block "10.0.0.0/16" --display-name "defaultVCN" --wait-for-state "AVAILABLE" --wait-interval-seconds "10" --query "data.id" |  sed 's/"//g') 
echo "Completed creating VCN"


# Create a default internet gateway
echo "Creating Internet Gateway"
export oci_gateway=$(oci network internet-gateway create --compartment-id "${COMPARTMENTOCID}" --wait-for-state "AVAILABLE" --wait-interval-seconds "10" --vcn-id $oci_vcn_ocid --display-name "gateway-0" --is-enabled "true" --query "data.id" |  sed 's/"//g')
echo "Completed creating internet gateway"

# create a route table
echo "Creating Route Table"
export oci_route_table=$(oci network route-table create --compartment-id "${COMPARTMENTOCID}" --route-rules "[{\"destination\":\"0.0.0.0/0\",\"destinationType\": \"CIDR_BLOCK\", \"networkEntityId\":\"${oci_gateway}\"}]" --vcn-id $oci_vcn_ocid --display-name "routetable-0" --wait-for-state "AVAILABLE" --query "data.id" |  sed 's/"//g')
echo "Completed creating internet gateway"

# create security lists
echo "Creating security lists"
echo "Creating workers security list"
export oci_security_list_worker=$(oci network security-list create --compartment-id "${COMPARTMENTOCID}" \
--vcn-id $oci_vcn_ocid \
--display-name "workers-security-list" \
--wait-for-state "AVAILABLE" \
--egress-security-rules '[{"destination": "10.0.10.0/24", "protocol": "all", "isStateless": true},{"destination": "10.0.11.0/24", "protocol": "all", "isStateless": true},{"destination": "10.0.12.0/24", "protocol": "all", "isStateless": true },{"destination": "0.0.0.0/0", "protocol": "all","isStateless": false }]' \
--ingress-security-rules '[{"source": "10.0.10.0/24", "protocol": "All", "isStateless": true },{"source": "10.0.11.0/24", "protocol": "All", "isStateless": true },{"source": "10.0.12.0/24", "protocol": "All", "isStateless": true},{"source": "0.0.0.0/0", "protocol": "1", "isStateless": false},{"source": "130.35.0.0/16", "protocol": "6", "isStateless": false, "tcpOptions": {"destinationPortRange": {"max": 22, "min": 22}}},{"source": "138.1.0.0/17", "protocol": "6", "isStateless": false, "tcpOptions": {"destinationPortRange": {"max": 22, "min": 22}}},{"source": "0.0.0.0/0", "protocol": "6", "isStateless": false, "tcpOptions": {"destinationPortRange": {"max": 22, "min": 22}}},{"source": "0.0.0.0/0", "protocol": "6", "isStateless": false, "tcpOptions": {"destinationPortRange": {"min": 30000, "max": 32767}}}]' \
--query "data.id" |  sed 's/"//g')

echo "Completed creating workers security list"
echo "Creating loadbalancer security list"
export oci_security_list_loadbalancer=$(oci network security-list create --compartment-id "${COMPARTMENTOCID}" \
--vcn-id $oci_vcn_ocid --display-name "loadbalancer-security-list" \
--wait-for-state "AVAILABLE" \
--egress-security-rules '[{"destination": "0.0.0.0/0", "protocol": "6", "isStateless": true}]' \
--ingress-security-rules '[{"source": "0.0.0.0/0", "protocol": "6", "isStateless": true}]' \
--query "data.id" |  sed 's/"//g')

echo "Completed creating loabalancer security list"

# create worker subnets
echo "Creating Workers Subnets"
export oci_subnet_workers1=$(oci network subnet create --compartment-id "${COMPARTMENTOCID}" --availability-domain $(oci iam availability-domain list --query "data[0].name" |  sed 's/"//g') --cidr-block "10.0.10.0/24" --vcn-id $oci_vcn_ocid --display-name "workers-1"  --route-table-id $oci_route_table --security-list-ids "[\"${oci_security_list_worker}\"]" --wait-for-state "AVAILABLE" --query "data.id" |  sed 's/"//g')
export oci_subnet_workers2=$(oci network subnet create --compartment-id "${COMPARTMENTOCID}" --availability-domain $(oci iam availability-domain list --query "data[1].name" |  sed 's/"//g') --cidr-block "10.0.11.0/24" --vcn-id $oci_vcn_ocid --display-name "workers-2"  --route-table-id $oci_route_table --security-list-ids "[\"${oci_security_list_worker}\"]" --wait-for-state "AVAILABLE" --query "data.id" |  sed 's/"//g')
export oci_subnet_workers3=$(oci network subnet create --compartment-id "${COMPARTMENTOCID}" --availability-domain $(oci iam availability-domain list --query "data[2].name" |  sed 's/"//g') --cidr-block "10.0.12.0/24" --vcn-id $oci_vcn_ocid --display-name "workers-3"  --route-table-id $oci_route_table --security-list-ids "[\"${oci_security_list_worker}\"]" --wait-for-state "AVAILABLE" --query "data.id" |  sed 's/"//g')
echo "Completed Creating Workers Subnets"

# create loadbalancer subnets
echo "Creating loadbalancer subnets"
export oci_subnet_loadbalancer1=$(oci network subnet create --compartment-id "${COMPARTMENTOCID}" --availability-domain $(oci iam availability-domain list --query "data[0].name" |  sed 's/"//g') --cidr-block "10.0.20.0/24" --vcn-id $oci_vcn_ocid --display-name "loadbalancer-1"  --route-table-id $oci_route_table --security-list-ids "[\"${oci_security_list_loadbalancer}\"]" --wait-for-state "AVAILABLE" --query "data.id" |  sed 's/"//g')
export oci_subnet_loadbalancer2=$(oci network subnet create --compartment-id "${COMPARTMENTOCID}" --availability-domain $(oci iam availability-domain list --query "data[1].name" |  sed 's/"//g') --cidr-block "10.0.21.0/24" --vcn-id $oci_vcn_ocid --display-name "loadbalancer-2"  --route-table-id $oci_route_table --security-list-ids "[\"${oci_security_list_loadbalancer}\"]" --wait-for-state "AVAILABLE" --query "data.id" |  sed 's/"//g')
echo "Completed creating loadbalancer subnets"



# ------------- Creating Cluster ------------------

echo "Creating OKE Cluster"
export oci_ce_cluster=$(oci ce cluster create --compartment-id "${COMPARTMENTOCID}" --name "defaultCluster" --vcn-id $oci_vcn_ocid --kubernetes-version "v1.10.3" --wait-for-state "SUCCEEDED" --service-lb-subnet-ids "[\"${oci_subnet_loadbalancer1}\", \"${oci_subnet_loadbalancer2}\"]" --pods-cidr "10.244.0.0/16" --services-cidr "10.96.0.0/16" --query "data.resources[0].identifier" |  sed 's/"//g')
echo "Completed creating OKE Cluster"


echo "Creating Node Pool"
export oci_ce_node_pool=$(oci ce node-pool create --compartment-id "${COMPARTMENTOCID}" --cluster-id $oci_ce_cluster --name "defaultNodePool"  --kubernetes-version "v1.10.3" --node-shape "VM.Standard2.2" --node-image-name "Oracle-Linux-7.5" --subnet-ids "[\"${oci_subnet_workers1}\"]" --quantity-per-subnet 1 --wait-for-state "SUCCEEDED" --query "data.resources[0].identifier" |  sed 's/"//g')

echo "waiting for nodes to be available"
while true
do
    RESULT=$(oci ce node-pool get  --node-pool-id $oci_ce_node_pool --query "data.nodes")

    if [ "" != "${RESULT}"  ]
        then
        RESULT=$(oci ce node-pool get  --node-pool-id $oci_ce_node_pool --query "data.nodes[0].\"lifecycle-state\"" |  sed 's/"//g')

        if [ "ACTIVE" = "${RESULT}" ]
            then
            echo "node is ${RESULT}"
            break
        else
            echo "node is ${RESULT}, waiting for it to be active"
            sleep 10
        fi
    else
        echo "initializing node(s)"
        sleep 10
    fi
done

# ------------------ Configure kubectl ------------------------

oci ce cluster create-kubeconfig --cluster-id $oci_ce_cluster --file $(pwd)/kubeconfig

export KUBECONFIG=`pwd`/kubeconfig


