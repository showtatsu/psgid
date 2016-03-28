#!/bin/bash

TAG="$1"
PSLIST=`ps -ef | grep start_serve[r]`
[ -n "$PSLIST" -a -n "$TAG" ] && PSLIST=`echo "${PSLIST[@]}" | egrep "tag=${TAG}$|tag=${TAG}\s"`
[ -n "$PSLIST" ] && PIDS=(`echo "${PSLIST}" | awk '{print $2}'`)


# check if stdout is a terminal...
if test -t 1; then
    ncolors=$(tput colors)
    if test -n "$ncolors" && test $ncolors -ge 8; then
        bold="$(tput bold)"
        normal="$(tput sgr0)"
    fi
fi

echo "${bold}==== free info${normal}"
free
echo

if [ -n "${PIDS}" ]; then
    echo "${bold}start_server: pid=(${PIDS[@]})${normal}"
    echo
    echo "${bold}==== starter process${normal}"
    
    ps -fww -p "${PIDS[@]}"
    
    echo
    echo "${bold}==== process tree${normal}"

    for PID in "${PIDS[@]}"; do
        pstree $PID
    done

    echo
fi


