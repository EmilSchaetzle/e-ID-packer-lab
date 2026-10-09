#!/bin/sh

alias elevate="echo '$ELEVATE_PASS' | sudo -S "

get_prov_file()
{
	local path="$1"
	local output="$2"

	curl -s "http://$PACKER_HTTP_ADDR/provisioning/issuer/$path" -o "$output"
}

cd ~/Documents

printf "\n===============================\n"
printf "ISSUER SETUP"
printf "\n===============================\n"

git clone https://github.com/swiyu-admin-ch/swiyu-issuer -- 2>&1
cd swiyu-issuer

# The default value is "X", if not set on variables.auto.pkrvars.hcl
BRANCH=""
if [ "$GIT_TAG" != "X" ]
then
  git checkout "$GIT_TAG" -- 2>&1
fi

printf "\n--------\n"
printf "Generating issuer's VSCode config"
printf "\n--------\n"

mkdir -p .vscode
get_prov_file vscode_launcher.json .vscode/launch.json

printf "\n--------\n"
printf "Fixing issuer config"
printf "\n--------\n"

get_prov_file visconid_issuer_metadata.json issuer-application/src/main/resources/visconid_issuer_metadata.json
get_prov_file visconid_vct_metadata.json issuer-application/src/main/resources/visconid_vct_metadata.json

get_prov_file visconid_oca.json issuer-application/src/main/resources/visconid_oca.json
get_prov_file visconid_json_schema.json issuer-application/src/main/resources/visconid_json_schema.json

printf "\n--------\n"
printf "Setting keys in the config"
printf "\n--------\n"

DIDLOG_ROOT=~/Documents/didlogs/issuer/
APP_CONFIG_FILE="issuer-application/src/main/resources/application-local.yml"

RAW_KEY=$(sed -Ee 's#-----(BEGIN|END) EC PRIVATE KEY-----##g' "$DIDLOG_ROOT/.didtoolbox/assert-key-01" | tr -d '\n\r')
DID="$(jq -r '.state.id' "$DIDLOG_ROOT/issuer_did.jsonl")"
DID_KEY="$(jq -r '.state.assertionMethod[0]' "$DIDLOG_ROOT/issuer_did.jsonl")"

printf "Got key: %s\n" "$RAW_KEY"
printf "Got DID: %s\n" "$DID"
printf "Got DID key: %s\n" "$DID_KEY"

# We're running the service locally to debug it. Our compose.yml needs only the DB
yq -i -y 'del(.services."swiyu-issuer-service")' sample.compose.yml

# Properties with hyphens need to be quoted
DID="$DID" RAW_KEY="$RAW_KEY" DID_KEY="$DID_KEY" yq -i -y '
  .application."external-url" = "https://viscon.swiyu/issuer" |
  .application."issuer-id" = env.DID |

  .application.key.sdjwt."private-key" = "-----BEGIN EC PRIVATE KEY-----\n" + env.RAW_KEY + "\n-----END EC PRIVATE KEY-----" |
  .application.key.sdjwt."verification-method" = env.DID_KEY |

  .application."template-replacement"."external-url" = "https://viscon.swiyu/issuer" |

  .application."metadata-file" = "classpath:visconid_issuer_metadata.json" |
  .application."vct-metadata-files"."my-vct-v01" = "classpath:visconid_vct_metadata.json" |
  .application."overlays-capture-architecture-metadata-files"."my-overlay-v01" = "classpath:visconid_oca.json" |
  .application."json-schema-metadata-files"."my-schema-v01" = "classpath:visconid_json_schema.json" |

  .spring.docker.compose.file = "sample.compose.yml" |

  del(.swiyu."status-registry"."token-url") |
  del(.swiyu."status-registry"."token-refresh-interval")

' "$APP_CONFIG_FILE"

