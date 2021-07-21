#########################################################
##              SNMPWALK CHECK WATCHGUARD              ##
#########################################################

# - VAR

# - Bash info
APPNAME=$(basename $0)
AUTHOR="Kalarumeth"
VERSION="v1.0"

# - Default settings for connection
COMMUNITY="public"
HOST_NAME="localhost"
SNMPVERSION="2c"

# - State Variables
STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNK=3

# - Default Outputs
STATE=$STATE_OK
STATE_STRING=""
PERFDATA=""

# - WATCHGUARD OID

# - wgSystemStatisticsMIB
OID_wgSystemTotalSendBytes="1.3.6.1.4.1.3097.6.3.8"
OID_wgSystemTotalRecvBytes="1.3.6.1.4.1.3097.6.3.9"
OID_wgSystemTotalSendPackets="1.3.6.1.4.1.3097.6.3.10"
OID_wgSystemTotalRecvPackets="1.3.6.1.4.1.3097.6.3.11"
OID_wgSystemCpuUtil1="1.3.6.1.4.1.3097.6.3.77"
OID_wgSystemCurrActiveConns="1.3.6.1.4.1.3097.6.3.80"
# - wgIpsecStats
OID_wgIpsecTunnelNum="1.3.6.1.4.1.3097.6.5.1.1"
# - wgInfoSystem
OID_wgInfoGavService="1.3.6.1.4.1.3097.6.1.3.0"
OID_wgInfoIpsService="1.3.6.1.4.1.3097.6.1.4.0"

# - HELP

print_help () {

        echo "----------------------------------{HELP}-----------------------------------"
        echo ''
        print_version
        echo ''
        echo "Script bash for check WatchGuard OIDs"
        echo ''
        print_usage
        echo ''
        echo 'OPTIONS:'
        echo ''
        echo '  -C|--community'
        echo "                  SNMP v2 community string with Read access. Default is 'public'."
        echo ''
        echo '  -H|--host'
        echo '                  [REQUIRED OPTION] Host name or IP address to check. Default is: localhost.'
        echo ''
        echo '  -t|--type'
        echo '                  [REQUIRED OPTION] { ActiveConns | Cpu | InfoGav | IpsecTunnelNum | Transfer }'
        echo ''
        echo '  -h|--help'
        echo '                  Show this help screen'
        echo ''
        echo 'EXAMPLES:'
        echo "                  ./$APPNAME -C public -H localhost -t InfoGav"
        echo ''
        echo "---------------------------------------------------------------------------"

        exit $STATE_UNK

}

print_version() {

    echo "$APPNAME $VERSION"
        echo "$AUTHOR"

}

print_usage(){

        echo ''
        echo 'Usage for SNMP 2c:'
        echo ''
        echo "                  ./$APPNAME -C <SNMP community> -H <host/ip> -t <type to check>"
        echo ''

}

# - SNMPWALK FUNCTION

# - Check System Statistics Send/Recv
CheckTransferData(){

        TOTSENDB=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemTotalSendBytes)
        TOTSENDPKG=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemTotalSendPackets)
        TOTRECVB=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemTotalRecvBytes)
        TOTRECVPKG=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemTotalRecvPackets)

        TSPO=$(echo "$TOTSENDPKG" | cut -d " " -f 4)
        TSBO=$(echo "$TOTSENDB" | cut -d " " -f 4 | awk '{ byte =$1 /1024/1024/1024; print byte }' | xargs printf "%.2f")
        TRPO=$(echo "$TOTRECVPKG" | cut -d " " -f 4)
        TRBO=$(echo "$TOTRECVB" | cut -d " " -f 4 | awk '{ byte =$1 /1024/1024/1024; print byte }' | xargs printf "%.2f")

        TSGB=$(echo "$TOTSENDB" | cut -d " " -f 4 | awk '{ byte =$1 /1024/1024/1024; print byte }' | xargs printf "%.0f")
        TRGB=$(echo "$TOTRECVB" | cut -d " " -f 4 | awk '{ byte =$1 /1024/1024/1024; print byte }' | xargs printf "%.0f")

        echo "Send $TSGB GB / Recive $TRGB GB"

        echo "WatchGuard transfer info:"
        echo ""
        echo "Total Data Send:"
        echo "  $TSPO pkg"
        echo "  $TSBO GB"
        echo ""
        echo "Total Data Recive:"
        echo "  $TRPO pkg"
        echo "  $TRBO GB"

}

# - Check Cpu Utilization   (CPU output 846 > 8.46%)
CheckCpuUtil(){

        CPUUTIL=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemCpuUtil1)

        CPU_STATE=$(echo "$CPUUTIL" | cut -d " " -f 4)
        CPU_PERC=$(echo "$CPU_STATE" | awk '{ cpu =$1 /100; print cpu "%" }')

        case 1 in
            $(($CPU_STATE<= 7900)))     echo "OK! CPU used: $CPU_PERC"
                                        exit $STATE_OK ;;   # 0-79%     Ok
            $(($CPU_STATE<= 8900)))     echo "WARRING! CPU used: $CPU_PERC"
                                        exit $STATE_WARN ;;   # 80-89%    Warring
            $(($CPU_STATE<= 10000)))    echo "CRITICAL! CPU used: $CPU_PERC"
                                        exit $STATE_CRIT ;;   # 90-100%   Critical
                                *)      echo "UNKNOWN! Cpu not found"
                                        exit $STATE_UNK ;;
        esac

}

# - Check Current Active Connections    (WG M70 | Max 3.300.000) 
CheckCurrActiveConns(){

        CAC=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemCurrActiveConns)

        CACO=$(echo "$CAC" | cut -d " " -f 4)
        CAC_A=$(echo "$CACO" | awk '{ one =$1 /3300000; print one }')
        CAC_B=$(echo "$CAC_A" | awk '{ perc =$1 *100; print perc }' | xargs printf "%.2f")

        CAC_TOT=$(echo "Current Active Connections: $CACO of 3.300.000")

        case 1 in
            $(($CACO<= 2607000)))       echo "OK! Active Connections used: $CAC_B%"
                                        echo "$CAC_TOT"
                                        exit $STATE_OK ;;   # 0-79%     Ok
            $(($CACO<= 2937000)))       echo "WARRING! Active Connections used: $CAC_B%"
                                        echo "$CAC_TOT"
                                        exit $STATE_WARN ;;   # 80-89%    Warring
            $(($CACO<= 3300000)))       echo "CRITICAL! Active Connections used: $CAC_B%"
                                        echo "$CAC_TOT"
                                        exit $STATE_CRIT ;;   # 90-100%   Critical
                                *)      echo "UNKNOWN! Current Active Connections not found"
                                        exit $STATE_UNK ;;
        esac

}

# - Check IP Security Tunnel
CheckIpsecTunnelNum(){

        IPSTN=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgIpsecTunnelNum)

        IPSTNO=$(echo "$IPSTN" | cut -d " " -f 4)

        echo "VPN active: $IPSTNO"

}

# - Check Last update of Gateway Antivirus Service
CheckInfoGavService(){

        INFOGAV=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgInfoGavService)

        IGSV=$(echo "$INFOGAV" | cut -d "<" -f 2 | cut -d ">" -f 1)
        IGSD=$(echo "$INFOGAV" | cut -d "(" -f 2 | cut -d ")" -f 1)

        echo "Gateway Antivirus Service: $IGSV"
        echo "Last Update: $IGSD"

}

#########################################################
##                      MAIN CODE                      ##
#########################################################

check_snmp_error(){

         if [[ $1 -ne 0 ]]; then
                echo $2
                exit $STATE_UNK
        fi

}

binaries="snmpwalk snmpget cut tr sed grep awk wc"

for required_binary in $binaries
do
        which $required_binary > /dev/null
        if [ "$?" != '0' ];then
                echo "UNKNOWN: $APPNAME: No usable '$required_binary' binary in '$PATH'"
                exit $STATE_UNK
        fi
done

# Check to see if any parameters were passed
while test -n "$1"; do

        case "$1" in
                --host|-H)
                        HOST_NAME=$2
                        shift
                        ;;
                --comunity|-C)
                        COMMUNITY=$2
                        shift
                        ;;
                --type|-t)
                        CHECK_TYPE=$2
                        shift
                        ;;
                --help|-h)
                        print_help
                        ;;
                --version|-V)
                        print_version
                        exit $STATE
                        ;;
                  *)
                        echo "Unknown argument: $1"
                        print_usage
                        exit $STATE_UNK
                        ;;

        esac

        shift

done

# - Type Check
if [ ! -z $CHECK_TYPE ]; then

        case "$CHECK_TYPE" in
                Transfer)
                        CheckTransferData;;
                Cpu)
                        CheckCpuUtil;;
                ActiveConns)
                        CheckCurrActiveConns;;
                IpsecTunnelNum)
                        CheckIpsecTunnelNum;;
                InfoGav)
                        CheckInfoGavService;;
        esac

else
        echo "Command incomplete!"
        echo ''
        print_help
        STATE=$STATE_UNK
fi

exit $STATE