# Federation workflow

[Return to index](../README.MD)

This section describes the workflow to federate a data provider and consult its entities from the federator.

## Table of Contents

- [Federation workflow](#federation-workflow)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Workflow](#workflow)
    - [1. Create an entity on the candidate FP](#1-create-an-entity-on-the-candidate-fp)
    - [2. Obtain a token for the candidate FP](#2-obtain-a-token-for-the-candidate-fp)
    - [3. Create a Context Source Registration](#3-create-a-context-source-registration)
    - [4. Consult the FP entity from the federator](#4-consult-the-fp-entity-from-the-federator)

## Introduction

The procedure to create a federation of participants and articulates into four steps:

1. create an entity on the candidate federated provider (FP) and verify that it is not visible to the federator
2. obtain a token for the candidate FP
3. create an authorized Context Source Registration
4. verify that the entity can be now consulted from the federator

Each of these steps will be discussed individually in the following.

## Workflow

### 1. Create an entity on the candidate FP

Since the candidate FP's context broker ingress is exposed (for the sake of simplicity), the creation of an entity is merely a matter of interacting with its endpoint:

```bash
curl -s -X POST 'http://scorpio-federated-provider-a.127.0.0.1.nip.io:8080/ngsi-ld/v1/entities' \
  -H 'content-type: application/ld+json' \
  -d '
  {
    "id": "urn:ngsi-ld:PhotovoltaicMeasurement:fms-1",
    "type": "PhotovoltaicMeasurement",
    "name": {
        "type": "Property",
        "value": "SmartPV Station 1"
    },
    "nominalPeakPowerGeneration": {
        "type": "Property",
        "value": "95"
    },
    "@context": ["https://raw.githubusercontent.com/smart-data-models/dataModel.GreenEnergy/master/context.jsonld"]
  }'
```

Once the entity has been created, it is possible to verify that it is visible in the candidate FP's data service:

```bash
curl -X GET 'http://scorpio-federated-provider-a.127.0.0.1.nip.io:8080/ngsi-ld/v1/entities/urn:ngsi-ld:PhotovoltaicMeasurement:fms-1' \
  -H 'accept: application/json'
```

But not from the federator:

```bash
curl -X GET 'http://scorpio-federator.127.0.0.1.nip.io:8080/ngsi-ld/v1/entities/urn:ngsi-ld:PhotovoltaicMeasurement:fms-1' \
  -H 'accept: application/json'
```

### 2. Obtain a token for the candidate FP

The interaction with the federator data service is protected by an authentication and authorization layer. Therefore, a participant that wants to interact with it must first obrain an access token.

In this case, the candidate FP can request an access token for user verifiable credentials. This simple scenario aims to demonstrate how it is possible to set up a federation of participants, so the process is simplified and any possessor of user verifiable credentials is authorized to obtain an access token.

To request a token, first a user credential must be issued at the candidate FP's VC issuer:

```bash
export USER_CREDENTIAL=$(./get_credential_for_consumer.sh http://keycloak-federated-provider-a.127.0.0.1.nip.io:8080 user-credential); echo ${USER_CREDENTIAL}
```

Then, the user access token can be requested at the federator data service:

```bash
export USER_TOKEN=$(./get_access_token_oid4vp.sh http://mp-data-service-federator.127.0.0.1.nip.io:8080 $USER_CREDENTIAL user ../wallet); echo ${USER_TOKEN}
```

This token must be embedded to any request sent to the federator data service, including the creation and management of Context Source Registrations.

### 3. Create a Context Source Registration

The creation of a Context Source Registration allows the federation of participants to take place.

```bash
curl -s -X POST 'http://mp-data-service-federator.127.0.0.1.nip.io:8080/ngsi-ld/v1/csourceRegistrations' \
    -H "Authorization: Bearer $USER_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "id": "urn:ngsi-ld:ContextSourceRegistration:csr-federated-participant-a",
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
        "endpoint": "http://scorpio-federated-participant-a.127.0.0.1.nip.io:8080",
        "@context": ["https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context-v1.7.jsonld"]
    }'
```

The payload of the request contains information on the entities that will be "mirrored" to the federator data service (in this case "PhotovoltaicMeasurement" entities), the FP data service endpoint. More advanced configurations are possible, enabling fine grained federation rules to be set up. The full documentation can be found [here](https://www.etsi.org/deliver/etsi_gs/CIM/001_099/009/01.06.01_60/gs_CIM009v010601p.pdf) (check clause 5.2.9 for CSourceRegistration API Operation Definition and clause 5.9 for Context Source Registration documentation).

### 4. Consult the FP entity from the federator

The last step is to verify that the entity previously created on the FP can be consulted on the federator as a result of the active Context Source Resistration.

```bash
curl -X GET 'http://mp-data-service-federator.127.0.0.1.nip.io:8080/ngsi-ld/v1/entities/urn:ngsi-ld:PhotovoltaicMeasurement:fms-1' \
  -H 'Authorization: Bearer $USER_TOKEN'
  -H 'accept: application/json'
```

The entity is successfully returned.

Changes on the FP entity will also be visible from the federator. To verify it, update the entity:

```bash
curl -s -X PUT  'http://scorpio-federated-provider-a.127.0.0.1.nip.io:8080/ngsi-ld/v1/entities/urn:ngsi-ld:PhotovoltaicMeasurement:fms-1' \
  -H 'content-type: application/ld+json' \
  -d '
  {
    "type": "PhotovoltaicMeasurement",
    "name": {
        "type": "Property",
        "value": "SmartPV Station 1"
    },
    "nominalPeakPowerGeneration": {
        "type": "Property",
        "value": "100"
    },
    "@context": ["https://raw.githubusercontent.com/smart-data-models/dataModel.GreenEnergy/master/context.jsonld"]
  }'
```

And then repeat the API call to retrieve it from the federator.

[Return to index](../README.MD)
