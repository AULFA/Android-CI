#!/bin/bash

#------------------------------------------------------------------------
# A script to clone the Credentials repository and check that the required
# secrets are present and working.
#

#------------------------------------------------------------------------
# Utility methods
#

fatal()
{
  echo "ci-credentials.sh: fatal: $1" 1>&2
  exit 1
}

info()
{
  echo "ci-credentials.sh: info: $1" 1>&2
}

#------------------------------------------------------------------------
# Check environment
#

if [ -z "${MAVEN_CENTRAL_USERNAME}" ]
then
  fatal "MAVEN_CENTRAL_USERNAME is not defined"
fi
if [ -z "${MAVEN_CENTRAL_PASSWORD}" ]
then
  fatal "MAVEN_CENTRAL_PASSWORD is not defined"
fi
if [ -z "${MAVEN_CENTRAL_STAGING_PROFILE_ID}" ]
then
  fatal "MAVEN_CENTRAL_STAGING_PROFILE_ID is not defined"
fi
if [ -z "${MAVEN_CENTRAL_SIGNING_KEY_ID}" ]
then
  fatal "MAVEN_CENTRAL_SIGNING_KEY_ID is not defined"
fi
if [ -z "${AULFA_GITHUB_ACCESS_TOKEN}" ]
then
  fatal "AULFA_GITHUB_ACCESS_TOKEN is not defined"
fi

#------------------------------------------------------------------------
# Clone credentials repos
#

info "Cloning credentials"

git clone \
  --depth 1 \
  "https://${AULFA_GITHUB_ACCESS_TOKEN}@github.com/AULFA/application-secrets" \
  ".ci/credentials" || fatal "Could not clone credentials"

#------------------------------------------------------------------------
# Import the PGP key for signing Central releases, and try to sign a test
# file to check that the key hasn't expired.
#

info "Importing GPG key"
gpg --import ".ci/credentials/lfa.asc" || fatal "Could not import GPG key"

info "Signing test file"
echo "Test" > hello.txt || fatal "Could not create test file"
gpg --sign -a hello.txt || fatal "Could not produce test signature"

#------------------------------------------------------------------------
# Import the SSH key for uploading builds.
#

info "Importing SSH key"
mkdir -p "$HOME/.ssh" ||
  fatal "could not create .ssh"
cp -v ".ci/credentials/builds-ssh.key" "$HOME/.ssh/id_ed25519" ||
  fatal "could not copy key"
cp -v ".ci/credentials/builds-ssh.key.pub" "$HOME/.ssh/id_ed25519.pub" ||
  fatal "could not copy key"
cp -v ".ci/credentials/builds-ssh.known_hosts" "$HOME/.ssh/known_hosts" ||
  fatal "could not copy key"

chmod 0600 "$HOME/.ssh/id_ed25519" || fatal "could not set permissions"
chmod 0644 "$HOME/.ssh/id_ed25519.pub" || fatal "could not set permissions"
chmod 0644 "$HOME/.ssh/known_hosts" || fatal "could not set permissions"

cat >> "$HOME/.ssh/config" <<EOF
Host builds.lfa.one
  Port 1022
  User ci

EOF

#------------------------------------------------------------------------
# Download Brooklime if necessary.
#

BROOKLIME_URL="https://repo1.maven.org/maven2/com/io7m/brooklime/com.io7m.brooklime.cmdline/0.1.0/com.io7m.brooklime.cmdline-0.1.0-main.jar"
BROOKLIME_SHA256_EXPECTED="d706dee5ce6be4992d35b3d61094872e194b7f8f3ad798a845ceb692a8ac8fcd"

wget -O "brooklime.jar.tmp" "${BROOKLIME_URL}" || fatal "Could not download brooklime"
mv "brooklime.jar.tmp" "brooklime.jar" || fatal "Could not rename brooklime"

BROOKLIME_SHA256_RECEIVED=$(openssl sha256 "brooklime.jar" | awk '{print $NF}') || fatal "Could not checksum brooklime.jar"

if [ "${BROOKLIME_SHA256_EXPECTED}" != "${BROOKLIME_SHA256_RECEIVED}" ]
then
  fatal "brooklime.jar checksum does not match.
  Expected: ${BROOKLIME_SHA256_EXPECTED}
  Received: ${BROOKLIME_SHA256_RECEIVED}"
fi

#------------------------------------------------------------------------
# Download changelog if necessary.
#

CHANGELOG_URL="https://repo1.maven.org/maven2/com/io7m/changelog/com.io7m.changelog.cmdline/4.1.0/com.io7m.changelog.cmdline-4.1.0-main.jar"
CHANGELOG_SHA256_EXPECTED="2a38beaea7c63349c1243dbee52d97a1d048578d1132dd1b509e2d8d37445033"

wget -O "changelog.jar.tmp" "${CHANGELOG_URL}" || fatal "Could not download changelog"
mv "changelog.jar.tmp" "changelog.jar" || fatal "Could not rename changelog"

CHANGELOG_SHA256_RECEIVED=$(openssl sha256 "changelog.jar" | awk '{print $NF}') || fatal "Could not checksum changelog.jar"

if [ "${CHANGELOG_SHA256_EXPECTED}" != "${CHANGELOG_SHA256_RECEIVED}" ]
then
  fatal "changelog.jar checksum does not match.
  Expected: ${CHANGELOG_SHA256_EXPECTED}
  Received: ${CHANGELOG_SHA256_RECEIVED}"
fi

#------------------------------------------------------------------------
# Run local credentials hooks if present.
#

if [ -f .ci-local/credentials.sh ]
then
  .ci-local/credentials.sh || fatal "local credentials hook failed"
fi
