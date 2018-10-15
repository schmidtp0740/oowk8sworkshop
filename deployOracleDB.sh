#!/bin/bash

# TODO give database a random name
export OCIDB=$(oci db autonomous-database create --compartment-id "${COMPARTMENTOCID}" --admin-password "${DB_PASSWORD}" --cpu-core-count "1" --data-storage-size-in-tbs "1" --db-name "oracledb2" --display-name "oracleDB2" --license-model "LICENSE_INCLUDED" --wait-for-state "AVAILABLE" --query "data.id" |  sed 's/"//g')
echo "completed deploying autonoumous-database"

echo "Grabbing wallet"

URL="https://database.us-ashburn-1.oraclecloud.com/20160918/autonomousDatabases/${OCIDB}/actions/generateWallet"

curl