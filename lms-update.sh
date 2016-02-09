#!/bin/sh
#
#  lms-update.sh
#
#  Script to update slimserver.tcz on piCore 7.x from Logitech 7.9.0 nightly tar pack.
#
#  Script by Paul_123 @ http://forum.tinycorelinux.net/
#  Script Source https://github.com/paul-1/lms-update-script
#  Original script concept by jgrulich
#
#
. /etc/init.d/tc-functions

checkroot
TCEDIR=$(readlink "/etc/sysconfig/tcedir")
NEWARGS="${@}"

while [ $# -gt 0 ]
do
    case "$1" in
        -u)  UNATTENDED=1;;
	-d)  DEBUG=1;;
	-r)  REBOOT=1;;
	-t)  TEST=1;;
	-s)  SKIPUPDATE=1;;
        --)	shift; break;;
        -*) 	echo "usage: $0 [-u] [-d] [-r] [-s] [-t]" 
		echo "  -u Unattended Execution"
		echo "  -d Debug, Temp files not erased"
		echo "  -r Automatic Reboot after Update"
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
echo "            -r Automatic Reboot after Update"
echo "            -s Skip Update from GitHub"
echo "            -t Test building, but do not move extension to tce directory"
echo
[ -n "$UNATTENDED" ] && echo "       Unattended Operation Enabled"
[ -n "$DEBUG" ] && echo "       Debug Enabled"
[ -n "$REBOOT" ] && echo "       Automatic Reboot Enabled"
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
  wget -O /tmp/lms-update.sh https://raw.githubusercontent.com/paul-1/lms-update-script/master/lms-update.sh
  if [ "$?" != "0" ]; then 
    echo "${RED}Download FAILED......Continuing with Current Script !${NORMAL}"
  else
    echo "${GREEN}Relaunching Script in 3 seconds${NORMAL}"
    chmod 755 /tmp/lms-update.sh
    sleep 3
    set -- "-s" $NEWARGS
    exec /bin/sh /tmp/lms-update.sh "${@}"
  fi
fi

echo -ne "${CYAN}Querring the update server ..."
echo

tmp=`mktemp`
wget "http://www.mysqueezebox.com/update/?version=7.9.0&revision=1&geturl=1&os=nocpan" -O $tmp
if [ "$?" != "0" ]; then echo "${RED}Unable to Contact Download Server!${NORMAL}"; rm $tmp; exit 1; fi
read NEWLINK < $tmp
rm -f $tmp

if [ -f  "/usr/local/slimserver/currentversion" ]; then
	read CURVER < /usr/local/slimserver/currentversion
else
	CURVER="Blank"
fi

######This give just the filename echo "${NEWLINK##*/}"

if [ "${NEWLINK##*/}" = "$CURVER" ]; then
#	No Update needed
	echo
	echo "${BLUE}No update needed.${NORMAL}"
	echo "DONE"
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
echo "${GREEN}Updating from $NEWLINK"

DL_DIR=`mktemp -d`
wget -P $DL_DIR $NEWLINK
if [ "$?" != "0" ]; then 
  echo "${RED}Download FAILED...... exiting!${NORMAL}"
  [ -n "$DEBUG" ] || rm -rf $DL_DIR
  exit 1
fi

echo
echo -e "${BLUE}Download Complete. The files will now be extracted"

#  Extract Downloaded File
echo
echo -ne "${GREEN}Extracting Download..."
f=`mktemp`
( tar -xzf $DL_DIR/${NEWLINK##*/} -C $DL_DIR; echo -n $? > $f ) &

rotdash $!
read e < $f
if [ "$e" != "0" ]; then
  echo "${RED}File Extraction FAILED.....exiting!${NORMAL}"
  [ -n "$DEBUG" ] || rm -rf $DL_DIR
  exit 1
fi
rm -f $f

#Erase tar file
[ -n "$DEBUG" ] || rm $DL_DIR/${NEWLINK##*/}

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
mv $DL_DIR/*-noCPAN $BUILD_DIR/usr/local/slimserver
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
if [ -x /tmp/lms-update.sh ]; then
  cp -f /tmp/lms-update.sh $BUILD_DIR/usr/local/bin/lms-update.sh
else
  cp -f /tmp/tcloop/slimserver/usr/local/bin/lms-update.sh $BUILD_DIR/usr/local/bin/lms-update.sh
fi
[ "$?" != "0" ] && echo -n "1" > $f
##Save Nightly Link for next update check
echo ${NEWLINK##*/} > $BUILD_DIR/usr/local/slimserver/currentversion
) &

rotdash $!
read e < $f
if [ "$e" != "0" ]; then
  echo "${RED}Update FAILED.....exiting!${NORMAL}"
  [ -n "$DEBUG" ] || (rm -rf $DL_DIR; rm -rf $BUILD_DIR)
  exit 1
fi
rm -f $f

echo
echo
echo -e "${BLUE}Done Updating Files.  The files are ready to be packed into the new extension"
echo
echo "${BLUE}Press Enter to continue, or Ctrl-c to exit${NORMAL}"

[ -z "$UNATTENDED" ] && read gagme

echo "${GREEN}Creating extension, it may take a while ..."

mksquashfs $BUILD_DIR /tmp/slimserver.tcz -noappend -force-uid 0 -force-gid 50
if [ "$?" != "0" ]; then 
  echo "${RED}Building Extension FAILED...... exiting!${NORMAL}"
  [ -n "$DEBUG" ] || (rm -rf $DL_DIR; rm -rf $BUILD_DIR)
  exit 1
fi

if [ -z "$TEST" ]; then
  md5sum /tmp/slimserver.tcz > $TCEDIR/optional/slimserver.tcz.md5.txt
  mv -f /tmp/slimserver.tcz $TCEDIR/optional
  chown tc.staff $TCEDIR/optional/slimserver.tcz*
  echo
  echo "${GREEN}Syncing filesystems"
  sync
  echo
  echo -e "${BLUE}Done, the new extension was moved to $TCEDIR/optional"
  echo
else 
  echo
  echo -e "${BLUE}Done, the new extension was left at /tmp/slimserver.tcz"
  echo
fi


if [ -z "$DEBUG" ]; then
	echo -e "${GREEN}Deleting the temp folders"
	rm -rf $BUILD_DIR
	rm -rf $DL_DIR
fi

if [ -z "$TEST" ]; then
  echo
  echo "${BLUE}The update was finished, please reboot to take effect."
fi
echo
echo "${BLUE}Press Enter to exit${NORMAL}"
echo

[ -z "$UNATTENDED" ] && read gagme

[ -n "$REBOOT" ] && (echo "${RED}You asked for auto reboot, you got it..... in 10 seconds"; sleep 10;  reboot)
