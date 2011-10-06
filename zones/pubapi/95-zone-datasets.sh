echo "95 configuring pubapi datasets"

# This needs to run after scmgit pkgsrc package has been installed:

# pubapi-data dataset name will remain the same always:
zfs set mountpoint=/opt/smartdc/pubapi-data zones/pubapi/pubapi-data
# pubapi-app-ISO_DATE dataset name will change:
STAMP=$(cat /root/pubapi-app-timestamp)
zfs set mountpoint=/opt/smartdc/pubapi "zones/pubapi/pubapi-app-$STAMP"
# Get git revision:
cd /opt/smartdc/pubapi-repo
REVISION=$(/opt/local/bin/git rev-parse --verify HEAD)
# Export complete repo into pubapi:
cd /opt/smartdc/pubapi-repo

/opt/local/bin/git checkout-index -f -a --prefix=/opt/smartdc/pubapi/

# Export only config into pubapi-data:
cd /opt/smartdc/pubapi-repo

# Create some directories into pubapi-data
mkdir -p /opt/smartdc/pubapi-data/log
mkdir -p /opt/smartdc/pubapi-data/tmp/pids
mkdir -p /opt/smartdc/pubapi-data/db
# Remove and symlink directories:
if [[ ! -n ${KEEP_DATA_DATASET} ]]; then
  mv /opt/smartdc/pubapi/config /opt/smartdc/pubapi-data/config
else
  rm -Rf /opt/smartdc/pubapi/config
fi
rm -Rf /opt/smartdc/pubapi/log
rm -Rf /opt/smartdc/pubapi/tmp
rm -Rf /opt/smartdc/pubapi/config
ln -s /opt/smartdc/pubapi-data/log /opt/smartdc/pubapi/log
ln -s /opt/smartdc/pubapi-data/tmp /opt/smartdc/pubapi/tmp
ln -s /opt/smartdc/pubapi-data/config /opt/smartdc/pubapi/config
ln -s /opt/smartdc/pubapi-data/db /opt/smartdc/pubapi/db
# Save REVISION:
echo "${REVISION}">/opt/smartdc/pubapi-data/REVISION
echo "${REVISION}">/opt/smartdc/pubapi/REVISION
# Save VERSION (Updates based on this):
APP_VERSION=$(/opt/local/bin/git describe --tags)
if [[ ! -n ${KEEP_DATA_DATASET} ]]; then
  echo "${APP_VERSION}">/opt/smartdc/pubapi-data/VERSION
fi
echo "${APP_VERSION}">/opt/smartdc/pubapi/VERSION
# Cleanup build products:
cd /root/
rm -Rf /opt/smartdc/pubapi-repo
rm /root/pubapi-app-timestamp
