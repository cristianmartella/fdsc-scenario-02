# Federated Provider

[Return to index](../README.MD)

## Table of Contents

## Introduction

A federated provider (FP) offers "local" context data and services to an upstream federator. The federator aggregates and makes available such information to the other authorized participants of the data space.

To manage local context and to mirror it to the federator, the FP needs a context broker. **Scorpio** is a context broker that natively supports federation through Context Source Registrations and is integrated within the FIWARE Data Space Connector umbrella chart.

In this scenario, the FP authenticates to the federator and acquires the necessary authorization to use (i.e. consume) its data service and, thus, be allowed to create a Context Source Registration. Therefore, the FP can be considered as an hybrid between a Provider and a Consumer, and will include not only a context broker, but also a verifiable credential issuance service (**Keycloak**). This latter service is used to issue verifiable credentials that can be used to authenticate to the federator.

For the sake of simplicity, the FP's data service is made accessible without authentication layer. Nevertheless, it is possible to include it by integrating the necessary PEP, PDP and PAP components.

## Configuration values.yaml

### Data Service

#### Context Broker - Scorpio

```yaml
scorpio:
  enabled: true

  # ingress configuration for the data service (for test purposes only!)
  ingress:
    enabled: true
    hosts:
      - host: scorpio-federated-provider-a.127.0.0.1.nip.io
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

### Verifiable Credentials issuance

#### Keycloak

```yaml
# -- keycloak as issuer of verifiable credentials is required
keycloak:
  ingress:
    enabled: true
    hostname: keycloak-federated-provider-a.127.0.0.1.nip.io
  
  externalDatabase:
    host: postgresql
    database: keycloak
    user: postgres
    existingSecret: database-secret
    existingSecretPasswordKey: postgres-admin-password

  extraEnvVars:
    # import the configured realm
    - name: KEYCLOAK_EXTRA_ARGS
      value: "--import-realm"
    # enable the issuance feature
    - name: KC_FEATURES
      value: "oid4vc-vci"
    # indicates ssl is terminated at the edge
    - name: KC_PROXY
      value: "edge"
    # password for reading the key store connected to the did
    - name: STORE_PASS
      value: test
    # keycloak admin password
    - name: KC_ADMIN_PASSWORD
      valueFrom:
        secretKeyRef:
          name: issuance-secret
          key: keycloak-admin
    # log level for keycloak
    - name: KC_LOG_LEVEL
      value: INFO
    # hostname of keycloak to be set as part of the realm config
    - name: KC_HOSTNAME
      value: keycloak-federated-provider-a.127.0.0.1.nip.io
    # did of the federated provider
    - name: DID
      value: "did:key:<FEDERATED-PROVIDER-KEY>"

  extraVolumeMounts:
    - name: did-material
      mountPath: /did-material
    - name: did-material
      mountPath: "/etc/env"
      readOnly: true
    - name: realms
      mountPath: /opt/bitnami/keycloak/data/import

  extraVolumes:
    - name: did-material
      secret:
        secretName: federated-provider-a-identity
    - name: realms
      configMap:
        name: test-realm-realm

  realm:
    frontendUrl: http://keycloak-federated-provider-a.127.0.0.1.nip.io:8080
    import: true
    name: test-realm
    clientRoles: <CONSUMER-CLIENT-ROLES>

    users: <CONSUMER-USERS>
    clients: <CONSUMER-CLIENTS>
```

#### Keycloak Realm configuration

1. CONSUMER-CLIENT-ROLES

    ```json
    "${DID}": [
        {
            "name": "READER",
            "description": "Is allowed to see offers etc.",
            "clientRole": true
        },
        {
            "name": "OPERATOR",
            "description": "Is allowed to operate clusters.",
            "clientRole": true
        }
    ]
    ```

2. CONSUMER-USERS

    ```json
    {
        "username": "test-user",
        "enabled": true,
        "email": "test@user.org",
        "firstName": "Test",
        "lastName": "Reader",
        "credentials": [
            {
                "type": "password",
                "value": "test"
            }
        ],
        "clientRoles": {
            "${DID}": [
                "OPERATOR"
            ],
            "account": [
                "view-profile",
                "manage-account"
            ]
        },
        "groups": []
    }
    ```

3. CONSUMER-CLIENTS

    ```json
    {
        "clientId": "${DID}",
        "enabled": true,
        "description": "Client to connect test.org",
        "surrogateAuthRequired": false,
        "alwaysDisplayInConsole": false,
        "clientAuthenticatorType": "client-secret",
        "defaultRoles": [],
        "redirectUris": [],
        "webOrigins": [],
        "notBefore": 0,
        "bearerOnly": false,
        "consentRequired": false,
        "standardFlowEnabled": true,
        "implicitFlowEnabled": false,
        "directAccessGrantsEnabled": false,
        "serviceAccountsEnabled": false,
        "publicClient": false,
        "frontchannelLogout": false,
        "protocol": "oid4vc",
        "attributes": {
            "client.secret.creation.time": "1675260539",
            "vc.user-credential.format": "jwt_vc",
            "vc.user-credential.scope": "UserCredential",
            "vc.verifiable-credential.format": "jwt_vc",
            "vc.verifiable-credential.scope": "VerifiableCredential",
            "vc.operator-credential.format": "jwt_vc",
            "vc.operator-credential.scope": "OperatorCredential"
        },
        "protocolMappers": [
            {
                "name": "target-role-mapper",
                "protocol": "oid4vc",
                "protocolMapper": "oid4vc-target-role-mapper",
                "config": {
                    "subjectProperty": "roles",
                    "clientId": "${DID}",
                    "supportedCredentialTypes": "OperatorCredential"
                }
            },
            {
                "name": "context-mapper",
                "protocol": "oid4vc",
                "protocolMapper": "oid4vc-context-mapper",
                "config": {
                    "context": "https://www.w3.org/2018/credentials/v1",
                    "supportedCredentialTypes": "VerifiableCredential,UserCredential,OperatorCredential"
                }
            },
            {
                "name": "email-mapper",
                "protocol": "oid4vc",
                "protocolMapper": "oid4vc-user-attribute-mapper",
                "config": {
                    "subjectProperty": "email",
                    "userAttribute": "email",
                    "supportedCredentialTypes": "UserCredential,OperatorCredential"
                }
            },
            {
                "name": "firstName-mapper",
                "protocol": "oid4vc",
                "protocolMapper": "oid4vc-user-attribute-mapper",
                "config": {
                    "subjectProperty": "firstName",
                    "userAttribute": "firstName",
                    "supportedCredentialTypes": "UserCredential,OperatorCredential"
                }
            },
            {
                "name": "lastName-mapper",
                "protocol": "oid4vc",
                "protocolMapper": "oid4vc-user-attribute-mapper",
                "config": {
                    "subjectProperty": "lastName",
                    "userAttribute": "lastName",
                    "supportedCredentialTypes": "UserCredential,OperatorCredential"
                }
            }
        ],
        "authenticationFlowBindingOverrides": {},
        "fullScopeAllowed": true,
        "nodeReRegistrationTimeout": -1,
        "defaultClientScopes": [],
        "optionalClientScopes": []
    }
    ```

#### Postgresql database for Keycloak

```yaml
# -- database for keycloak as the issuer needs to be registered
postgresql:
  primary:
    persistence:
      enabled: true      
      # use one of the classes provided by your cluster
      storageClass: local-path
```

### Excluded services

#### VCVerifier

No APIs offered, thus no authentication framework required

```yaml
vcverifier:
  enabled: false
```

#### Credentials Config Service

No verifier deployed, thus no supporting services required

```yaml
credentials-config-service:
  enabled: false
```

#### Trusted Issuers List

No verifier deployed, thus no supporting services required

```yaml
trusted-issuers-list:
  enabled: false
```

#### MySql database for TIL

No trusted-issuers-list deployed, thus no db for it required

```yaml
mysql:
  enabled: false
```

#### ODRL-PAP

No apis offered, thus no policy administration required

```yaml
odrl-pap:
  enabled: false
```

#### APISIX - PEP

No apis offered, thus no policy enforcement required

```yaml
apisix:
  enabled: false
```

#### TMForum APIs to support contracting

Nothing offered, thus no api to offer something required

```yaml
tm-forum-api:
  enabled: false
```

#### Contract Management

Nothing offered, thus no contracts need to be managed

```yaml
contract-management:
  enabled: false
```

## Deployment of the Federated Provider

### Step-by-step procedure

#### 1. Create an identity for the federated provider

1.1 Create a folder for the federated provider identity material

```bash
cd federated-provider-a
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

#### 2. Replace CONSUMER_DID in values.yaml with generated DID

#### 3. Create 'federated-provider-a' namespace

```bash
kubectl create namespace federated-provider-a
```

#### 4. Deploy the key into the cluster

```bash
kubectl create secret generic federated-provider-a-identity --from-file=identity/cert.pfx -n federated-provider-a
```

#### 5. Install the federated provider

```bash
helm install federated-provider-a-dsc data-space-connector/data-space-connector --version 7.17.0 -f values.yaml --namespace=federated-provider-a

watch kubectl get pods -n federated-provider-a
```

The issuer can be accessed at: <http://keycloak-federated-provider-a.127.0.0.1.nip.io:8080/realms/test-realm/account/oid4vci>

### Quick deployment

Follow the steps reported in this [guide](../SCRIPTS.MD).

### Additional configuration

#### Register the federated provider at the Trust Anchor

```bash
curl -X POST http://til.127.0.0.1.nip.io:8080/issuer \
--header 'Content-Type: application/json' \
--data '{
    "did": "did:key:<FEDERATED-PROVIDER-KEY>",
    "credentials": []
}'
```

## Uninstall

```bash
helm uninstall federated-provider-a-dsc -n federated-provider-a
```

[Return to index](../README.MD)
