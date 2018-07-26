#!/bin/bash
# Mac OS X
# Download new jenkins.war them replace the current on; restart the service.

DEFAULT_URL=http://updates.jenkins-ci.org/current/latest/jenkins.war
TMP_PATH=/tmp/jenkins.war
APP_PATH=/Applications/Jenkins/jenkins.war
PLIST_PATH=/Library/LaunchDaemons/org.jenkins-ci.plist

url=${1-$DEFAULT_URL}


echo 'Applying update...'
sudo -s -- <<EOF
wget $DEFAULT_URL -O $TMP_PATH
launchctl unload $PLIST_PATH
mv -f $APP_PATH $APP_PATH.bak
mv $TMP_PATH $APP_PATH
chown root:wheel $APP_PATH
launchctl load $PLIST_PATH
EOF
