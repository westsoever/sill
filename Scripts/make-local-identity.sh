#!/bin/bash
# Makes "Sill Local Signing", a self-signed code-signing identity in the login keychain, for a Mac
# with no Apple Development or Developer ID identity (no Apple developer account).
#
#   Scripts/make-local-identity.sh     makes it once; prints its SHA-1 when it is already there
#
# Scripts/make-app.sh and Scripts/make-client-app.sh sign with it when they find no Apple identity.
# Why: an ad hoc signature's designated requirement is a hash of that one build, so every rebuild
# loses Screen Recording and Accessibility (System Settings still shows the switch on, for the
# build before) and can no longer read the login keychain's items it made. With this identity the
# requirement is the bundle ID plus this certificate, which every rebuild keeps. Builds signed with
# it run on this Mac only: Gatekeeper does not trust the certificate, so never hand one to anyone.
# It never replaces a Developer ID release: those keep their identity in the data-protection
# keychain (docs/keychain-plan.md), which no build signed here can read.
set -euo pipefail
name="Sill Local Signing"
keychain="$HOME/Library/Keychains/login.keychain-db"

existing="$(security find-identity -p codesigning 2>/dev/null | awk -v n="\"$name\"" 'index($0, n) { print $2; exit }' || true)"
if [ -n "$existing" ]; then
    echo "$name is already in the login keychain: $existing"
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/cfg" <<EOF
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=$name
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
EOF
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$tmp/key.pem" -out "$tmp/cert.pem" -days 3650 -config "$tmp/cfg" 2>/dev/null
pass="$(openssl rand -hex 16)"
openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -name "$name" -out "$tmp/id.p12" -passout "pass:$pass"
# -T: codesign may use the key without asking.
security import "$tmp/id.p12" -k "$keychain" -P "$pass" -T /usr/bin/codesign >/dev/null
hash="$(security find-identity -p codesigning | awk -v n="\"$name\"" 'index($0, n) { print $2; exit }')"
echo "Made $name in the login keychain: $hash"
