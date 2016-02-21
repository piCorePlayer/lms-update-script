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
. /etc/init.d/tc-functions

checkroot
TCEDIR=$(readlink "/etc/sysconfig/tcedir")
DL_DIR="/tmp/slimupdate"
NEWARGS="${@}"
GIT_REPO="https://raw.githubusercontent.com/paul-1/lms-update-script/master"

while [ $# -gt 0 ]
do
    case "$1" in
	-u)  UNATTENDED=1;;
	-d)  DEBUG=1;;
	-r)  RELOAD=1;;
	-t)  TEST=1;;
	-s)  SKIPUPDATE=1;;
        --)	shift; break;;
        -*) 	echo "usage: $0 [-u] [-d] [-r] [-s] [-t]" 
		echo "  -u Unattended Execution"
		echo "  -d Debug, Temp files not erased"
		echo "  -r Reload LMS after Update"
		echo "  -s Skip Update from GitHub"
		echo "  -t Test building, but do not move extension to tce directory"
		exit 1;;
    	*)  break;;	# terminate while loop
    esac
    shift
done

[ -z "$UNATTENDED" ] && clear

echo
echo "${BLUE}###############################################################"
echo
echo "  This script will update the Logitech Media Server extension  "
echo
echo "  usage: $0 [-u] [-d] [-r] [-s] [-t]"
echo "            -u Unattended Execution"
echo "            -d Debug, Temp files not erased"
echo "            -r Reload LMS after Update"
echo "            -s Skip Update from GitHub"
echo "            -t Test building, but do not move extension to tce directory"
echo
[ -n "$UNATTENDED" ] && echo "       Unattended Operation Enabled"
[ -n "$DEBUG" ] && echo "       Debug Enabled"
[ -n "$RELOAD" ] && echo "       Automatic Reload Enabled"
[ -n "$SKIPUPDATE" ] && echo "       Skipping Update"
[ -n "$TEST" ] && echo "       Test Mode Enabled"
echo "###############################################################"
echo
echo "Press Enter to continue, or Ctrl-c to exit and change options${NORMAL}"

[ -z "$UNATTENDED" ] && read gagme

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
  FILES="lms-update.sh custom-strings.txt picore-update.htm Custom.pm"
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
  chmod 755 /tmp/lms-update.sh
  sleep 3
  set -- "-s" $NEWARGS
  exec /bin/sh /tmp/lms-update.sh "${@}"
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

[ -z "$UNATTENDED" ] && read gagme

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
#Copy Startup and Update Script
cp -f /tmp/tcloop/slimserver/usr/local/etc/init.d/slimserver $BUILD_DIR/usr/local/etc/init.d/slimserver
[ "$?" != "0" ] && echo -n "1" > $f

FDIR="usr/local/bin"
F="lms_update.sh"
if [ -x ${DL_DIR}/${F} ]; then  # Copy Updated Version
  cp -f ${DL_DIR}/${F} $BUILD_DIR/${FDIR}/${F}
else   # Copy version from current Extension
  cp -f /tmp/tcloop/slimserver/${FDIR}/${F} $BUILD_DIR/${FDIR}/${F}
fi
[ "$?" != "0" ] && echo -n "1" > $f

FDIR="usr/local/slimserver/Slim/Utils/OS"
F="Custom.pm"
if [ -x ${DL_DIR}/${F} ]; then  # Copy Updated Version
  cp -f ${DL_DIR}/${F} $BUILD_DIR/${FDIR}/${F}
else   # Copy version from current Extension
  cp -f /tmp/tcloop/slimserver/${FDIR}/${F} $BUILD_DIR/${FDIR}/${F}
fi
[ "$?" != "0" ] && echo -n "1" > $f

FDIR="usr/local/slimserver/HTML/EN/html/docs"
F="picore-update.html"
if [ -x ${DL_DIR}/${F} ]; then  # Copy Updated Version
  cp -f ${DL_DIR}/${F} $BUILD_DIR/${FDIR}/${F}
else   # Copy version from current Extension
  cp -f /tmp/tcloop/slimserver/${FDIR}/${F} $BUILD_DIR/${FDIR}/${F}
fi
[ "$?" != "0" ] && echo -n "1" > $f

FDIR="usr/local/slimserver"
F="custom-strings.txt"
if [ -x ${DL_DIR}/${F} ]; then  # Copy Updated Version
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

[ -z "$UNATTENDED" ] && read gagme

echo "${GREEN}Creating extension, it may take a while ... especially on rpi 0/A/B/A+/B+"

mksquashfs $BUILD_DIR /tmp/slimserver.tcz -noappend -force-uid 0 -force-gid 50
if [ "$?" != "0" ]; then 
  echo "${RED}Building Extension FAILED...... exiting!${NORMAL}"
  [ -n "$DEBUG" ] || (rm -rf $SRC_DIR; rm -rf $BUILD_DIR)
  exit 1
fi

if [ -z "$TEST" ]; then
  echo "${BLUE}Ready to Reload LMS, Press Enter to Continue${NORMAL}")
  [ -z "$UNATTENDED" ] && read gagme
  echo "${GREEN}Stopping LMS${NORMAL}"
  /usr/local/etc/slimserver stop
  echo "${GREEN}Unmounting Extension${NORMAL}"
  umount /tmp/tcloop/slimserver
  rm -f /usr/local/tce.installed/slimserver
  echo "${GREEN}Moving new Extension to $TCEDIR/optional${NORMAL}"
  md5sum /tmp/slimserver.tcz > $TCEDIR/optional/slimserver.tcz.md5.txt
  mv -f /tmp/slimserver.tcz $TCEDIR/optional
  chown tc.staff $TCEDIR/optional/slimserver.tcz*
  echo
  echo "${GREEN}Syncing filesystems${NORMAL}"
  sync
  echo "${GREEN}Loading new Extension${NORMAL}"
  su - tc -c "tce-load -li slimserver.tcz"
  echo "${GREEN}Starting LMS${NORMAL}"
  /bin/sh -c /usr/local/etc/slimserver start
  echo
else 
  echo
  echo -e "${BLUE}Done, the new extension was left at /tmp/slimserver.tcz"
  echo
fi
echo
echo "${BLUE}Press Enter to Cleanup and exit${NORMAL}"
echo
[ -z "$UNATTENDED" ] && read gagme

if [ -z "$DEBUG" ]; then
	echo -e "${GREEN}Deleting the temp folders"
	rm -rf $BUILD_DIR
	rm -rf $SRC_DIR
	#Erase Downloaded Files
	rm -f ${DL_DIR}/*
fi

echo "${BLUE}DONE${NORMAL}"
echo


