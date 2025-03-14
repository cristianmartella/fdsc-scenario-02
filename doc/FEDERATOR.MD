# Federator

[Return to index](../README.MD)

## Table of Contents

- [Federator](#federator)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Configuration values.yaml](#configuration-valuesyaml)
    - [Authentication](#authentication)
      - [VCVerifier](#vcverifier)
      - [Credentials Config Service](#credentials-config-service)
      - [Trusted Issuers List](#trusted-issuers-list)
      - [MySql database for TIL](#mysql-database-for-til)
    - [Authorization](#authorization)
      - [APISIX - PEP](#apisix---pep)
        - [Routes configuration](#routes-configuration)
      - [Open Policy Agent (OPA) - PDP](#open-policy-agent-opa---pdp)
      - [ODRL-PAP](#odrl-pap)
      - [Postgres database for ODRL-PAP](#postgres-database-for-odrl-pap)
    - [Data Service](#data-service)
      - [Context Broker - Scorpio](#context-broker---scorpio)
      - [Postgis database for Scorpio](#postgis-database-for-scorpio)
    - [TMForum API](#tmforum-api)
      - [TMForum APIs to support contracting](#tmforum-apis-to-support-contracting)
      - [Contract Management](#contract-management)
    - [Data Space Config](#data-space-config)
  - [Excluded services](#excluded-services)
    - [Keycloak](#keycloak)
  - [Deployment of the Federator](#deployment-of-the-federator)
    - [Step-by-step procedure](#step-by-step-procedure)
      - [1. Create an identity for the federator](#1-create-an-identity-for-the-federator)
      - [2. Replace FEDERATOR-KEY in values.yaml with generated DID](#2-replace-federator-key-in-valuesyaml-with-generated-did)
      - [3. Create 'federator' namespace](#3-create-federator-namespace)
      - [4. Deploy the key into the cluster](#4-deploy-the-key-into-the-cluster)
      - [5. Install the federator](#5-install-the-federator)
    - [Quick deployment](#quick-deployment)
    - [Additional configuration](#additional-configuration)
      - [Register the federator at the Trust Anchor](#register-the-federator-at-the-trust-anchor)
      - [Policies](#policies)
        - [1. Allow any participant to read entities of a given type (e.g _PhotovoltaicMeasurement_)](#1-allow-any-participant-to-read-entities-of-a-given-type-eg-photovoltaicmeasurement)
        - [2. Allow the creation of context source registrations](#2-allow-the-creation-of-context-source-registrations)
  - [Uninstall](#uninstall)

## Introduction

In an inclusive federated FDSC context, the federator instance keeps track of the context source registrations associated with the corresponding federated providers. Essentially, for a given entity it is possible to combine different bits of information provided by multiple local context sources and output a comprehensive representation of the same entity that ultimately integrates such contributes.

To this end, the federator instance must include a **data service**, namely a context broker, to manage the context source registrations to the federated data providers. In particular, the FDSC encourages the usage of **Scorpio**, which comes with native support for federation through context source registrations and is NGSI-LD compliant.

In this demo scenario, the federator includes data entities and attributes provided by trusted and authorized providers. Hence, the federator recipe must also include the Authentication and Authorization services stack. In particular, **Authentication** services are registered and connected to the **Verifiable Data Registry** and include:

- A **Verifiable Credential Verifier (VCVerifier)** that provides OID4VP endpoints
- An _internal_ **Trusted Issuers List** (which differs from the global one managed by the Verifiable Data Registry) and a **Credentials Config Service**, to provide information about issuers and credentials for the verifier.
- **MySql** acts as Storage Backend (can be a shared instance).

On the other hand, **Authorization** services enforce and manage policies through a combination of **Policy Enforcement Point (PEP)**, **Policy Decision Point (PDP)** and **Policy Administration Point (PAP)**. In particular:

- PEP and central entrypoint - **APISIX Gateway**: (a) routes _well-known/openid-configuration_ from the Verifier, (b) routes _well-known/data-space-configuration_ from a static fileserver and (c) checks _JWT_ at the Verifier.
- PDP - **Open Policy Agent**, which is deployed as a sidecar of APISIX for better performance.
- PAP - **ODRL-PAP** for managing policies. In this case, **Postgresql** is used as storage backend.
- Data Service - **Scorpio**: it is NGSI-LD compliant and requires **Postgis** as storage backend.

Optionally, **Data marketplace and contracting** services are offered through **TMForum API** and **Contract Management**.

Eventually, **Data Space Config** acts as well-known endpoint, and allows to configure of the data space by specifying supported data models, authentication protocols, etc.

## Configuration values.yaml

### Authentication

#### VCVerifier

```yaml
# -- Verifiable Credentials Verifier
vcverifier:
  # make the verifier publicly accessible
  ingress:
    enabled: true
    hosts:
      - host: federator-verifier.127.0.0.1.nip.io
        paths:
          - "/"
  deployment:
    logging:
      level: DEBUG
    verifier:
      # address of the trust anchor
      tirAddress: http://tir.127.0.0.1.nip.io:8080/
      did: did:key:<FEDERATOR-KEY>
    # public address of the verifier, to be provided as oid-config
    server:
      host: http://federator-verifier.127.0.0.1.nip.io:8080
    # access to the internal credentials-config-service
    configRepo:
      configEndpoint: http://credentials-config-service:8080
```

#### Credentials Config Service

```yaml
# -- Credentials Config Service
credentials-config-service:
  enabled: true
```

#### Trusted Issuers List

```yaml
# -- Trusted Issuers List
trusted-issuers-list:
  # only open for demo purposes
  ingress:
    til:
      enabled: true
      hosts:
        - host: til-federator.127.0.0.1.nip.io
          paths:
            - /
```

#### MySql database for TIL

```yaml
# -- MySql database for TIL
mysql:
  primary:
    persistence:
      enabled: true      
      # use one of the classes provided by your cluster
      storageClass: local-path
```

### Authorization

#### APISIX - PEP

```yaml
apisix:
  image:
    debug: true
  dataPlane:
    # -- configure the ingress to the data service
    ingress:
      enabled: true
      hostname: mp-data-service-federator.127.0.0.1.nip.io
      # -- configure the ingress to the tmf-api
      extraHosts:
        - name: mp-tmf-api-federator.127.0.0.1.nip.io
          path: /
  catchAllRoute:
    enabled: false
  routes: |-
    <ROUTES>
```

Configuration of ROUTES is broken down in the following.

##### Routes configuration

Route to answer all openid-config requests to the data service from within the verifier

```yaml
- uri: /.well-known/openid-configuration
  host: mp-data-service-federator.127.0.0.1.nip.io
  upstream:
    nodes:
      verifier:3000: 1
    type: roundrobin
  plugins:
    proxy-rewrite:
        uri: /services/data-service/.well-known/openid-configuration
```

Route to provider data-space-configuration

```yaml
- uri: /.well-known/data-space-configuration
  host: mp-data-service-federator.127.0.0.1.nip.io
  upstream:
    nodes:
      dsconfig:3002: 1
    type: roundrobin
  plugins:
    proxy-rewrite:
      uri: /.well-known/data-space-configuration/data-space-configuration.json
    response-rewrite:
      headers:
        set:
          content-type: application/json
```

Central route to the data service

```yaml
- uri: /*
  host: mp-data-service-federator.127.0.0.1.nip.io
  upstream:
    nodes:
      data-service-scorpio:9090: 1
    type: roundrobin
  plugins:
    # verify the jwt at the verifiers endpoint
    openid-connect:
      bearer_only: true
      use_jwks: true
      client_id: data-service
      client_secret: unused
      ssl_verify: false
      discovery: http://verifier:3000/services/data-service/.well-known/openid-configuration
    # request decisions at opa
    opa:
      host: "http://localhost:8181"
      policy: policy/main
      with_body: true
```

Route to answer all openid-config requests to the TMForum API from within the verifier

```yaml
- uri: /.well-known/openid-configuration
  host: mp-tmf-api-federator.127.0.0.1.nip.io
  upstream:
    nodes:
      verifier:3000: 1
    type: roundrobin
  plugins:
    proxy-rewrite:
      uri: /services/tmf-api/.well-known/openid-configuration
```

Central route to the TMForum API

```yaml
- uri: /*
  host: mp-tmf-api-federator.127.0.0.1.nip.io
  upstream:
    nodes:
      tm-forum-api:8080: 1
    type: roundrobin
  plugins:
    openid-connect:
      bearer_only: true
      use_jwks: true
      client_id: contract-management
      client_secret: unused
      ssl_verify: false
      discovery: http://verifier:3000/services/tmf-api/.well-known/openid-configuration
    opa:
      host: "http://localhost:8181"
      policy: policy/main
      with_body: true
```

#### Open Policy Agent (OPA) - PDP

The OPA is deployed as part of the connector (in particular, as sidecar of APISIX), fulfillig the role of PDP.

```yaml
opa:
  # -- should an opa sidecar be deployed to apisix
  enabled: true
```

#### ODRL-PAP

```yaml
# policy administration point
odrl-pap:
  additonalEnvVars:
    # needs to know the federator's identity to 
    - name: GENERAL_ORGANIZATION_DID
      value: did:key:<FEDERATOR-KEY>
  ingress:
    enabled: true
    hosts:
      - host: pap-federator.127.0.0.1.nip.io
        paths:
          - "/"
```

#### Postgres database for ODRL-PAP

```yaml
postgresql:
  primary:
    persistence:
      enabled: true      
      # use one of the classes provided by your cluster
      storageClass: local-path
```

### Data Service

#### Context Broker - Scorpio

```yaml
scorpio:
  enabled: true

  # ingress configuration for the data service (for test purposes only!)
  ingress:
    enabled: true
    hosts:
      - host: scorpio-federator.127.0.0.1.nip.io
        paths:
          - "/"

  # configuration for the dataservice at the credentials-config-service
  ccs:
    defaultOidcScope:
      name: default
    oidcScopes:
      default:
        - type: UserCredential
          trustedParticipantsLists:
            - http://tir.trust-anchor.svc.cluster.local:8080
          trustedIssuersLists:
            - http://trusted-issuers-list:8080
      operator:
        - type: OperatorCredential
          trustedParticipantsLists:
            - http://tir.trust-anchor.svc.cluster.local:8080
          trustedIssuersLists:
            - http://trusted-issuers-list:8080
```

#### Postgis database for Scorpio

```yaml
postgis:
  primary:
    persistence:
      enabled: true      
      # use one of the classes provided by your cluster
      storageClass: local-path
```

### TMForum API

#### TMForum APIs to support contracting

```yaml
# tmforum apis to support contracting
tm-forum-api:
  registration:
    ccs:
      defaultOidcScope:
        credentialType: UserCredential
        trustedParticipantsLists: http://tir.trust-anchor.svc.cluster.local:8080
  ingress:
    enabled: true
    hosts:
      - host: tm-forum-api.127.0.0.1.nip.io
        paths:
          - /
```

#### Contract Management

```yaml
# contract management component and the credential type it should register for a bought service
contract-management:
  enabled: true
  til:
    credentialType: OperatorCredential
```

### Data Space Config

```yaml
# serves configuration of the dataspace
dataSpaceConfig:
  enabled: true
  
  ## Defaults
  serviceType: ClusterIP
  port: 3002
  supportedModels:
    - "https://raw.githubusercontent.com/smart-data-models/dataModel.Consumption/master/ConsumptionPoint/schema.json"
    - "https://raw.githubusercontent.com/smart-data-models/dataModel.Consumption/master/ConsumptionCost/schema.json"
    - "https://github.com/smart-data-models/dataModel.GreenEnergy/blob/master/PhotovoltaicMeasurement/schema.json"
    - "https://github.com/smart-data-models/dataModel.GreenEnergy/blob/master/PhotovoltaicDevice/schema.json"
  supportedProtocols:
    - http
    - https
  authenticationProtocols:
    - oid4vp
```

## Excluded services

### Keycloak

Credentials issuance is not required in this case.

```yaml
keycloak:
  enabled: false
```

## Deployment of the Federator

### Step-by-step procedure

#### 1. Create an identity for the federator

1.1 Create a folder for the federator identity material

```bash
cd federator
mkdir identity
```

1.2 Generate the **private key** - do not get confused about the curve: openssl uses the name `prime256v1` for `secp256r1`(as defined by P-256)

```bash
openssl ecparam -name prime256v1 -genkey -noout -out identity/private-key.pem
```

1.3 Generate corresponding **public key**

```bash
openssl ec -in identity/private-key.pem -pubout -out identity/public-key.pem
```

1.4 Create a **(self-signed) certificate**

```bash
openssl req -new -x509 -key identity/private-key.pem -out identity/cert.pem -days 360
```

1.5 Export the **keystore**

Tip: use `test` as keystore password.

```bash
openssl pkcs12 -export -inkey identity/private-key.pem -in identity/cert.pem -out identity/cert.pfx -name didPrivateKey
```

1.6 Check the contents

```bash
keytool -v -keystore identity/cert.pfx -list -alias didPrivateKey
```

1.7 Generate **DID** from the keystore

```bash
wget https://github.com/wistefan/did-helper/releases/download/0.1.1/did-helper

chmod +x did-helper

./did-helper -keystorePath ./identity/cert.pfx -keystorePassword=test | grep -o 'did:key:.*' > identity/did.key
```

#### 2. Replace FEDERATOR-KEY in values.yaml with generated DID

#### 3. Create 'federator' namespace

```bash
kubectl create namespace federator
```

#### 4. Deploy the key into the cluster

```bash
kubectl create secret generic federator-identity --from-file=identity/cert.pfx -n federator
```

#### 5. Install the federator

```bash
helm install federator-dsc data-space-connector/data-space-connector --version 7.22.7 -f values.yaml --namespace=federator

watch kubectl get pods -n federator
```

### Quick deployment

Follow the steps reported in this [guide](../SCRIPTS.MD).

### Additional configuration

#### Register the federator at the Trust Anchor

```bash
curl -X POST http://til.127.0.0.1.nip.io:8080/issuer \
--header 'Content-Type: application/json' \
--data '{
    "did": "did:key:<FEDERATOR-KEY>",
    "credentials": []
}'
```

#### Policies

For the purposes of this simple demo scenario, any data provider can participate to the federation. Thus, an user that operates on behalf of a federated data provider can register a context source registration at the federator and/or interact with the federator to fetch entities of a given type. For the sake of simplicity, this scenario does not implement marketplace operations, and every operation can be performed by authenticated users via their user verifiable credentials. Nevertheless, the configuration of contract management paradigms to allow advanced operations and policies is directly supported by this configuration and requires only minimal extra steps.

##### 1. Allow any participant to read entities of a given type (e.g _PhotovoltaicMeasurement_)

```bash
curl -X POST http://pap-federator.127.0.0.1.nip.io:8080/policy \
  -H 'content-type: application/json' \
  -H 'user-agent: vscode-restclient' \
  -d '
    {
      "@context": {
        "dc":"http://purl.org/dc/elements/1.1/",
        "dct":"http://purl.org/dc/terms/",
        "owl":"http://www.w3.org/2002/07/owl#",
        "odrl":"http://www.w3.org/ns/odrl/2/",
        "rdfs":"http://www.w3.org/2000/01/rdf-schema#",
        "skos":"http://www.w3.org/2004/02/skos/core#"
      },
      "@id":"https://mp-operation.org/policy/common/type",
      "@type":"odrl:Policy",
      "odrl:permission": {
        "odrl:assigner": {
          "@id":"https://www.mp-operation.org/"
        },
        "odrl:target": {
          "@type":"odrl:AssetCollection",
          "odrl:source":"urn:asset",
          "odrl:refinement": [
            {
              "@type":"odrl:Constraint",
              "odrl:leftOperand":"ngsi-ld:entityType",
              "odrl:operator": {
                "@id":"odrl:eq"
              },
              "odrl:rightOperand":"PhotovoltaicMeasurement"
            }
          ]
        },
        "odrl:assignee": {
          "@id":"vc:any"
        },
        "odrl:action": {
          "@id":"odrl:read"
        }
      }
    }'
```

##### 2. Allow the creation of context source registrations

```bash
curl --X POST http://pap-federator.127.0.0.1.nip.io:8080/policy \
  -H 'content-type: application/json' \
  -H 'user-agent: vscode-restclient' \
  -d '
    {
      "@context": {
        "dc": "http://purl.org/dc/elements/1.1/",
        "dct": "http://purl.org/dc/terms/",
        "owl": "http://www.w3.org/2002/07/owl#",
        "odrl": "http://www.w3.org/ns/odrl/2/",
        "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
        "skos": "http://www.w3.org/2004/02/skos/core#"
      },
      "@id": "https://mp-operation.org/policy/common/type",
      "@type": "odrl:Policy",
      "odrl:permission": {
        "odrl:assigner": {
          "@id": "https://www.mp-operation.org/"
        },
        "odrl:target": {
          "@type": "odrl:AssetCollection",
          "odrl:source": "urn:asset",
          "odrl:refinement": [
            {
              "@type": "odrl:Constraint",
              "odrl:leftOperand": "ngsi-ld:entityType",
              "odrl:operator": {
                  "@id": "odrl:eq"
              },
              "odrl:rightOperand": "ContextSourceRegistration"
            }
          ]
        },
        "odrl:assignee": {
          "@id": "vc:any"
        },
        "odrl:action": {
          "@id": "odrl:use"
        }
      }
    }'
```

## Uninstall

```bash
helm uninstall federator-dsc -n federator
```

[Return to index](../README.MD)
