#!/bin/bash

FROM_IP_SET_NAME=$1
TO_IP_SET_NAME=$2

# get id
FROM_IP_SET_ID=$(aws waf list-ip-sets | jq -r --arg IP_SET_NAME "$FROM_IP_SET_NAME" '.IPSets[] | select(.Name==$IP_SET_NAME) | .IPSetId')
TO_IP_SET_ID=$(aws waf list-ip-sets | jq -r --arg IP_SET_NAME "$TO_IP_SET_NAME" '.IPSets[] | select(.Name==$IP_SET_NAME) | .IPSetId')

# get ip descriptors
FROM_IP_SET_IP_DESCRIPTORS=$(aws waf get-ip-set --ip-set-id $FROM_IP_SET_ID | jq -r '.[].IPSetDescriptors[]')

CHANGE_SET=$(echo $FROM_IP_SET_IP_DESCRIPTORS | jq -s '[{"Action": "INSERT", "IPSetDescriptor":.[]}]')
echo $CHANGE_SET > changeset.json

# get change token
CHANGE_TOKEN=$(aws waf get-change-token | jq -r '.ChangeToken')

CHANGE_TOKEN=$(aws waf update-ip-set --ip-set-id $TO_IP_SET_ID --change-token "$CHANGE_TOKEN" --updates file://changeset.json | jq -r '.ChangeToken')

set +x
nr_polls=300
sleep_time=30
for i in $(seq 1 $nr_polls); do
    echo "Waiting for waf propagation to complete"
    STATUS=$(aws waf get-change-token-status --change-token $CHANGE_TOKEN | jq -r '.ChangeTokenStatus')
    if [ $STATUS = "INSYNC" ]; then
        echo "Completed propagation for change with token $CHANGE_TOKEN"
        break;
    fi
    echo "Propagation is still $STATUS"
    sleep $sleep_time
done

rm changeset.json