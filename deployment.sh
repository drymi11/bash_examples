###This file is the part of Jenkins and can't be used without it. Literally, it's useless and can only show codestyle.###
#!/bin/bash
SSHKEY="/var/lib/jenkins/keys/some_key"
NODE="4.3.2.1" #DEV_NODE
#NODE="1.2.3.4" #QA_NODE
USER="some-user"
REMOTEEXEC="ssh -i "$SSHKEY" "$USER"@"$NODE""
pushd $WORKSPACE/path/to/builded/zip/
export PKGNAME=`basename myproject*.zip`
MD5=`md5sum "$PKGNAME"` 
curl -v -u $NEXUS_LOGIN:$NEXUS_PASSWORD --upload-file $PKGNAME http://172.20.20.20/content/sites/backend_dev #uploading archive to Nexus
scp -i $SSHKEY $PKGNAME $USER@$NODE:/tmp/
MD5REMOTE=`$REMOTEEXEC "cd /tmp && md5sum $PKGNAME"`
if [ "$MD5" != "$MD5REMOTE" ]
	then
		exit 1
fi

$REMOTEEXEC "sudo unzip /tmp/$PKGNAME -d /opt/"
$REMOTEEXEC "sudo rm -f /tmp/$PKGNAME"
$REMOTEEXEC "sudo systemctl stop backend"
$REMOTEEXEC "sudo rm -rf /opt/backend"
DIRNAME=`echo $PKGNAME | sed -e s/.zip//`
$REMOTEEXEC "sudo mv /opt/$DIRNAME /opt/backend"

$REMOTEEXEC "sudo chown -R $USER:$USER /opt/backend/"
$REMOTEEXEC "sudo systemctl start backend"
sleep 35
if [[ $($REMOTEEXEC "systemctl is-failed backend") != active ]]
  then 
    $REMOTEEXEC "sudo journalctl -n200 -u backend"
      exit 1
fi
