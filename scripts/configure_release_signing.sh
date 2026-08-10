#!/bin/sh
set -eu

workspace_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
android_dir="$workspace_dir/mobile_app/android"
keystore_file="$android_dir/app/ai-blind-assistant-release.jks"
properties_file="$android_dir/key.properties"
alias_name="ai_blind_assistant"

if [ -f "$keystore_file" ] && [ -f "$properties_file" ]; then
  echo "Existing ignored release signing configuration preserved."
  exit 0
fi

if [ -e "$keystore_file" ] || [ -e "$properties_file" ]; then
  echo "Refusing to overwrite an incomplete release signing configuration." >&2
  echo "Back up and resolve $keystore_file and $properties_file manually." >&2
  exit 1
fi

command -v keytool >/dev/null 2>&1 || {
  echo "keytool is required to create the Android release keystore." >&2
  exit 1
}
command -v openssl >/dev/null 2>&1 || {
  echo "openssl is required to create a random local signing password." >&2
  exit 1
}

umask 077
signing_password=$(openssl rand -base64 48 | tr -d '\n/+=' | cut -c1-48)
export AIBA_RELEASE_STORE_PASSWORD="$signing_password"
export AIBA_RELEASE_KEY_PASSWORD="$signing_password"

keytool -genkeypair \
  -keystore "$keystore_file" \
  -storetype PKCS12 \
  -storepass:env AIBA_RELEASE_STORE_PASSWORD \
  -keypass:env AIBA_RELEASE_KEY_PASSWORD \
  -alias "$alias_name" \
  -keyalg RSA \
  -keysize 3072 \
  -sigalg SHA256withRSA \
  -validity 10000 \
  -dname "CN=AI Blind Assistant, OU=FYP, O=AI Blind Assistant, L=Local, ST=Local, C=PK" \
  >/dev/null

temporary_properties=$(mktemp "$android_dir/.key.properties.XXXXXX")
trap 'rm -f "$temporary_properties"' EXIT HUP INT TERM
printf '%s\n' \
  "storePassword=$signing_password" \
  "keyPassword=$signing_password" \
  "keyAlias=$alias_name" \
  "storeFile=ai-blind-assistant-release.jks" \
  >"$temporary_properties"
chmod 600 "$temporary_properties" "$keystore_file"
mv "$temporary_properties" "$properties_file"
trap - EXIT HUP INT TERM

unset AIBA_RELEASE_STORE_PASSWORD AIBA_RELEASE_KEY_PASSWORD signing_password
echo "Created ignored project release signing files. Back them up securely; future app updates require the same keystore."
