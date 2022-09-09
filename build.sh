#!/bin/bash
set -euo pipefail

# Variables you should set when updating. You SHOULD check on
# https://db-ip.com/ if a new version is available.
country_db_url=https://download.db-ip.com/free/dbip-country-lite-2022-09.mmdb.gz
country_db_sha1sum=c293560345b5043c2a49051474e8be87b31d358e

# See https://github.com/ooni/probe/issues/2271
asn_db_url=https://download.db-ip.com/free/dbip-asn-lite-2022-08.mmdb.gz
asn_db_sha1sum=c5e17f70ac3d282eb58a55f9ba9e20ad1fa1e097

# Remove leftovers.
set -x
rm -f ./assets/*.mmdb ./assets/*.mmdb.gz
set +x

# See https://remarkablemark.org/blog/2017/10/12/check-git-dirty/
[[ -z `git status -s` ]] || {
    echo "fatal: repository contains modified or untracked files"
    exit 1
}

# Make sure you are in the master branch of the repository.
# See https://git-blame.blogspot.com/2013/06/checking-current-branch-programatically.html
__ref=`git symbolic-ref --short -q HEAD`
[[ "$__ref" == "master" || "$__ref" == "main" ]] || {
  echo "FATAL: not on the master branch" 1>&2
  exit 1
}

# Fetch the country DB file, decompress and verify it.
country_db_file=./assets/country.mmdb
country_db_gzfile=${country_db_file}.gz
set -x
curl -fsSLo $country_db_gzfile $country_db_url
gunzip -k $country_db_gzfile
set +x
sha1sum=`shasum -a1 $country_db_file | awk '{print $1}'`
if [ "$sha1sum" != "$country_db_sha1sum" ]; then
  echo "FATAL: country database does not match the expected sha1sum" 1>&2
  exit 1
fi

# Fetch the asn DB file, verify and decompress it.
asn_db_file=./assets/asn.mmdb
asn_db_gzfile=${asn_db_file}.gz
set -x
curl -fsSLo $asn_db_gzfile $asn_db_url
gunzip -k $asn_db_gzfile
set +x
sha1sum=`shasum -a1 $asn_db_file | awk '{print $1}'`
if [ "$sha1sum" != "$asn_db_sha1sum" ]; then
  echo "FATAL: asn database does not match the expected sha1sum" 1>&2
  exit 1
fi

# Verify the downloaded databases
go run ./cmd/verify $asn_db_file $country_db_file

# Make sure what we have downloaded does not emit smoke.
set -x
go test -v ./...
set +x

if [ "$1" = "-n" ]; then
  exit 0  # dry-run
fi

# Instructions to make a release.
version=`cat VERSION`
version=$(($version + 1))
echo $version > VERSION
set -x
git commit -m "Bump version to 0.$version.0" VERSION
git checkout -b vendor-0.$version.0
git add assets/*.mmdb
git commit -am "Release 0.$version.0"
git tag -m "Tag v0.$version.0" -s v0.$version.0
set +x
echo "Now you should run the following commands:"
echo ""
echo "- git push origin master vendor-0.$version.0 v0.$version.0"
echo ""
echo "For updating, you need to go in github.com/ooni/probe-cli and run:"
echo ""
echo "- go get -v github.com/ooni/probe-assets@v0.$version.0"
echo ""
