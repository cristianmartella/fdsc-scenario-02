#!/bin/bash

echo "*** Participant federation ***"

data_service_url="http://mp-data-service.127.0.0.1.nip.io:8080"


while getopts 'f:w:' opt; do
    case $opt in
        f)
            participant_name=$OPTARG
            ;;
        w)
            wallet_path=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

if [ -z $participant_name ]; then
    echo "No participant name provided."
    return 1
fi

if [ -z $wallet_path ]; then
    echo "No wallet path provided."
    return 1
fi

echo "Getting access token for $participant_name..."

access_token=$(./get_access_token_oid4vp.sh $data_service_url $OPERATOR_CREDENTIAL operator $wallet_path)

if [ -z $access_token ]; then
    echo "No access token retrieved."
    return 1
fi

echo -e "Operator access token retrieved:\n$access_token"

echo "\nFederating $participant_name..."

# curl --request POST \
#   --url http://scorpio-provider-a.127.0.0.1.nip.io:8080/ngsi-ld/v1/csourceRegistrations \
#   --header 'content-type: application/ld+json' \
#   --header 'user-agent: vscode-restclient' \
#   --data '{"id": "urn:ngsi-ld:ContextSourceRegistration:provider-b","type": "ContextSourceRegistration","information": [{"entities": [{"type": "PhotovoltaicMeasurement"}]}],"endpoint": "http://scorpio-provider-b.127.0.0.1.nip.io:8080","@context": ["https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context-v1.7.jsonld"]}'

curl -s -X POST $data_service_url \
    --header "Authorization: Bearer $access_token" \
    --header 'Content-Type: application/json' \
    --data-raw '{
        "id": "urn:ngsi-ld:ContextSourceRegistration:provider-b",
        "type": "ContextSourceRegistration",
        "information": [
            {
                "entities": [
                    {
                        "type": "PhotovoltaicMeasurement"
                    }
                ]
            }
        ],
        "endpoint": "http://scorpio-provider-b.127.0.0.1.nip.io:8080",
        "@context": ["https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context-v1.7.jsonld"]
    }'


