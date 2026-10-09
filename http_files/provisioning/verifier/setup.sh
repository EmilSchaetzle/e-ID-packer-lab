#!/bin/sh

alias elevate="echo '$ELEVATE_PASS' | sudo -S "

get_prov_file()
{
	local path="$1"
	local output="$2"

	curl -s "http://$PACKER_HTTP_ADDR/provisioning/verifier/$path" -o "$output"
}

patch_file()
{
	local path="$1"
	local filename="$(basename "$path")"

	get_prov_file "${filename}.patch" /tmp/patchfile
	patch -u -i /tmp/patchfile "$path"
}

cd ~/Documents

printf "\n===============================\n"
printf "VERIFIER SETUP"
printf "\n===============================\n"

git clone https://github.com/swiyu-admin-ch/swiyu-verifier -- 2>&1
cd swiyu-verifier

# The default value is "X", if not set on variables.auto.pkrvars.hcl
BRANCH=""
if [ "$GIT_TAG" != "X" ]
then
  git checkout "$GIT_TAG" -- 2>&1
fi

printf "\n--------\n"
printf "Generating verifier's VSCode config"
printf "\n--------\n"

mkdir -p .vscode
get_prov_file vscode_launcher.json .vscode/launch.json

printf "\n--------\n"
printf "Fixing verifier config"
printf "\n--------\n"

patch_file verifier-application/src/main/resources/bootstrap.yml
patch_file verifier-application/src/main/resources/client_metadata.json

printf "\n--------\n"
printf "Setting keys in the config"
printf "\n--------\n"

DIDLOG_ROOT=~/Documents/didlogs/verifier/
APP_CONFIG_FILE="verifier-application/src/main/resources/application-local.yml"

RAW_KEY=$(sed -Ee 's#-----(BEGIN|END) EC PRIVATE KEY-----##g' "$DIDLOG_ROOT/.didtoolbox/assert-key-01" | tr -d '\n\r')
DID="$(jq -r '.state.id' "$DIDLOG_ROOT/verifier_did.jsonl")"
DID_KEY="$(jq -r '.state.assertionMethod[0]' "$DIDLOG_ROOT/verifier_did.jsonl")"

printf "Got key: %s\n" "$RAW_KEY"
printf "Got DID: %s\n" "$DID"
printf "Got DID key: %s\n" "$DID_KEY"

# We're running the service locally to debug it. Our compose.yml needs only the DB
yq -i -y 'del(.services."verifier-service") |
	.services."verifier_postgres".ports = ["5435:5432"]
' sample.compose.yml

DID="$DID" RAW_KEY="$RAW_KEY" DID_KEY="$DID_KEY" yq -i -y '
  .application.signing_key = "-----BEGIN EC PRIVATE KEY-----\n" + env.RAW_KEY + "\n-----END EC PRIVATE KEY-----" |
  .application."signing-key-verification-method" = env.DID_KEY |

  .application.client_id = env.DID |
  .application."external-url" = "https://viscon.swiyu/verifier" |

  .spring.datasource.url = "jdbc:postgresql://localhost:5435/verifier_db" |
  .spring.docker.compose.file = "sample.compose.yml"

' "$APP_CONFIG_FILE"

