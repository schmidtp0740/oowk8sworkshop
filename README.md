

# Prereqs
- make sure you have an oci user that has admin rights to manange all resources in a given comparment
- collect the following details
    - tenancy OCID
    - User OCID
    - fingerprint
    - path of private key 
    - region
    - compartment ocid

# Step 1
- build worker container and get in terminal
```
./start.sh
```

- setup oci config files
```
oci setup config
```
- accept all defaults
- enter USEROCID
- enter tenancyOCID
- enter region

- copy the public key and paste into the ocir user api key page
```
cat ~/.oci/oci_api_key_public.pem
```

- deploy infra
```
source infraAutomation/infraAutomation.sh
```

- enter compartment ocid
- watch all the resources needed deploy automatically and the web app deployed