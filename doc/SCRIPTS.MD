# Scripts usage guide

[Return to index](../README.MD)

## Table of Contents

- [Scripts usage guide](#scripts-usage-guide)
  - [Table of Contents](#table-of-contents)

## k3s cluster deployment

Run the script `01.deploy_cluster.sh` performs all the operations required to configure and deploy a base k3s cluster.

```bash
[source] ./01.deploy_cluster.sh
```

The script can be sourced to export the KUBECONFIG variable automatically.

```bash
source ./01.deploy_cluster.sh
```

Alternatively, it is possible to run the script and export the KUBECONFIG variable manually.

```bash
./01.deploy_cluster.sh

export KUBECONFIG=$(builtin cd $(pwd)/..; pwd)/base-cluster/target/k3s.yaml
```

## Trust Anchor deployment

Run the script `02.deploy_trust_anchor.sh`.

```bash
./02.deploy_trust_anchor.sh
```

## Provider deployment

Run the script `03.deploy_provider.sh`.

```bash
./03.deploy_provider.sh [-p path/to/provider/ -c path/to/certificate/details/]
```

With the option `-p` it is possible to specify the path to the privider folder as an argument. This option is facultative and, if omitted, the path defaults to `../provider`.
The script infers the name of the provider from its folder's basename. This name is used in the deployment and for the creation of the corresponding namespace.

The argument following the option `-c` is optional. If passed, it allows the script to generate a certificate non interactively using the information included in a configuration file, whose content matches the following template:

```conf
COUNTRY=""    # 2 letter country-code (e.g DE)
STATE=""      # state or province name
LOCALITY=""   # Locality Name (e.g. city)
ORGNAME=""    # Organization Name (eg, company)
ORGUNIT=""    # Organizational Unit Name (eg. section)
COMMONNAME="" # Common Name
```

If it is not passed, the script proceeds non interactively to generate a certificate without specifying any information.

### Example: federator certificate.conf

The file `federator/.certificate.conf` contains the following configuration:

```conf
COUNTRY="DE"
STATE="Saxony"
LOCALITY="Dresden"
ORGNAME="M&P Operations Inc."
ORGUNIT="Federator"
COMMONNAME="www.mp-operation.org"
```

Run the script `03.deploy_provider.sh` with the proper path to the conf file.

```bash
./03.deploy_provider.sh -c ../provider/.certificate.conf
```

### Example: federated provider certificate.conf

The file `federated-provider-a/.certificate.conf` contains the following configuration:

```conf
COUNTRY="DE"
STATE="Saxony"
LOCALITY="Dresden"
ORGNAME="M&P Operations Inc."
ORGUNIT="Provider"
COMMONNAME="www.mp-operation.org"
```

Run the script `03.deploy_provider.sh` with the proper path to the conf file.

```bash
./03.deploy_provider.sh -c ../federated-provider-a/.certificate.conf
```

## Wallet identity creation

By running the script `05.create_wallet.sh`, it is possible to create a wallet for the user that will interact with the federator on behalf of the federated provider (i.e. a consumer of federator's data service).

```bash
[source] ./05.create_wallet.sh [-p wallet-path -n vc-issuer-name]
```

With the option `-p` it is possible to specify the root directory where the wallet will be created (defaults to *PROJECT_HOME/wallet-identity*).

The option `-n` allows to indicate the name of the verifiable credential issuer, i.e. the participant on behalf of which the wallet owner operates (defaults to `consumer`).

The script supports the issuance of verifiable credentials for **USER** and **OPERATOR** scopes, according to the scopes defined at *scorpio/ccs/oidcScopes* in provider's values.yaml.

The script can be sourced to export the issued verified credentials as the `USER_CREDENTIAL` and `OPERATOR_CREDENTIAL` environment variables, or executed normally. In the latter case, the export commands are returned on the console.

The resulting token can then be embedded as bearer token in the authorization header of the HTTP requests to the data provider.

### Generating verifiable credentials

A required argument is the verifiable credential of the user that intends to act on behalf of the consumer.

To get the **UserCredential**:

```bash
export USER_CREDENTIAL=$(./get_credential_for_consumer.sh http://keycloak-federated-provider-a.127.0.0.1.nip.io:8080 user-credential); echo ${USER_CREDENTIAL}
```

Similarly, to get the **OperatorCredential**:

```bash
export OPERATOR_CREDENTIAL=$(./get_credential_for_consumer.sh http://keycloak-federated-provider-a.127.0.0.1.nip.io:8080 operator-credential); echo ${OPERATOR_CREDENTIAL}
```

## Federate a participant


## Cleanup script

Run the script `00.cleanup.sh` to uninstall the deployed pods, remove the namespaces and delete the persistent volumes.

```bash
[source] ./00.cleanup.sh [-p -f]
```

With the `-p` flag, following the uninstallation of the deployed pods, the script deletes the persistent volumes.

With the `-f` flag the script forces the uninstallation of the cluster, by removing the `k3s-maven-plugin` docker container and the corresponding volumes.

Additionally, the script can be sourced to restore the default system KUBECONFIG, if exists. If it is not sourced, the script will output the export command with the default path to KUBECONFIG for the user to prompt it.

To keep track of the deployed participants, deployment scripts (`02.deploy_trust_anchor.sh` and `03.deploy_provider.sh`) store their names on a temporary file called `.participants.tmp`. This file is then consulted by the cleanup script to uninstall the corresponding deployments.

[Return to index](./doc/README.MD)
