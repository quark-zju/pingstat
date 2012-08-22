#!/bin/sh

HOSTS='gateway www.google.com'

cd $(dirname `readlink -f "$0"`)
exec >/dev/null 2>/dev/null

for i in $HOSTS; do
    pidof pingstat_$i && continue
    ./pingstat.rb $i &
done

disown

