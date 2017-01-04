#!/bin/bash
# Xymon tools (C) Corentin Labbe <clabbe.montjoie@gmail.com>
# Released under GPLv2

COLUMN='ntp'
COLOR='green'
MSG="NTP status OK"

umask 027

. /opt/checks/common_xymon

prepare_xymon_state 'ntp'
state_add "status+2h $MACHINE.$COLUMN __X_COLOR__ `date` NTP"

detect_rpi

#bad test
if [ -z "`ps aux |grep ntpd | grep -v grep`" ] ; then
	set_color 'red'
	state_add "&red NTPD is not running"
else
	state_add "&green NTPD running"
fi

if [ ! -e /proc/driver/rtc ] ; then
	#For the moment only rpi does not have a RTC
	if [ "$RASPBERRYPI" != 'yes' ];then
		set_color 'red'
	fi
	state_add "&red no RTC"
else
	state_add "<fieldset><legend>`cat /sys/class/rtc/rtc0/name`</legend>"
	#TODO check embeded pour etre sur que BATT_STATUS est ok
	BATT_STATUS="`grep batt_status /proc/driver/rtc | sed 's/^.*: //'`"
	if [ -z "$BATT_STATUS" ];then
		state_add "&clear pas de batterie"
	else
		state_add "&green batt_status $BATT_STATUS"
		if [ "$BATT_STATUS" != "okay" ] ; then
			set_color 'red'
			state_add "&red Pile BIOS a changer stat=$BATT_STATUS"
		fi
	fi
	state_add "</fieldset>"

	#hwclock work only if a RTC exists
	check_tool hwclock "DEFAULT" $XYSTATE

	print_terminal
	TMP="${TMPDIR}/ntp_hwclock"
	LC_ALL=C hwclock |tee $TMP 2>&1 >> $XYSTATE
	RET=$?
	end_terminal
	if [ $RET -ne 0 ];then
		state_add "&red Erreur de hwclock"
	#else
	# TODO
	#	DERIVE=`cat $TMP | sed 's,.*\([0-9][0-9]*\.[0-9][0-9]*\)[[:space:]].*,\1,g'`
	#	state_add "Derive $DERIVE"
	fi

	LC_ALL=C hwclock --noadjfile --localtime 2>&1 >> $TMP
	if [ $? -ne 0 ];then
		state_add "&red Erreur de hwclock"
	else
		state_add "&green hwclock OK"
	fi
	rm $TMP
fi

if [ ! -e /etc/adjtime ];then
	state_add "&green /etc/adjtime not present"
else
	state_add "&yellow /etc/adjtime present"
	#TODO check heavy derive
fi

#check secu ntp
# http://guides.ovh.com/FixNtp
state_add "<fieldset><legend>ntp.conf</legend>"
if [ ! -e /etc/ntp.conf ];then
	set_color 'red'
	state_add "&red /etc/ntp.conf not found"
else
	state_add "&green /etc/ntp.conf found"
	for keyword in nomodify notrap noquery nopeer kod
	do
		if [ -z "`grep ^restrict.*$keyword /etc/ntp.conf`" ];then
			state_add "&yellow missing $keyword"
		else
			state_add "&green $keyword found"
		fi
	done
fi
state_add "</fieldset>"

ntpq -n -c as -c peers > ${TMPDIR}/ntpq.out 2> ${TMPDIR}/ntpq.err
RET=$?

print_terminal
cat ${TMPDIR}/ntpq.out >> $XYSTATE
cat ${TMPDIR}/ntpq.err >> $XYSTATE
end_terminal

if [ $RET -ne 0 ] ; then
	set_color 'red'
	state_add "&red ntpq error"
fi

if [ -z "`grep '^\*' ${TMPDIR}/ntpq.out`" ] ; then
	set_color 'red'
	state_add "&red NTP is non sync"
else
	state_add "&green NTP sync OK"
fi
rm ${TMPDIR}/ntpq.out ${TMPDIR}/ntpq.err

#now check all NTP server
grep ^server /etc/ntp.conf | sed 's,server[[:space:]][[:space:]]*,,g' |
while read ntpserver
do
	state_add "&clear found $ntpserver"
	check_if_resolve "$ntpserver"
done

add_sonde_version "$XYSTATE"

xymon_finish2 "$XYSTATE"
exit $?
