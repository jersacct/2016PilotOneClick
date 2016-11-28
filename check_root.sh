#!/bin/sh




#echo "Disconnecting other adb devices\n"
#adb disconnect
#sleep 1

#echo "Connecting to $1\n"
#adb connect $1

success=`adb shell 'su -c id' | grep "root"`
#echo "Return = $success"

if [ ! -z "$success" ]; then
	echo "Rooted successfully!"
	exit 0
else
	#echo "Root failed :("
	exit 1
fi

