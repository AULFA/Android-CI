#!/bin/bash

#------------------------------------------------------------------------
# A script to deploy over ssh.
#

#------------------------------------------------------------------------
# Utility methods
#

fatal()
{
  echo "ci-deploy-ssh.sh: fatal: $1" 1>&2
  exit 1
}

info()
{
  echo "ci-deploy-ssh.sh: info: $1" 1>&2
}

#------------------------------------------------------------------------

SSH_PROJECTS=$(egrep -v '^#' '.ci-local/deploy-ssh.conf') ||
  fatal "could not list projects"

for PROJECT in ${SSH_PROJECTS}
do
  info "uploading binaries for ${PROJECT}"
  APK_RELEASE_DIRECTORY="${PROJECT}/build/outputs/apk/release/"
  rsync \
    -avz \
    --progress \
    --delay-updates \
    --no-times \
    --no-owner \
    --no-perms \
    --include '*.apk' \
    --exclude '*' \
    "${APK_RELEASE_DIRECTORY}/" \
    "builds.lfa.one:/repository/testing/all/" ||
    fatal "could not upload APK files"
done
