#!/bin/sh
BASE_DIR=$(dirname $0)
VERSION=$(grep 'Version:' ${BASE_DIR}/../../monitor.spec | awk '{print $2}')
TMP_DIR=/tmp/monitor-${VERSION}/DEBIAN
test -d ${TMP_DIR} && rm -rf ${TMP_DIR}
mkdir -p ${TMP_DIR} || true

cat << EOF > ${TMP_DIR}/control
Package: monitor
Version: ${VERSION}
Architecture: all
Maintainer: Alexander Rumyantsev <dolphin@wikimart.ru>
Section: utils
Priority: optional
Description: Perl-based Zabbix agent daemon
EOF

cat << EOF > ${TMP_DIR}/conffiles
/usr/bin/monitor.pl
EOF

echo "monitor (${VERSION}) unstable; urgency=low" > ${TMP_DIR}/changelog
sed '1,/%changelog/d' ${BASE_DIR}/../../monitor.spec >> ${TMP_DIR}/changelog
cp -pr ${BASE_DIR}/../../usr ${TMP_DIR}/..
cp -pr ${BASE_DIR}/../../etc ${TMP_DIR}/..
cp -p  ${BASE_DIR}/init-script ${TMP_DIR}/../etc/init.d/monitor
(cd ${TMP_DIR}/../.. && dpkg-deb --build monitor-${VERSION})
mv /tmp/monitor-${VERSION}.deb .
