#!/bin/sh
#
#  slim-update.sh
#
#  Script to update slimserver.tcz on piCore 7.x from Automatic Download from LMS.
#
#  Script by Paul_123 @ http://forum.tinycorelinux.net/
#  Script Source https://github.com/paul-1/lms-update-script
#  Original script concept by jgrulich
#
#
#  Most common usage will be 'sudo lms-update.sh -r'
#
#  Revision 1.0
#

. /etc/init.d/tc-functions

checkroot
TCEDIR=$(readlink "/etc/sysconfig/tcedir")
DL_DIR="/tmp/slimupdate"
UPDATELINK="${DL_DIR}/update_url"
NEWARGS="${@}"
GIT_REPO="https://raw.githubusercontent.com/paul-1/lms-update-script/Master"
[ -d ${DL_DIR} ] || mkdir -p ${DL_DIR}

usage(){
	echo "  usage: $0 [-u] [-d] [-m] [-r] [-s] [-t]"
	echo "            -u Unattended Execution"
	echo "            -d Debug, Temp files not erased"
	echo "            -m Manual download Link Check for LMS update"  #this method could break when there is a change on LMS from 7.9.0
	echo "            -r Reload LMS after Update"
	echo "            -s Skip Update from GitHub"
	echo "            -t Test building, but do not move extension to tce directory"
	echo
}

while [ $# -gt 0 ]
do
	case "$1" in
		-u)  UNATTENDED=1;;
		-d)  DEBUG=1;;
		-m)  MANUAL=1;;
		-r)  RELOAD=1;;
		-t)  TEST=1;;
		-s)  SKIPUPDATE=1;;
		-sss) RESUME=1;;  #For script relaunch use only, do not use from
		--)	shift; break;;
		-*)  usage
		exit 1;;
		*)  break;;	# terminate while loop
	esac
	shift
done

if [ -z "$RESUME" ]; then
	[ -z "$UNATTENDED" ] && clear

	echo
	echo "${BLUE}###############################################################"
	echo
	echo "  This script will update the Logitech Media Server extension  "
	echo
	usage
	[ -n "$UNATTENDED" ] && echo "       Unattended Operation Enabled"
	[ -n "$DEBUG" ] && echo "       Debug Enabled"
	[ -n "$MANUAL" ] && echo "       Manual Download Link Check Enabled"
	[ -n "$RELOAD" ] && echo "       Automatic Reload Enabled"
	[ -n "$SKIPUPDATE" ] && echo "       Skipping Update"
	[ -n "$TEST" ] && echo "       Test Mode Enabled"
	echo "###############################################################"
	echo
	echo "Press Enter to continue, or Ctrl-c to exit and change options${NORMAL}"

	[ -z "$UNATTENDED" ] && read key

	if [ "$SKIPUPDATE" != "1" ]; then
	#Check for depednancy of openssl for wget to work with https://
		if [ ! -x /usr/local/bin/openssl ]; then
			if  [ ! -f $TCEDIR/optional/openssl.tcz ]; then
				echo "${GREEN} Downloading required extension openssl.tcz${NORMAL}"
				echo
				su - tc -c "tce-load -liw openssl.tcz"
			else
				echo "${GREEN} Loading Local Extension openssl.tcz${NORMAL}"
				echo
				su - tc -c "tce-load -li openssl.tcz"
			fi
			if [ "$?" != "0" ]; then echo "${RED}Failed to load required extension!. ${NORMAL} Check by manually installing	extension openssl.tcz"; exit 1; fi
		fi

		echo "${GREEN}Updateing Script from Github..."
		FILES="lms-update.sh"
		for F in $FILES
		do
			rm -f ${DL_DIR}/${F}
			wget -O ${DL_DIR}/${F} ${GIT_REPO}/${F}
			if [ "$?" != "0" ]; then
				echo "${RED}Download FAILED......Please Check or Relauch script with with -s option!${NORMAL}"
				exit 1
			fi
		done

		echo "${GREEN}Relaunching Script in 3 seconds${NORMAL}"
		chmod 755 ${DL_DIR}/lms-update.sh
		sleep 3
		set -- "-sss" $NEWARGS
		exec /bin/sh ${DL_DIR}/lms-update.sh "${@}"
	else
		#if we are going to dismount drive to automatically reload extension, we cannot run lms-update.sh from /usr/local/bin
		if [ -n "$RELOAD" ]; then
			echo "${GREEN}Copying and Running script to tmp so we can automatically reload LMS later"
			cp -f /usr/local/bin/lms-update.sh ${DL_DIR}/lms-update.sh
			set -- "-sss" $NEWARGS
			exec /bin/sh ${DL_DIR}/lms-update.sh "${@}"
		fi
	fi
fi

if [ "$SKIPUPDATE" != "1" ]; then
	echo "${GREEN}Updateing Slimserver customizations from Github..."
	FILES="custom-strings.txt picore-update.html Custom.pm slimserver"
	for F in $FILES
	do
		rm -f ${DL_DIR}/${F}
		wget -O ${DL_DIR}/${F} ${GIT_REPO}/${F}
		if [ "$?" != "0" ]; then
			echo "${RED}Download FAILED......Please Check or Relauch script with with -s option!${NORMAL}"
			exit 1
		fi
	done
fi

if [ -z "$MANUAL" ]; then
	if [ -f  "${UPDATELINK}" ]; then
		read LINK < $UPDATELINK
	else
		LINK="0"
	fi
else
	CURVER=$(head -n 1 /usr/local/slimserver/revision.txt)
	echo "${YELLOW}Performing manual check for update link, Current Version is: $CURVER.${NORMAL}"
	tmp=`mktemp`
	wget "http://www.mysqueezebox.com/update/?version=7.9.0&revision=${CURVER}&geturl=1&os=nocpan" -O $tmp
	if [ "$?" != "0" ]; then echo "${RED}Unable to Contact Download Server!${NORMAL}"; rm $tmp; exit 1; fi
	read LINK < $tmp
	rm -f $tmp
fi

if [ "$LINK" = "0" ]; then
#   No Update needed
	if [ -z "$MANUAL" ]; then
		echo
		echo "${BLUE}No update link found.   THis either means that there is no update, or you do not have automatic update"
		echo "checks and automatic downloads enabled in the LMS settings."
		echo
		echo "If you would like to manually check for updates using a static update check, please relaunch this script"
		echo "using the -m command line switch"
		echo
		echo "DONE${NORMAL}"
		exit 0
	else
		echo "${BLUE}Revision $CURVER is the latest. No Update Needed."
		echo
		echo "DONE.${NORMAL}"
		exit 0
	fi
else
	echo
	echo "${GREEN}Downloading update from ${LINK}"
fi

rm -f $DL_DIR/*.tgz
wget -P $DL_DIR $LINK
if [ "$?" != "0" ]; then
	echo "${RED}Download FAILED...... exiting!${NORMAL}"
	[ -n "$DEBUG" ] || rm -f $DL_DIR/'*.tgz'
	exit 1
fi

NEWUPDATE=`find ${DL_DIR} -name "*.tgz"`
if [ -z $NEWUPDATE ]; then
	echo "${BLUE}No Update Found, please make sure Automatic updates and Automatic Downloads are enable in LMS.${NORMAL}"
	echo
	exit 0
fi

#Check for depednancy of mksquashfs
if [ ! -x /usr/local/bin/mksquashfs ]; then
	if  [ ! -f $TCEDIR/optional/squashfs-tools.tcz ]; then
		echo "${GREEN}Downloading required extension squashfs-tools.tcz${NORMAL}"
		echo
		su - tc -c "tce-load -liw squashfs-tools.tcz"
	else
		echo "${GREEN}Loading Local Extension squashfs-tools.tcz${NORMAL}"
		echo
		su - tc -c "tce-load -li squashfs-tools.tcz"
	fi
	if [ "$?" != "0" ]; then echo "${RED}Failed to load required extension!. ${NORMAL} Check by manually installing extension squashfs-tools.tcz"; exit 1; fi
fi

echo
echo "${GREEN}Updating from ${NEWUPDATE}"

#  Extract Downloaded File
echo
echo -ne "${GREEN}Extracting Update..."

SRC_DIR=`mktemp -d`
f=`mktemp`
( tar -xzf ${NEWUPDATE} -C $SRC_DIR; echo -n $? > $f ) &

rotdash $!
read e < $f
if [ "$e" != "0" ]; then
	echo "${RED}File Extraction FAILED.....exiting!${NORMAL}"
	[ -n "$DEBUG" ] || rm -rf $SRC_DIR
	exit 1
fi
rm -f $f

echo
echo -e "${BLUE}Tar Extraction Complete, Building Updated Extension Filesystem"
echo
echo "Press Enter to continue, or Ctrl-c to exit${NORMAL}"

[ -z "$UNATTENDED" ] && read key

echo
echo -ne "${GREEN}Update in progress ..."

BUILD_DIR=`mktemp -d`

f=`mktemp`
echo 0 > $f

# Each command has an error trap
(mkdir -p $BUILD_DIR/usr/local/bin
[ "$?" != "0" ] && echo -n "1" > $f
mkdir -p $BUILD_DIR/usr/local/etc/init.d
[ "$?" != "0" ] && echo -n "1" > $f
mv $SRC_DIR/*-noCPAN $BUILD_DIR/usr/local/slimserver
[ "$?" != "0" ] && echo -n "1" > $f

#Copy in piCore custom files
FDIR="usr/local/slimserver/Slim/Utils/OS"
F="Custom.pm"
if [ -e ${DL_DIR}/${F} ]; then  # Copy Updated Version
	cp -f ${DL_DIR}/${F} $BUILD_DIR/${FDIR}/${F}
else   # Copy version from current Extension
	cp -f /tmp/tcloop/slimserver/${FDIR}/${F} $BUILD_DIR/${FDIR}/${F}
fi
[ "$?" != "0" ] && echo -n "1" > $f

FDIR="usr/local/slimserver/HTML/EN/html/docs"
F="picore-update.html"
if [ -e ${DL_DIR}/${F} ]; then  # Copy Updated Version
	cp -f ${DL_DIR}/${F} $BUILD_DIR/${FDIR}/${F}
else   # Copy version from current Extension
	cp -f /tmp/tcloop/slimserver/${FDIR}/${F} $BUILD_DIR/${FDIR}/${F}
fi
[ "$?" != "0" ] && echo -n "1" > $f

FDIR="usr/local/slimserver"
F="custom-strings.txt"
if [ -e ${DL_DIR}/${F} ]; then  # Copy Updated Version
	cp -f ${DL_DIR}/${F} $BUILD_DIR/${FDIR}/${F}
else   # Copy version from current Extension
	cp -f /tmp/tcloop/slimserver/${FDIR}/${F} $BUILD_DIR/${FDIR}/${F}
fi
[ "$?" != "0" ] && echo -n "1" > $f

###tarfile comes with only user ownership, which breaks symlinks on TC
#Change all files to 644
chmod -R 644 $BUILD_DIR
[ "$?" != "0" ] && echo -n "1" > $f
#Change mode for directories to 755
find $BUILD_DIR -type d | xargs -t -I {} chmod 755 {} > /dev/null 2>&1
[ "$?" != "0" ] && echo -n "1" > $f
#Change mod for executables
find $BUILD_DIR -name "*.pl" | xargs  -t -I {} chmod 755 {} > /dev/null 2>&1
[ "$?" != "0" ] && echo -n "1" > $f
find $BUILD_DIR -name "dbish" | xargs  -t -I {} chmod 755 {} > /dev/null 2>&1
[ "$?" != "0" ] && echo -n "1" > $f

#Copy in new init.d script
FDIR="usr/local/etc/init.d"
F="slimserver"
if [ -e ${DL_DIR}/${F} ]; then  # Copy Updated Version
	cp -f ${DL_DIR}/${F} $BUILD_DIR/${FDIR}/${F}
	chmod 755 $BUILD_DIR/${FDIR}/${F}
else   # Copy version from current Extension
	cp -f /tmp/tcloop/slimserver/${FDIR}/${F} $BUILD_DIR/${FDIR}/${F}
fi
[ "$?" != "0" ] && echo -n "1" > $f

#Copy Update Script
FDIR="usr/local/bin"
F="lms-update.sh"
echo "${DL_DIR}/${F}"
if [ -x "${DL_DIR}/${F}" ]; then  # Copy Updated Version
	cp -f ${DL_DIR}/${F} $BUILD_DIR/${FDIR}/${F}
else   # Copy version from current Extension
	cp -f /tmp/tcloop/slimserver/${FDIR}/${F} $BUILD_DIR/${FDIR}/${F}
fi
[ "$?" != "0" ] && echo -n "1" > $f

) &

rotdash $!
read e < $f
if [ "$e" != "0" ]; then
	echo "${RED}Update FAILED.....exiting!${NORMAL}"
	[ -n "$DEBUG" ] || (rm -rf $SRC_DIR; rm -rf $BUILD_DIR)
	exit 1
fi
rm -f $f

echo
echo
echo -e "${BLUE}Done Updating Files.  The files are ready to be packed into the new extension"
echo
echo "${BLUE}Press Enter to continue, or Ctrl-c to exit${NORMAL}"

[ -z "$UNATTENDED" ] && read key

echo "${GREEN}Creating extension, it may take a while ... especially on rpi 0/A/B/A+/B+"

mksquashfs $BUILD_DIR /tmp/slimserver.tcz -noappend -force-uid 0 -force-gid 50
if [ "$?" != "0" ]; then 
	echo "${RED}Building Extension FAILED...... exiting!${NORMAL}"
	[ -n "$DEBUG" ] || (rm -rf $SRC_DIR; rm -rf $BUILD_DIR)
	exit 1
fi

REBOOT=""
if [ -z "$TEST" ]; then
	if [ -n "$RELOAD" ]; then
		echo "${BLUE}Ready to Reload LMS, Press Enter to Continue${NORMAL}"
		[ -z "$UNATTENDED" ] && read key
		echo "${GREEN}Stopping LMS"
		/usr/local/etc/init.d/slimserver stop
		if [ "$?" != "0" ]; then
			echo "${RED}Extension will be replaced, but a reboot will be requied when finished"
			REBOOT=1
		fi
		echo "${GREEN}Waiting for File Handles to Close"
		CNT=0
		until ! lsof | grep -q /tmp/tcloop/slimserver
		do
			[ $((CNT++)) -gt 10 ] && break || sleep 1
		done
		if [ $CNT -gt 10 ]; then
			echo "${RED}Drive is still busy, Extension will be replaced, but a reboot will be requied when finished"
		 	REBOOT=1
		fi
		if [ -z "$REBOOT" ]; then
			echo "${GREEN}Unmounting Extension${NORMAL}"
			umount -d -f /tmp/tcloop/slimserver
			if [ "$?" != "0" ]; then 
				echo "${RED}Unmounting Filesystem failed......extension will be replaced, but reboot is requried${NORMAL}"
				REBOOT=1
			fi
		fi
		rm -f /usr/local/tce.installed/slimserver
		echo "${GREEN}Moving new Extension to $TCEDIR/optional${NORMAL}"
		md5sum /tmp/slimserver.tcz > $TCEDIR/optional/slimserver.tcz.md5.txt
		sed -i 's|/tmp/||' $TCEDIR/optional/slimserver.tcz.md5.txt
		mv -f /tmp/slimserver.tcz $TCEDIR/optional
		chown tc.staff $TCEDIR/optional/slimserver.tcz*
		echo
		echo "${GREEN}Syncing filesystems${NORMAL}"
		sync
		if [ -z "$REBOOT" ]; then
			echo "${GREEN}Loading new Extension${NORMAL}"
			su - tc -c "tce-load -li slimserver.tcz"
			if [ "$?" != "0" ]; then
				echo "${RED}Problem Mounting new slimserver extension. Please check errors"
				echo "Might just need to reboot${NORMAL}"
			else
				echo "${GREEN}Starting New Version of LMS${NORMAL}"
				/bin/sh -c "/usr/local/etc/init.d/slimserver start"
				echo
			fi
		else
			echo
			echo "${BLUE}Extension copied and will be loaded on next reboot${NORMAL}"
		fi
	else
		echo "${GREEN}Moving new Extension to $TCEDIR/optional${NORMAL}"
		md5sum /tmp/slimserver.tcz > $TCEDIR/optional/slimserver.tcz.md5.txt
		sed -i 's|/tmp/||' $TCEDIR/optional/slimserver.tcz.md5.txt
		mv -f /tmp/slimserver.tcz $TCEDIR/optional
		chown tc.staff $TCEDIR/optional/slimserver.tcz*
		echo
		echo "${GREEN}Syncing filesystems${NORMAL}"
		sync
		echo
		echo "${BLUE}Extension copied and will be loaded on next reboot${NORMAL}"
	fi
else
	md5sum /tmp/slimserver.tcz > /tmp/slimserver.tcz.md5.txt
	sed -i 's|/tmp/||' /tmp/slimserver.tcz.md5.txt
	echo
	echo -e "${BLUE}Done, the new extension was left at /tmp/slimserver.tcz"
	echo
fi
echo
echo "${BLUE}Press Enter to Cleanup and exit${NORMAL}"
echo
[ -z "$UNATTENDED" ] && read key

if [ -z "$DEBUG" ]; then
	echo -e "${GREEN}Deleting the temp folders"
	rm -rf $BUILD_DIR
	rm -rf $SRC_DIR
	#Erase Downloaded Files
	rm -f ${DL_DIR}/*
fi

echo "${BLUE}DONE${NORMAL}"
echo


