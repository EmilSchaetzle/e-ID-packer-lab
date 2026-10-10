#!/bin/sh

if ! command -v packer >/dev/null
then
	printf "Packer doesn't seem to be installed.\nCheck https://developer.hashicorp.com/packer/install for installation instructions\n"
	exit 1
fi

set -e # To fail if the directory is not empty without having to write a full if-else
test -d output-eID && rmdir output-eID
set +e

#password="$(cat /dev/urandom | LC_ALL=C tr -dc [:alnum:] | fold -w 10 | head -n 1)"
#printf "Password generated for 'lab-user': %s\n" "$password"

#sed -E -i.orig 's|(d-i passwd/user-password[a-z-]* password).*$|\1 '"$password"'|g' ./http_files/preseed.cfg
#sed    -i.orig 's-\(user_pass = \).*$-\1 "'"$password"'"-g' ./variables.auto.pkrvars.hcl

packer init .
packer build .
