#!/bin/bash
# Xymon tools (C) Corentin Labbe <clabbe.montjoie@gmail.com>
# Released under GPLv2

COLUMN='apt'
COLOR='green'
MSG="APT status OK"

umask 027

. /opt/checks/common_xymon

prepare_xymon_state 'apt'
state_add "status+2h $MACHINE.$COLUMN __X_COLOR__ `date` NTP"

check_apt() {
	#TODO test /var/cache/apt/pkgcache.bin time

	create_tmp || return 1
	TMPF=$TMP_FILE
	apt-get -s upgrade > $TMPF
	#test retour

	grep Inst $TMPF | grep -qv Security
	if [ $? -eq 0 ];then
		state_add "&yellow Non-security upgrade to do"
		set_color yellow
		state_add "<ul>"
		grep Inst $TMPF | grep -v Security | cut -d\  -f2,3 |
		while read line
		do
			state_add "<li>$line</li>"
		done
		state_add "</ul>"
	fi
	grep -q Security $TMPF
	if [ $? -eq 0 ];then
		state_add "&red Security upgrade to do"
		set_color red
		state_add "<ul>"
		grep Security $TMPF | cut -d\  -f2,3 |
		while read line
		do
			state_add "<li>$line</li>"
		done
		state_add "</ul>"
	fi
	rm $TMPF

}

if [ -e /etc/apt ];then
	check_apt
fi

add_sonde_version "$XYSTATE"

xymon_finish2 "$XYSTATE"
exit $?
