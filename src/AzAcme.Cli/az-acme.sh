#!/bin/sh

SCRIPT_NAME=$0
AZACME=`dirname $(realpath $SCRIPT_NAME)`/az-acme.dll
SERVER=https://acme-v02.api.letsencrypt.org/directory

[ "'$1'" != "''" ] || { 
  echo 'Shell wrapper for az-acme-cli utility (https://github.com/az-acme/az-acme-cli).'
  echo No command specified.
  echo Run '"'$SCRIPT_NAME help'"' for help.
  exit 1
}

COMMAND=$1
shift 1

if [ "$COMMAND" = "help" ]
then
  echo 'Shell wrapper for az-acme-cli utility (https://github.com/az-acme/az-acme-cli).'
  echo
  if [ "'$1'" = "''" ]
  then
    echo Supported commands are '"register"' and '"order"', so use: 
    echo '  '$SCRIPT_NAME help '(register|order)'
  elif [ "$1" = "register" ]
  then
    echo Usage:
    echo '  '$SCRIPT_NAME' register [options]'
    echo
    echo 'Performs registration in Lets Encrypt.'
    echo
    echo 'Arguments may be set as command line options or as environment variables:'
    echo
    echo 'Option                    | Variable              | Description'
    echo '--------------------------|-----------------------|-----------------------------------------------------------------'
    echo '--tenant-id <tenant-id>   | AZURE_TENANT_ID       | Azure App registration Directory (tenant) ID.'
    echo '                          |                       |   e.g.: 0f6865ba-f57b-477c-8e90-f39f7639bd17'
    echo '--client-id <client-id>   | AZURE_CLIENT_ID       | Azure App registration Application (client) ID.'
    echo '                          |                       |   e.g.: cd809933-3dcc-442a-8edc-9c04ca1db624'
    echo '--client-secret <secret>  | AZURE_CLIENT_SECRET   | Azure App registration secret.'
    echo '                          |                       |   e.g.: S9y8Q~ARGixGQs_T~P-G2taOfQy41mrirjAc9bKb'
    echo '--kv <keyvault-name>      | AZURE_KEY_VAULT       | Azure KeyVault name.'
    echo '                          |                       |   e.g.: my-keyvault'
    echo '--secret <secret-name>    | AZACME_SECRET         | Azure KeyVault secret name used to store ACME registration data.'
    echo '                          |                       |   e.g.: cert-updater-secret'
    echo '                          |                       |   The default value "az-acme" will be used if not specified.'
    echo '--email <email>           | AZACME_EMAIL          | Email address used for ACME registration.'
    echo '                          |                       |   e.g.: admin@example.com'
    echo '--force-registration      |                       | Rewrites existing registration if any.'
  elif [ "$1" = "order" ]
  then
    echo Usage:
    echo '  '$SCRIPT_NAME' order [options]'
    echo
    echo 'Updates certificate stored in Azure KeyVault if update is required.'
    echo
    echo 'Arguments may be set as command line options or as environment variables:'
    echo
    echo 'Option                                 | Variable              | Description'
    echo '---------------------------------------|-----------------------|-----------------------------------------------------------------'
    echo '--tenant-id <tenant-id>                | AZURE_TENANT_ID       | Azure App registration Directory (tenant) ID.'
    echo '                                       |                       |   e.g.: 0f6865ba-f57b-477c-8e90-f39f7639bd17'
    echo '--client-id <client_id>                | AZURE_CLIENT_ID       | Azure App registration Application (client) ID.'
    echo '                                       |                       |   e.g.: cd809933-3dcc-442a-8edc-9c04ca1db624'
    echo '--client-secret <secret>               | AZURE_CLIENT_SECRET   | Azure App registration secret.'
    echo '                                       |                       |   e.g.: S9y8Q~ARGixGQs_T~P-G2taOfQy41mrirjAc9bKb'
    echo '--kv <keyvault-name>                   | AZURE_KEY_VAULT       | Azure KeyVault name.'
    echo '                                       |                       |   e.g.: my-keyvault'
    echo '--subscription <subscription-id>       | AZURE_SUBSCRIPTION_ID | Azure Subscription ID where target DNS zone is placed.'
    echo '                                       |                       |   e.g.: 8d743309-fceb-4302-ae49-1386d5cafed6'
    echo '--resource-group <resource-group-name> | AZURE_RESOURCE_GROUP  | Azure Resource Group name where target DNS zone is placed.'
    echo '                                       |                       |   e.g.: my-resource-group'
    echo '--secret <secret_name>                 | AZACME_SECRET         | Azure KeyVault secret name used to store ACME registration data.'
    echo '                                       |                       |   e.g.: cert-updater-secret'
    echo '                                       |                       |   The default value "az-acme" will be used if not specified.'
    echo '--dns-zone <dns-zone>                  | AZACME_DNS_ZONE       | Target DNS zone.'
    echo '                                       |                       |   e.g.: mydomain.com'
    echo '--cert-subject <cert-subject>          | AZACME_CERT_SUBJECT   | Issuing certificate subject (domain name).'
    echo '                                       |                       |   e.g.: prod.mydomain.com'
    echo '                                       |                       |   Target DNS zone will be used if not specified.'
    echo '--cert-name <cert-name>                | AZACME_CERT_NAME      | Email address used for ACME registration.'
    echo '                                       |                       |   e.g.: cert-prod-https'
    echo '                                       |                       |   Certificate subject based name will be used if not specified'
    echo '                                       |                       |   (with all dots replaced with hyphens).'
  else
    echo Invalid command specified: $1
    echo Supported commands are '"register"' and '"order"' so use: $SCRIPT_NAME help '(register|order)'
    exit 1
  fi
  exit 0
elif [ "$COMMAND" = "register" ]
then
  FORCE_REGISTRATION=""

  OPTS=$(getopt -l "tenant-id:,client-id:,client-secret:,kv:,secret:,email:,force-registration" -- "" $@)
  [ $? = 0 ] || {
      echo Incorrect options provided
      exit 1
  }

  eval set -- "$OPTS"

  while :
  do
    case "$1" in
      --tenant-id )
        export AZURE_TENANT_ID="$2"
        shift 2
        ;;
      --client-id )
        export AZURE_CLIENT_ID="$2"
        shift 2
        ;;
      --client-secret )
        export AZURE_CLIENT_SECRET="$2"
        shift 2
        ;;
      --kv )
        AZURE_KEY_VAULT="$2"
        shift 2
        ;;
      --secret )
        AZACME_SECRET="$2"
        shift 2
        ;;
      --email )
        AZACME_EMAIL="$2"
        shift 2
        ;;
      --force-registration )
        FORCE_REGISTRATION="--force-registration"
        shift 1
        ;;
      --)
        shift;
        break
        ;;
      *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
  done
  
  HAS_ERRORS=0
  [ "$AZURE_TENANT_ID" != "" ] || {
    echo No Azure App registration Directory '(tenant)' ID provided, use '"--tenant-id <tenant-id>"' or set AZURE_TENANT_ID variable.
    HAS_ERRORS=1
  }
  [ "$AZURE_CLIENT_ID" != "" ] || {
    echo No Azure App registration Application '(client)' ID provided, use '"--client-id <client-id>"' or set AZURE_CLIENT_ID variable.
    HAS_ERRORS=1
  }
  [ "$AZURE_CLIENT_SECRET" != "" ] || {
    echo No Azure App registration secret provided, use '"--client-secret <secret>"' or set AZURE_CLIENT_SECRET variable.
    HAS_ERRORS=1
  }
  [ "$AZURE_KEY_VAULT" != "" ] || {
    echo No Azure KeyVault name provided, use '"--kv <keyvault-name>"' or set AZURE_KEY_VAULT variable.
    HAS_ERRORS=1
  }
  [ "$AZACME_SECRET" = "" ] && {
    AZACME_SECRET=az-acme
    echo No KeyVault secret provided, '"'$AZACME_SECRET'"' will be used.
  }
  [ "$AZACME_EMAIL" != "" ] || {
    echo No registration email provided, use '"--email <email>"' or set AZACME_EMAIL variable
    HAS_ERRORS=1
  }
  [ $HAS_ERRORS = 1 ] && exit 1

  dotnet $AZACME register \
    --server $SERVER \
    --key-vault-uri https://$AZURE_KEY_VAULT.vault.azure.net/ \
    --account-secret $AZACME_SECRET \
    --email $AZACME_EMAIL \
    $FORCE_REGISTRATION \
    --agree-tos \
    --verbose
    [ $? = 0 ] || {
        echo FAILED
        exit 1
    }

elif [ "$COMMAND" = "order" ]
then
  OPTS=$(getopt -l "tenant-id:,client-id:,client-secret:,kv:,secret:,subscription:,resource-group:,dns-zone:,cert-subject:,cert-name:" -- "" $@)
  [ $? = 0 ] || { 
      echo Incorrect options provided
      exit 1
  }

  eval set -- "$OPTS"

  while :
  do
    case "$1" in
      --tenant-id )
        export AZURE_TENANT_ID="$2"
        shift 2
        ;;
      --client-id )
        export AZURE_CLIENT_ID="$2"
        shift 2
        ;;
      --client-secret )
        export AZURE_CLIENT_SECRET="$2"
        shift 2
        ;;
      --kv )
        AZURE_KEY_VAULT="$2"
        shift 2
        ;;
      --secret )
        AZACME_ACCOUNT_SECRET="$2"
        shift 2
        ;;
      --subscription )
        AZURE_SUBSCRIPTION_ID="$2"
        shift 2
        ;;
      --resource-group )
        AZURE_RESOURCE_GROUP="$2"
        shift 2
        ;;
      --dns-zone )
        AZACME_DNS_ZONE="$2"
        shift 2
        ;;
      --cert-subject )
        AZACME_CERT_SUBJECT="$2"
        shift 2
        ;;
      --cert-name )
        AZACME_CERT_NAME="$2"
        shift 2
        ;;
      --)
        shift;
        break
        ;;
      *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
  done
  
  HAS_ERRORS=0
  [ "$AZURE_TENANT_ID" != "" ] || {
    echo No Azure App registration Directory '(tenant)' ID provided, use '"--tenant-id <tenant-id>"' or set AZURE_TENANT_ID variable.
    HAS_ERRORS=1
  }
  [ "$AZURE_CLIENT_ID" != "" ] || {
    echo No Azure App registration Application '(client)' ID provided, use '"--client-id <client-id>"' or set AZURE_CLIENT_ID variable.
    HAS_ERRORS=1
  }
  [ "$AZURE_CLIENT_SECRET" != "" ] || {
    echo No Azure App registration secret provided, use '"--client-secret <secret>"' or set AZURE_CLIENT_SECRET variable.
    HAS_ERRORS=1
  }
  [ "$AZURE_KEY_VAULT" != "" ] || {
    echo No Azure KeyVault name provided, use '"--kv <keyvault-name>"' or set AZURE_KEY_VAULT variable.
    HAS_ERRORS=1
  }
  [ "$AZACME_SECRET" = "" ] && {
    AZACME_SECRET=az-acme
    echo No KeyVault secret provided, '"'$AZACME_SECRET'"' will be used.
  }
  [ "$AZURE_SUBSCRIPTION_ID" != "" ] || {
    echo No registration email provided, use '"--subscription <subscription-id>"' or set AZURE_SUBSCRIPTION_ID variable.
    HAS_ERRORS=1
  }
  [ "$AZURE_RESOURCE_GROUP" != "" ] || {
    echo No registration email provided, use '"--resource-group <resource-group-name>"' or set AZURE_RESOURCE_GROUP variable.
    HAS_ERRORS=1
  }
  [ "$AZACME_DNS_ZONE" != "" ] || {
    echo No registration email provided, use '"--dns-zone <dns-zone>"' or set AZACME_DNS_ZONE variable.
    HAS_ERRORS=1
  }
  [ "$AZACME_CERT_SUBJECT" = "" ] && {
    AZACME_CERT_SUBJECT=$AZACME_DNS_ZONE
    echo No certificate subject provided, $AZACME_CERT_SUBJECT will be used.
  }
  [ "$AZACME_CERT_NAME" = "" ] && {
    AZACME_CERT_NAME=`echo $AZACME_CERT_SUBJECT | tr . -`
    echo No certificate name provided, $AZACME_CERT_NAME will be used.
  }
  [ $HAS_ERRORS = 1 ] && exit 1

  dotnet $AZACME order \
    --server $SERVER \
    --key-vault-uri https://$AZURE_KEY_VAULT.vault.azure.net/ \
    --account-secret $AZACME_SECRET \
    --subject $AZACME_CERT_SUBJECT \
    --certificate $AZACME_CERT_NAME \
    --dns-provider Azure \
    --azure-dns-zone /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Network/dnszones/$AZACME_DNS_ZONE \
    --dns-lookup google \
    --renew-within-days 30 \
    --disable-livetable \
    --verification-timeout-seconds 300 \
    --verbose
    [ $? = 0 ] || {
        echo FAILED
        exit 1
    }
else
  echo Invalid command specified: $COMMAND
  exit 1
fi

echo SUCCEEDED
exit 0
