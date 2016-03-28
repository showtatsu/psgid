#!/bin/bash

#  psgid
#    chkconfig: - 80 20
#
### BEGIN INIT INFO
# Provides: psgid
# Required-Start: $network $syslog
# Required-Stop:  $network $syslog
# Default-Start:
# Default-Stop:
# Description: PSGI application server controller with Server::Starter
# Short-Description: psgi-server control
### END INIT INFO

APL="${0##*/}"
APP_ROOT="/usr/local/psgid"
source "${APP_ROOT}/init/clean.sh"

BOOTSTRAP="/etc/psgid/bootstrap.${APL}.conf"
if [ -f "$BOOTSTRAP" ]; then
    source "$BOOTSTRAP"
else
    echo "WARN: bootstrap file not found. path=[${BOOTSTRAP}]"
fi


ADDR="${ADDR}"
PORT="${PORT:-5000}"
INTERVAL="${INTERVAL:-5}"
USER="${USER}"
CONFIG="${CONFIG:-/etc/psgid/${APL}.yaml}"
PIDFILE="${PIDFILE:-/var/run/psgid/${APL}.pid}"
BOOTLOG="${BOOTLOG:-/var/log/psgid/bootstrap.${APL}.log}"

EXECUTER="${APP_ROOT}/psgid"

KILLTIMER=15
STATUS_URL="${STATUS_URL:-http://${ADDR:-127.0.0.1}:${PORT}/status}"

starter_bin="/usr/local/bin/start_server"
starter_opts="--daemonize"
starter_opts="${starter_opts} --signal-on-hup=USR1"
starter_opts="${starter_opts} --port=${PORT}"
starter_opts="${starter_opts} --interval=${INTERVAL}"
starter_opts="${starter_opts} --pid-file=${PIDFILE}"
starter_opts="${starter_opts} --log-file=${BOOTLOG}"
starter_opts="${starter_opts} -- ${EXECUTER} --config=${CONFIG}"

starter="${USER:+sudo -u ${USER} }${starter_bin} ${starter_opts}"


# set color info if console connected.
if test -t 1; then
    ncolors=$(tput colors)
    if test -n "$ncolors" && test $ncolors -ge 8; then
        normal="$(tput sgr0)"
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
    fi
fi

getpid() {
    local pid=`cat "${PIDFILE}" 2>/dev/null`
    [ -n "$pid" ] && echo -n $pid
}

count() {
    local pid=$(getpid)
    if [ -n "$pid" ]; then
        echo -n `pstree -paAl ${pid} 2>/dev/null | wc -l`
    else
        echo -n "0"
    fi
}

check_root() {
    [ `id -u` -ne 0 ] && echo "root privilege required." && exit 8
}

check_permit() {
    # check required files
    local error=
    [ ! -x ${EXECUTER}   ] && echo "EXECUTER not found [${EXECUTER}]" && exit 9
    [ ! -f ${CONFIG}     ] && echo "CONFIG not found [${CONFIG}]" && exit 9
    [ ! -d ${PIDFILE%/*} ] && echo "PIDFILE's directory required. [${PIDFILE}]" && exit 10
    [ ! -d ${BOOTLOG%/*} ] && echo "BOOTLOG's directory required. [${BOOTLOG}]" && exit 10
    [ ! -d ${PIDFILE%/*} ] && echo "PIDFILE's directory required. [${PIDFILE}]" && exit 10
}

start() {
    local pid=$(getpid)
    if [ -n "$pid" ]; then
        echo "${APL} is already running (pid: ${pid})"
    else
        echo "Starting ${APL} ..."
        ${USER:+sudo -u ${USER} }${starter_bin} ${starter_opts}
        RETVAL=$?
        if [ $RETVAL -ne 0 ]; then
            echo -n "[${red}NG${normal}] Failed to start server. code=[$?]"
        else
            echo "[${green}OK${normal}]"
        fi
        return $RETVAL
    fi
}

stop() {
    local pid=$(getpid)
    if [ -z "$pid" ]; then
        echo "${APL} is not running."
    else
        echo "Stoping ${APL} (pid: ${pid}) ..."
        ${starter_bin} --pid-file=${PIDFILE} --stop
        
        until [ $(count) = '0' ] || [ $looped -gt $KILLWAIT ]; do
            echo -ne "\nWaiting for processes to exit.";
            sleep 1
            let looped=$looped+1;
        done
        
        if [  $(count) != "0" ]; then
            echo -e "[${red}NG${normal}] Failed to stop server ! pid=[${pid}]"
            return 2
        else
            echo "[${green}OK${normal}]"
        fi
    fi
    return 0
}

status() {
    local cnt=$(count)
    local pid=$(getpid)
    if [ "$cnt" -ne "0" ]; then
        echo "${APL} is running (pid:$pid, count:$cnt) "
        echo " [${green}OK${normal}]"
        RETVAL=0
    elif [ -n "$pid" ]; then
        echo "${APL} is not running but PID file ($PIDFILE) remained (pid:$pid)."
        echo " [${red}NG${normal}]"
        RETVAL=2
    else
        echo "${APL} is not running."
        echo " [${red}NG${normal}]"
        RETVAL=1
    fi
    return $RETVAL
}


reload() {
    local cnt=$(count)
    local pid=$(getpid)
    if [ "$cnt" -ne "0" ]; then
        echo -n "Reloading for ${APL} (pid:$pid, count:$cnt)..."
        kill -HUP $pid
        if [ "$?" -eq "0" ]; then
            echo " [${green}OK${normal}]"
            RETVAL=0
        else
            echo " [${red}NG${normal}] Failed to send HUP signal."
            RETVAL=4
        fi
    elif [ -n "$pid" ]; then
        echo "[${red}NG${normal}] ${APL} is not running but PID file ($PIDFILE) remained (pid:$pid)."
        RETVAL=5
    else
        echo "${APL} is not running."
        RETVAL=1
    fi
    return $RETVAL
}

detail() {
    local cnt=$(count)
    local pid=$(getpid)
    if [ "$cnt" -ne "0" ]; then
        echo "${APL} is running (pid:$pid, count:$cnt)"
        curl -s $STATUS_URL
        RETVAL=$?
    elif [ -n "$pid" ]; then
        echo "${APL} is not running but PID file ($PIDFILE) remained (pid:$pid)"
        RETVAL=2
    else
        echo "${APL} is not running."
        RETVAL=1
    fi
    return $RETVAL
}


## command list    

case "$1" in
  start)
        check_root
        check_permit
        start
        RETVAL=$?
        ;;
  stop)
        check_root
        check_permit
        stop
        RETVAL=$?
        ;;
  status)
        status
        RETVAL=$?
        ;;
  detail)
        detail
        RETVAL=$?
        ;;
  restart)
        check_root
        check_permit
        stop
        [ $? -eq "0" ] && sleep 1
        [ $? -eq "0" ] && start
        RETVAL=$?
        ;;
  reload)
        reload
        RETVAL=$?
        ;;
  *)
        echo $"Usage: $prog {start|stop|restart|reload|status}"
        RETVAL=2
esac

exit $RETVAL


