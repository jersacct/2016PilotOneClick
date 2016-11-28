#!/bin/sh

echo "Usage: ./OneClickInstall.sh ipaddress My.apk"
echo "Example: ./OneClickInstall.sh 192.168.1.100 Waze.apk"


echo "Disconnecting other adb devices\n"
adb disconnect
sleep 1

echo "Connecting to $1\n"
adb connect $1
sleep 1

echo "Checking for root..."
./check_root.sh $1

gotroot=`echo $?`

if [ $gotroot -gt 0 ]; then
	echo "No root yet, addressing the situation"

	echo "Attempting to push payloads to /data/local/tmp/rootme\n"
	adb shell 'mkdir /data/local/tmp/rootme'
	adb push factory_reset_mod.sh /data/local/tmp/rootme/
	adb push dirtycow /data/local/tmp/rootme/
	adb push nefarious.sh /data/local/tmp/rootme/
	adb push su /data/local/tmp/rootme/
	adb shell 'chmod 777 /data/local/tmp/rootme/*'


	echo "Exploiting dirtycow to replace factory_reset.sh with our own\n"
	adb shell '/data/local/tmp/rootme/dirtycow /system/etc/factory_reset.sh /data/local/tmp/rootme/factory_reset_mod.sh'

	echo "Okay - should be all set, initiate factory reset and hope for the best!"
	echo "Go to Home ->Settings->System->Factory Data Reset (scroll all the way down) and ititiate factory reset, press enter when unit has rebooted & reconnected to WiFi"

	read root

	echo "Okay - checking for successfull root\n"
	adb disconnect
	sleep 1
	adb connect $1
	sleep 1
	./check_root.sh $1
	gotroot=`echo $?`
	if [ $gotroot -gt 0 ]; then
		"Hmm, didn't get root. Aborting further operations."
		exit 1
	else
		"Got root!!!"
	fi
else
	echo "Already rooted!"
fi

#If we're at this point of the script, we have root & ADB connection established
echo "Okay, getting signature of $2"

sig=`java -jar bin/GetAndroidSig.jar "$2" | grep "To char" | sed -r 's/^.{9}//'`
echo "Signature: $sig"

echo "Getting package information"
package=`aapt dump permissions "$2" | head -1 | sed -r 's/^.{9}//'`
echo "Package name: $package"
echo "Retrieving current whitelist..."
`adb shell "su -c 'cp /data/system/whitelist.xml /data/local/tmp/'"`
`adb shell "su -c 'chown shell:shell /data/local/tmp/whitelist.xml'"`
`adb pull /data/local/tmp/whitelist.xml 2>/dev/null`

echo "Preparing replacement whitelist"
`cat whitelist.xml | grep  -v "</applicationLists" | grep -v "</whiteList" > whitelist-new.xml`

echo "        <application>
            <property>
                <name>$package</name>
                <package>$package</package>
                <versionCode>1-999999999</versionCode>
                <keyStoreLists> " >> whitelist-new.xml
#Need to hanlde case of sig containing multiple lines - some APKS have more than one sig

for signature in $sig; do
echo "                    <keyStore>$signature</keyStore> " >> whitelist-new.xml

done

echo "                </keyStoreLists>
            </property>
            <controlData>
                <withAudio>without</withAudio>
                <audioStreamType>null</audioStreamType>
                <regulation>null</regulation>
                <revert>no</revert>
            </controlData>
        </application>

	</applicationLists>
</whiteList>" >> whitelist-new.xml

echo "Okay - all set to replace the whitelist. Below are the final steps:
1. Backup existing whitelist to /data/local/tmp/
2. Upload whitelist to head unit
3. Reboot head unit
4. Install APK normally

Please review the below items carefully - if anything doesn't look right, ABORT NOW!\n"
if [ $gotroot -eq 0 ]; then
echo "Root status: rooted"
else
echo "Root status: not rooted (bad!)"
fi

if [ ! -z "$sig" ]; then
echo "APK signature obtained"
else
echo "APK signature NOT obtained (bad!)"
fi

if [ ! -z "$package" ]; then
echo "Have package name: $package"
else
echo "Did not get package name (bad!)"
fi
wlcheck=`ls -al whitelist.xml | awk '{print $5}'`
if [ $wlcheck -gt 20000 ]; then
echo "Original whitelist.xml size seems okay"
else
echo "Original whitelist.xml size DOES NOT seem okay (bad!)"
fi

packagecheck=`grep $package whitelist-new.xml`
if [ ! -z "$package" ]; then
echo "Package name is present in new whitelist"
else
echo "Package name is NOT present in new whitelist (bad!)"
fi

echo "
Would you like to proceed? (y/n):"
read retval
if [ "$retval" != "y" ]; then
echo "Okay - aborting"
exit 1
fi

`adb shell "su -c 'mount -o remount,rw /system'"`
ts=`date '+%d-%m-%Y--%H-%M-%S'`
echo "Backing up whitelist to /data/local/tmp/whitelist-$ts.xml"
`adb shell "su -c 'cp /data/system/whitelist.xml /data/local/tmp/whitelist-$ts.xml'"`
echo "Uploading whitelist"
`adb push whitelist-new.xml /data/local/tmp/whitelist.xml`
`adb shell "su -c 'cp /data/local/tmp/whitelist.xml /data/system/'"`
`adb shell "su -c 'mount -o remount,ro /system'"`
echo "Rebooting head unit"
`adb shell "su -c 'reboot' 2>/dev/null" &`
echo "Press enter when head unit has rebooted and is connected to WiFi"
read dummy
echo "Issuing APK installation command - this may take a while depending on APK size"
`adb disconnect`
sleep 1
adb connect $1
sleep 1
adb install $2
echo "All done - hope you enjoy!"


