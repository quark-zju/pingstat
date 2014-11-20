#!/bin/bash

cd $(dirname `readlink -f "$0"`)/
[ -z "$HOSTS" ] && HOSTS='www.baidu.com www.google.com'

case "${1:-start}" in
    start)
        cd $(dirname `readlink -f "$0"`)

        for i in $HOSTS; do
            pidof pingstat_$i >/dev/null && continue
            echo "starting pingstat $i"
            ./pingstat.rb $i >/dev/null 2>/dev/null &
            disown
        done
        ;;
    stop)
        for i in $HOSTS; do
            PID=`pidof pingstat_$i`
            [ -z "$PID" ] && continue
            echo "stopping pingstat $i"
            kill $PID
        done
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    *)
        echo "usage: $0 {start|stop|restart}"
esac

