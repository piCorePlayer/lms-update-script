#!/bin/sh
#
#  lms-update.sh
#
#  Script to update slimserver.tcz on piCorePlayer from LMS nightlies.
#
#  Script Source https://github.com/piCorePlayer/lms-update-script
#  Script by Paul_123 @ http://forum.tinycorelinux.net/
#  Original script concept by jgrulich
#
#  Most common usage will be 'sudo lms-update.sh -r'
#
. /etc/init.d/tc-functions

checkroot
TCEDIR=$(readlink "/etc/sysconfig/tcedir")
DL_DIR="/tmp/slimupdate"
# This is the default donwload location, currently overriden in pCP.pm
# The pCP web interface currently uses DL_DIR/update_url to determine if an update is needed
# LMS_DIR="/usr/local/slimserver/Cache/updates"
#
UPDATELINK="${DL_DIR}/update_url"
SCRIPT=$(readlink -f $0)
NEWARGS="${@}"
GIT_REPO="https://raw.githubusercontent.com/piCorePlayer/lms-update-script/prebuilt_tcz"
RELEASE=""
FORCE=0
[ -d ${DL_DIR} ] || mkdir -p ${DL_DIR}

usage(){
	echo "  usage: $0 [-u] [-d] [-m] [-r] [-s] [-t]"
	echo "            -u Unattended Execution"
	echo "            -d Debug, Temp files not erased"
	echo "            -f Force Downgrade"
	echo "            -m Manual download Link Check for LMS update"
	echo "            -r Reload LMS after Update"
	echo "            -s Skip Update from GitHub"
	echo "            --release <release|stable|devel> Update from the selected branch"
	echo
}

O=$(busybox getopt -l help,sss,mm:,release: -- hfmudrts "$@") || exit 1
eval set -- "$O"

while true; do
	case "$1" in
		-u)   UNATTENDED=1;;
		-d)   DEBUG=1;;
		-f)   FORCE=1;;
		-m)   MANUAL=1;;
		--mm) echo "--mm option is depreciated, use the --release option."
				MANUAL=1; RELEASE="release"; shift;;
		-r)   RELOAD=1;;
		--release) MANUAL=1; RELEASE="$2"; shift
			case $RELEASE in
				release|stable|devel);;
				*) echo "release selection error"
					usage
					exit 1;;
			esac
			;;
		-t)  TEST=1;;
		-s)  SKIPUPDATE=1;;
		--sss) RESUME=1;;  #For script relaunch use only, do not use from commandline
		--)	shift; break;;
		-*)  usage; exit 1;;
		*)  break;;	# terminate while loop
	esac
	shift
done

VERSION=$(fgrep "our \$VERSION" /usr/local/slimserver/slimserver.pl | cut -d"'" -f2)

if [ -z "$RESUME" ]; then
	echo
	echo "${BLUE}###############################################################"
	echo
	echo "  This script will update the Lyrion Music Server extension  "
	echo
	[ -n "$RELEASE" ] &&    echo    "       Upgrading from $RELEASE branch."
	[ $FORCE -eq 1 ] &&     echo    "       Forcing downgrade. (If needed)"
	[ -n "$UNATTENDED" ] && echo    "       Unattended Operation Enabled"
	[ -n "$DEBUG" ] &&      echo    "       Debug Enabled"
	[ -n "$MANUAL" ] &&     echo -n "       Manual Download Link Check Enabled"
	[ -n "$VERSION" ] &&    echo    " Version:${VERSION}" || echo ""
	[ -n "$RELOAD" ] &&     echo    "       Automatic Reload Enabled"
	[ -n "$SKIPUPDATE" ] && echo    "       Skipping GitHub Update"
	[ -n "$TEST" ] &&       echo    "       Test Mode Enabled"
	echo "###############################################################"
	echo
	echo "Press Enter to continue, or Ctrl-c to exit and change options${NORMAL}"

	[ -z "$UNATTENDED" ] && read key

	if [ "$SKIPUPDATE" != "1" ]; then
	# Check for depednancy of openssl for wget to work with https://
		if [ ! -x /usr/local/bin/openssl ]; then
			if  [ ! -f $TCEDIR/optional/openssl.tcz ]; then
				echo "${GREEN} Downloading required extension openssl.tcz${NORMAL}"
				echo
				su - tc -c "pcp-load -r https://repo.picoreplayer.org/repo -liw openssl.tcz"
			else
				echo "${GREEN} Loading Local Extension openssl.tcz${NORMAL}"
				echo
				su - tc -c "pcp-load -r https://repo.picoreplayer.org/repo -li openssl.tcz"
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
		set -- "--sss" $NEWARGS
		exec /bin/sh ${DL_DIR}/lms-update.sh "${@}"
	else
		#if we are going to dismount drive to automatically reload extension, we cannot run lms-update.sh from /usr/local/bin
		if [ -n "$RELOAD" ]; then
			echo "${GREEN}Copying and Running script to tmp so we can automatically reload LMS later"
			cp -f ${SCRIPT} ${DL_DIR}/lms-update.sh
			set -- "--sss" $NEWARGS
			exec /bin/sh ${DL_DIR}/lms-update.sh "${@}"
		fi
	fi
fi

if [ -z "$MANUAL" ]; then
	#Not running with manual options, look for URL saved from LMS
	if [ -f  "${UPDATELINK}" ]; then
		read LINK < $UPDATELINK
	else
		LINK="0"
	fi
else
	# This will download the branch xml file to determine the current version
	VERSION=$(fgrep "our \$VERSION" /usr/local/slimserver/slimserver.pl | cut -d"'" -f2)
	REVISION=$(head -n 1 /usr/local/slimserver/revision.txt)
	echo "${YELLOW}Current Version is: $VERSION r${REVISION}.${NORMAL}"

	case $RELEASE in
		release) LATEST="https://lms-community.github.io/lms-server-repository/latest.xml";;
		stable) LATEST="https://lms-community.github.io/lms-server-repository/stable.xml";;
		devel) LATEST="https://lms-community.github.io/lms-server-repository/dev.xml";;
		*) LATEST="https://lms-community.github.io/lms-server-repository/latest.xml";;
	esac

	tmp=$(mktemp)
	wget -q $LATEST -O $tmp
	# Add linefeeds after elements for parsing
	sed -E -i 's/>/>\n/g' $tmp

	while read line; do
		echo $line | grep -q pcp
		if [ $? -eq 0 ]; then
			UPDPKG=$(echo $line)
		fi

	done < $tmp
	rm -f $tmp

	if [ "$UPDPKG" != "" ]; then
		NEW_REVISION=$(echo $UPDPKG | awk -F'revision=' '{print $2}' | cut -d' ' -f1 | sed 's|/>||' | sed 's|"||g')
		NEW_URL=$(echo $UPDPKG | awk -F'url=' '{print $2}' | cut -d' ' -f1 | sed 's|/>||' | sed 's|"||g')
		NEW_VERSION=$(echo $UPDPKG | awk -F'version=' '{print $2}' | cut -d' ' -f1 | sed 's|/>||' | sed 's|"||g')
		NEW_MD5=$(echo $UPDPKG | awk -F'md5=' '{print $2}' | cut -d' ' -f1 | sed 's|/>||' | sed 's|"||g')
	else
		echo "${YELLOW}No update information returned from the download site.  There may not be current packages for the"
		echo "release branch selected.${NORMAL}"
		exit 1
	fi

	if [ $NEW_REVISION -eq $REVISION ]; then
		echo "${GREEN}Already running latest version, use the --release <branch> command line option to change branches.${NORMAL}"
		exit 1
	fi

	if [ $NEW_REVISION -lt $REVISION -a $FORCE -eq 0 ]; then
		echo "${RED}LMS version downgrade selected, you must use the -f command line option to force downgrade.${NORMAL}"
		echo ""
		echo "${YELLOW}If you are currently using a nightly branch, to do manual upgrade, you now must select the desired"
		echo "branch on the command line.  Automatic checks from within LMS will check the appropriate versions."
		echo "   --release release - This option will check for the latest full release of LMS, This is default."
		echo "   --release stable  - This option will check the latest stable branch with nightly bug fix releases."
		echo "   --release devel   - This option will check the latest nightly development branch."
		exit 1
	fi

	LINK=$NEW_URL
fi

if [ "$LINK" = "0" ]; then
#   No Update needed
	if [ -z "$MANUAL" ]; then
		echo
		echo "${BLUE}No update link found.   THis either means that there is no update, or you do not have automatic update"
		echo "checks and automatic downloads enabled in the LMS settings.  If you are running a full release version,"
		echo "there will only be updates when a new release is issued."
		echo
		echo "If you would like to manually check for updates using a static update check, please relaunch this script"
		echo "using the -m command line switch"
		echo
		echo "DONE${NORMAL}"
		exit 0
	else
		echo "${BLUE}Revision $VERSION r${REVISION} is the latest. No Update Needed."
		echo
		echo "DONE.${NORMAL}"
		exit 0
	fi
else
	echo
	echo "${GREEN}Updating from ${LINK}"
fi

function get_tcz_link() {
	echo ""
	echo "Converting from noCPAN build to direct LMS build...."
	NEW_URL=$(echo $1 | sed 's/-noCPAN\.tgz/\.tcz/')
	rm -f ${DL_DIR}/*.json
	echo "Retreiving complete server package listing....${BLUE}"
	wget -P "${DL_DIR}" "https://lms-community.github.io/lms-server-repository/servers.json"
	echo "${GREEN}Finding new package and checksum...."
	PARSEMD5=$(cat ${DL_DIR}/servers.json | JSON.awk - | grep "$NEW_URL" | awk '{print $1}' | sed 's/url/md5/' | sed 's/\[//' | sed 's/\]//')
	NEW_MD5=$(eval echo $(cat ${DL_DIR}/servers.json | JSON.awk - | grep "$PARSEMD5" | awk '{print $2}'))
	LINK="$NEW_URL"
	echo ""
	if [ "$NEW_MD5" = "" ]; then
		echo "${RED}Error getting checksum from servers.json"
		exit 1
	else
		echo "${GREEN}New Update link: $LINK"
		echo "Checksum of the new package: $NEW_MD5"
	fi
	echo ""
}

# Check for extension packages already downloaded
PKG=$(ls -1 ${DL_DIR}/lyrionmusicserver*.tcz 2>/dev/null)
if [ "$PKG" = "" ]; then
	rm -f $DL_DIR/*.tcz*
	# Check for file extension in link, if it is a tgz, it needs converted to tcz
	case "$LINK" in
		*.tgz)
			NEW_URL=""
			NEW_MD5=""
			get_tcz_link $LINK
			if [ "$NEW_URL" = "" -o "$NEW_MD5" = "" ]; then
				echo "${RED}Error finding new Lyrion extension from servers. Please try again."
				exit 1
			fi
		;;
		*);;
	esac

	wget -P $DL_DIR $LINK
	if [ "$?" != "0" ]; then
		echo "${RED}Download FAILED...... exiting!${NORMAL}"
		[ -n "$DEBUG" ] || rm -f $DL_DIR/'*.t?z'
		exit 1
	fi
	FILENAME="$(echo $NEW_URL | awk -F'/' '{ print $NF }')"
	echo "$NEW_MD5  $FILENAME" > ${DL_DIR}/${FILENAME}.md5.txt

	NEWUPDATE=`find ${DL_DIR} -name "*.tcz"`
	if [ -z $NEWUPDATE ]; then
		echo "${BLUE}No Update Found, please make sure Automatic updates and Automatic Downloads are enable in LMS.${NORMAL}"
		echo
		exit 0
	fi
fi

PKG=$(ls -1 $DL_DIR/lyrionmusicserver*.tcz 2>/dev/null)
if [ "$PKG" != "" ]; then
	mv ${PKG} /tmp/slimserver.tcz
	# LMS checks md5 when downloading automatically, 
	# but if this is a manual check, then the md5 needs checked
	if [ -f ${PKG}.md5.txt ]; then
		mv ${PKG}.md5.txt /tmp/slimserver.tcz.md5.txt
		sed -i 's/lyrionmusicserver-.*/slimserver.tcz/' /tmp/slimserver.tcz.md5.txt
		cd /tmp
		md5sum -cs slimserver.tcz.md5.txt
		if [ $? -ne 0 ]; then
			echo "$PKG MD5 does not verify, please try again."
			exit 1
		fi
	fi
fi

REBOOT=""
if [ -z "$TEST" ]; then
	if [ -n "$RELOAD" ]; then
		echo ""
		echo "${BLUE}New Server extension downloaded and tested..."
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
			[ $((CNT++)) -gt 20 ] && break || sleep 1
		done
		if [ $CNT -gt 20 ]; then
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
		mv -f /tmp/slimserver.tcz $TCEDIR/optional
		mv -f /tmp/slimserver.tcz.md5.txt $TCEDIR/optional
		chown tc.staff $TCEDIR/optional/slimserver.tcz*
		echo
		echo "${GREEN}Syncing filesystems${NORMAL}"
		sync
		if [ -z "$REBOOT" ]; then
			# Make sure Custom.pm is removed, pCP has direct support in the downloaded extension
			rm -f /usr/local/slimserver/custom-strings.txt
			rm -f /usr/local/slimserver/Slim/Utils/OS/Custom.pm
			echo "${GREEN}Loading new Extension${NORMAL}"
			su - tc -c "tce-load -li slimserver.tcz"
			if [ "$?" != "0" ]; then
				echo "${RED}Problem Mounting new slimserver extension. Please check errors"
				echo "Might just need to reboot${NORMAL}"
			else
				echo "${GREEN}Starting New Version of LMS${NORMAL}"
				/bin/sh -c "/usr/local/etc/init.d/slimserver start" >/dev/null 2>&1
				echo
			fi
		else
			echo
			echo "${BLUE}Extension copied and will be loaded on next reboot${NORMAL}"
		fi
	else
		echo "${GREEN}Moving new Extension to $TCEDIR/optional${NORMAL}"
		cd /tmp
		md5sum slimserver.tcz > $TCEDIR/optional/slimserver.tcz.md5.txt
		mv -f slimserver.tcz $TCEDIR/optional
		chown tc.staff $TCEDIR/optional/slimserver.tcz*
		echo
		echo "${GREEN}Syncing filesystems${NORMAL}"
		sync
		echo
		echo "${BLUE}Extension copied and will be loaded on next reboot${NORMAL}"
	fi
else
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
	# Remove Downloaded Files
	rm -f ${DL_DIR}/*
fi

echo "${BLUE}DONE${NORMAL}"
echo


