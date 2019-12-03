#!/bin/bash
# chkconfig: 2345 92 18
# description: ActiveMQ Broker Monitor
# edited on: 2019-27-11

# +++++ START EDIT VALUES #
HOME=`dirname $0`
AGENTLOGDIR="${HOME}/../logs"
AGENT_HOST=""
AGENT_PORT=8080
BROKER_CREDS="admin:admin"
BROKER_HOST=""
BROKER_PORT=8161
BROKER_NAME=""
BROKER_PROTO=""
# +++++ END EDIT VALUES #

# +++++ BEGIN FUNCTIONS #
function start(){
    if [ $RUNNING -eq 1 ]; then
        print "$STATUS"
        continue
    fi
    if [ -z "$AGENTLOGDIR" ]; then
        mkdir -p $AGENTLOGDIR
    fi

    CMD="python ../activeMQ.py -H ${AGENT_HOST} -p ${AGENT_PORT} -u ${BROKER_CREDS} -b ${BROKER_HOST} -j ${BROKER_PORT} -n ${BROKER_NAME} -o ${BROKER_PROTO}"
    eval nohup $CMD >> "$LOGFILE" 2>&1 &
    sleep 5
    if [ "x$!" != "x" ] ; then
        PID=`pgrep -f "$BROKER_NAME"`
        ps -ef | awk '/$BROKER_NAME/ {print $2}' | grep $PID > /dev/null
        RESULT=$?
        if [ "$RESULT" != "0" ]; then
            print "$0 $ARG: ActiveMQ Broker Monitor has failed";
            print "Check log files in $AGENTLOGDIR for more information.";
            ERROR=3
        else
            eval echo "$PID" > "$PIDFILE";
            print "$0 $ARG: ActiveMQ Broker Monitor (pid $PID) started";
            break
        fi
    else
        print "$0 $ARG: ActiveMQ Broker Monitor could not be started";
        print "Check log files in $AGENTLOGDIR for more information.";
        ERROR=3
    fi
}

function stop() {
	if [ $RUNNING -eq 0 ]; then
		print "$0 $ARG: $STATUS"
		continue
        fi
        print "Stopping $PID"
        if kill $PID ; then
                RESULT="0"
                COUNT="0"
                while [ $COUNT -lt 3 -a "$RESULT" = "0" ]
                    do
                        sleep 1
                        ps -ef | awk '/$BROKER_NAME/ {print $2}' | grep $PID > /dev/null
                        RESULT=$?
                        COUNT=$[$COUNT+1]
                done
                if [ "$RESULT" = "0" ]; then
                        print "Forcing $PID to stop"
                        kill -9 $PID
                        sleep 1
                        ps -ef | awk '/$BROKER_NAME/ {print $2}' | grep $PID > /dev/null
                        RESULT=$?
                        if [ "$RESULT" = "0" ]; then
                        print "$0 $ARG: ActiveMQ Broker Monitor could not be stopped"
                        ERROR=4
                    fi
                fi
                rm -rf "$PIDFILE"
            echo "$0 $ARG: ActiveMQ Broker Monitor stopped"
        else
            echo "$0 $ARG: ActiveMQ Broker Monitor could not be stopped"
            ERROR=4
        fi
 
}
# +++++ END FUNCTIONS #

ERROR=0
LOGFILE=$AGENTLOGDIR/$BROKER_NAME.log
PIDFILE=$HOME/broker.pid

for ARG_RAW in $@ $ARGS
    do
        if [ -f "$PIDFILE"]; then
            PID=`cat "$PIDFILE"`
            if [ "x$PID" != "x" ] && kill -0 $PID 2>/dev/null ; then
                STATUS="ActiveMQ Broker Monitor (pid $PID) is running"
                RUNNING=1
            else
                STATUS="ActiveMQ Broker Monitor (pid $PID) is not running"
                RUNNING=0
            fi
        else
            STATUS="ActiveMQ Broker Monitor (no pid file) is not running"
            RUNNING=0
        fi

        if [ $ERROR -eq 2 ]; then
            ARG="help"
        else
            ARG=${ARG_RAW}
        fi

        case $ARG in
            [r|R]estart)
                &stop
                sleep 5
                &start
            ;;
            [s|S]tart)
                if [ $RUNNING -eq 1 ]; then
                    print "$STATUS"
                else
                    print "$STATUS"
                    &start
                fi
            ;;
             [s|S]tatus)
                if [ "$RUNNING" -eq 1]; then
                    print "$STATUS"
                else
                    print "$STATUS"
                fi
            ;;
            [s|S]top)
                &stop
            ;;
            *)
                print "usage: $0 (restart|start|status|stop)"
                cat EOF<<
where
    start       - Starts the Broker Monitor
    status      - Status of the Broker Monitor
    stop        - Stops the Broker Monitor
    restart     - Restarts the Broker Monitor
EOF
                ERROR=2
            ;;
        esac
        break
done

exit $ERROR