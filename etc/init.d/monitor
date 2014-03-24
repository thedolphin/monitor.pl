#!/bin/bash

#
# chkconfig: - 55 45
# description: zabbix monitoring script
# probe: false
#

### BEGIN INIT INFO
# Provides:           zabbix-monitor-pl
# Required-Start:     $network $remote_fs $syslog
# Required-Stop:      $network $remote_fs $syslog
# Default-Start:      2 3 4 5
# Default-Stop:       0 1 6
# Short-Description:  Perl-based Zabbix Agent
# Description:        Perl-based Zabbix Agent
### END INIT INFO

# Written by Alexander Rumyantsev

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up. If you are running without a network, comment this out.
[ "${NETWORKING}" = "no" ] && exit 0

daemon="monitor.pl"
pidfile="/var/run/monitor.pid"
command="/usr/bin/$daemon"
lockf="/var/lock/subsys/$daemon"

murder() {
    pids=`ps -e -o comm= -o pid= | awk "BEGIN { ORS=\" \" } /^$daemon / {print \\$2}"`
    kill -9 $pids
    rm -f $pidfile >/dev/null 2>&1
    rm -f $lockf   >/dev/null 2>&1
}

is_running() {
    # try to find process by its pidfile
    if [ -e $pidfile ]; then
        pid=`cat $pidfile 2>/dev/null`
        if ps -o comm= $pid | grep "^$daemon$" >/dev/null 2>&1; then
            return 0;
        fi
    fi

    # ensure master process alive and single
    pcount=`ps -o comm= --ppid=1 | grep -c "^$daemon$" 2>/dev/null`
    if [ $pcount -gt 1 ]; then
        murder
        return 1
    fi

    # find the pid of master process and write it
    pid=`ps -o comm= -o pid= --ppid=1 | awk "/^$daemon / {print \\$2}" 2>/dev/null`;
    if [ "$pid" ]; then
        echo $pid > $pidfile
        return 0
    fi

    return 1
}

stopmaster() {
    pid=`cat $pidfile 2>/dev/null`
    countdown=5

    kill $pid

    while [ $countdown -gt 0 ] && is_running >/dev/null; do
        echo -n .
        let countdown--
        sleep 1
    done

    if [ $countdown -eq 0 ]; then
        murder
    else
        rm -f $lockf >/dev/null 2>&1
        rm -f $pidfile >/dev/null 2>&1
    fi
}


start() {
    echo -n "Starting $daemon: "

    if is_running; then
        echo -n "already running"
        failure "$daemon start: already running"
        echo
        exit 1
    fi

    if $command; then
        sleep 1
        if is_running; then
            success "$daemon started"
            echo
            touch $lockf;
            exit 0
        else
            echo -n "daemon died suddenly"
            failure "$daemon start: daemon died suddenly"
            echo
            exit 1
        fi
    else
        failure "$daemon start: failed to start"
        echo
        exit 1
    fi
}

stop() {
    echo -n "Stopping $daemon: "
    if is_running; then
        stopmaster
        success "$daemon stopped"
        echo
        exit 0
    else
        echo -n "not running"
        failure "$daemon stop: not running"
        echo
        exit 1
    fi
}


restart() {
    $0 stop
    $0 start
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    forcestop)
        is_running && murder
        ;;
    restart)
        restart
        ;;
    condrestart)
        [ -f $lockf ] && restart
        ;;
    status)
        if is_running; then
            echo "$daemon is running"
        else
            echo "$daemon is not running"
        fi
        ;;
    *)
        echo $"Usage: $0 {start|stop|forcestop|restart|condrestart}"
        exit 1
esac

exit $?
