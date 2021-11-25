#!/bin/sh

# - VAR

# - Bash info
APPNAME=$(basename $0)
NAME="Check Watchguard"
AUTHOR="Kalarumeth"
VERSION="v1.1"
URL="https://github.com/Kalarumeth/Check-WatchGuard"

# - Default settings for connection
COMMUNITY="public"
HOST_NAME="localhost"
SNMPVERSION="2c"

# - State Variables
STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNK=3

# - Range Variables

CPU_OK=7900
CPU_WA=8900
CPU_CR=10000

RAM_OK=80
RAM_WA=80
RAM_CR=90

CAC_OK=2607000
CAC_WA=2937000
CAC_CR=3300000

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
# - wgMem
OID_wgMemTotalReal="1.3.6.1.4.1.2021.4.5.0"
OID_wgMemAvailReal="1.3.6.1.4.1.2021.4.6.0"
# - wgIpsecStats
OID_wgIpsecTunnelNum="1.3.6.1.4.1.3097.6.5.1.1"
# - wgInfoSystem
OID_wgInfoGavService="1.3.6.1.4.1.3097.6.1.3.0"
OID_wgInfoIpsService="1.3.6.1.4.1.3097.6.1.4"

# - HELP

print_help(){
        echo ''
        echo "Script bash for check WatchGuard OIDs"
        echo ''
        print_usage
        echo ''
        print_options
        echo ''
        print_info
        echo ''
        print_sup
        echo ''
        exit $STATE_UNK
}

print_usage(){
        echo "  ./$APPNAME -C <SNMP community> -H <host/ip> -t <type to check>"
}

print_options(){
        echo 'OPTIONS:'
        echo ''
        echo "  -C|--community  SNMP v2 community string with Read access. Default is 'public'."
        echo ''
        echo "  -H|--host       [REQUIRED OPTION] Host name or IP address to check. Default is: localhost."
        echo ''
        echo "  -t|--type       [REQUIRED OPTION] { ActiveConns | Cpu | InfoIps | InfoGav | IpsecTunnelNum | Memory | Transfer }."
        echo ''
        echo "  -h|--help       Show help."
}

print_info(){
        echo "INFO: $NAME $VERSION"
        echo "      $AUTHOR - $URL"
}

print_sup(){
        echo 'GitHub Supporters:'
        echo "      kelups"
}

# - SNMPWALK FUNCTION

# - Check System Statistics Send/Recv
CheckTransferData(){

        TOTSENDB=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemTotalSendBytes)
        TOTSENDPKG=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemTotalSendPackets)
        TOTRECVB=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemTotalRecvBytes)
        TOTRECVPKG=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemTotalRecvPackets)

        TSPO=$(echo "$TOTSENDPKG" | cut -d " " -f 4)
        TSBO=$(echo "$TOTSENDB" | cut -d " " -f 4 | awk '{ byte = $1 /1024/1024/1024; print byte }' | xargs printf "%.2f")
        TRPO=$(echo "$TOTRECVPKG" | cut -d " " -f 4)
        TRBO=$(echo "$TOTRECVB" | cut -d " " -f 4 | awk '{ byte = $1 /1024/1024/1024; print byte }' | xargs printf "%.2f")
        TSGB=$(echo "$TOTSENDB" | cut -d " " -f 4 | awk '{ byte = $1 /1024/1024/1024; print byte }' | xargs printf "%.0f")
        TRGB=$(echo "$TOTRECVB" | cut -d " " -f 4 | awk '{ byte = $1 /1024/1024/1024; print byte }' | xargs printf "%.0f")

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

# - Check Cpu Utilization
CheckCpuUtil(){

        CPUUTIL=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemCpuUtil1)

        CPU_STATE=$(echo "$CPUUTIL" | cut -d " " -f 4)
        CPU_PERC=$(echo "$CPU_STATE" | awk '{ cpu =$1 /100; print cpu "%" }')

        case 1 in
            $(($CPU_STATE<= $CPU_OK)))  echo "OK! CPU used: $CPU_PERC"
                                        exit $STATE_OK ;;       # 0-79%     Ok
            $(($CPU_STATE<= $CPU_WA)))  echo "WARRING! CPU used: $CPU_PERC"
                                        exit $STATE_WARN ;;     # 80-89%    Warring
            $(($CPU_STATE<= $CPU_CR)))  echo "CRITICAL! CPU used: $CPU_PERC"
                                        exit $STATE_CRIT ;;     # 90-100%   Critical
                                *)      echo "UNKNOWN! Cpu not found"
                                        exit $STATE_UNK ;;
        esac
}

# - Check Memory Utilization
CheckMemory(){

        RAMIM=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgMemTotalReal)
        RAMAR=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgMemAvailReal)

        RAM_ALL=$(echo "$RAMIM" | cut -d " " -f4 )
        RAM_FRE=$(echo "$RAMAR" | cut -d " " -f4 )
        RAM_ALLK=$(echo "$RAM_ALL" | awk '{ kbyte = $1 /1024/1024; print kbyte }'  | xargs printf "%.2f")
        RAM_FREK=$(echo "$RAM_FRE" | awk '{ kbyte = $1 /1024/1024; print kbyte }'  | xargs printf "%.2f")
        RAM_PERC=$(echo "$RAM_FRE" "$RAM_ALL" | awk '{ ramp = $1 /$2 *100; print ramp }' | xargs printf "%.2f" )
        RAM_UPERC=$(echo "$RAM_PERC" | awk '{ ramup = 100 - $1; print ramup }' | xargs printf "%.2f" )
        RAM_USE=$(echo "$RAM_ALL" "$RAM_FRE" | awk '{ used = $1 -$2; print used }' )
        RAM_USEK=$(echo "$RAM_USE" | awk '{ kbyte = $1 /1024/1024; print kbyte }'  | xargs printf "%.2f")

        case 1 in
            $(($RAM_FRE > (100-$RAM_OK)*$RAM_ALL/100))) echo "OK! RAM used: $RAM_USEK / $RAM_ALLK GB ($RAM_UPERC %)"
                                                        echo "RAM free: $RAM_FREK GB ($RAM_PERC %)"
                                                        exit $STATE_OK ;;       # 0-79%     Ok
            $(($RAM_FRE<= (100-$RAM_WA)*$RAM_ALL/100))) echo "WARRING! RAM used: $RAM_USEK / $RAM_ALLK GB ($RAM_UPERC %)"
                                                        echo "RAM free: $RAM_FREK GB ($RAM_PERC %)"
                                                        exit $STATE_WARN ;;     # 80-89%    Warring
            $(($RAM_FRE<= (100-$RAM_CR)*$RAM_ALL/100))) echo "CRITICAL! RAM used: $RAM_USEK / $RAM_ALLK GB ($RAM_UPERC %)"
                                                        echo "RAM free: $RAM_FREK GB ($RAM_PERC %)"
                                                        exit $STATE_CRIT ;;     # 90-100%   Critical
                                                *)      echo "UNKNOWN! RAM not found"
                                                        exit $STATE_UNK ;;
        esac
}

# - Check Current Active Connections
CheckCurrActiveConns(){

        CAC=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgSystemCurrActiveConns)

        CACO=$(echo "$CAC" | cut -d " " -f 4)
        CAC_A=$(echo "$CACO" | awk '{ one =$1 /3300000; print one }')
        CAC_B=$(echo "$CAC_A" | awk '{ perc =$1 *100; print perc }' | xargs printf "%.2f")
        CAC_TOT=$(echo "Current Active Connections: $CACO of 3.300.000")

        case 1 in
            $(($CACO<= $CAC_OK)))       echo "OK! Active Connections used: $CAC_B%"
                                        echo "$CAC_TOT"
                                        exit $STATE_OK ;;       # 0-79%     Ok
            $(($CACO<= $CAC_WA)))       echo "WARRING! Active Connections used: $CAC_B%"
                                        echo "$CAC_TOT"
                                        exit $STATE_WARN ;;     # 80-89%    Warring
            $(($CACO<= $CAC_CR)))       echo "CRITICAL! Active Connections used: $CAC_B%"
                                        echo "$CAC_TOT"
                                        exit $STATE_CRIT ;;     # 90-100%   Critical
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

# - Check Last update of Intrusion Prevention Service
CheckInfoIpsService(){

        INFOIPS=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgInfoIpsService 2>&1 | sed 's/Timeout: No Response.*/Idle/')
        if [ "$INFOIPS" != "Idle" ] ; then
                INFOIPS=$(echo $INFOIPS)
        fi

        IISV=$(echo "$INFOIPS" | cut -d "<" -f 2 | cut -d ">" -f 1)
        IISD=$(echo "$INFOIPS" | cut -d "(" -f 2 | cut -d ")" -f 1)

        echo "Intrusion Prevention Service: $IISV"
        echo "Last Update: $IISD"

}

# - COMMAND LINE ENCODER

# - Prompt
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
                        print_info
                        exit $STATE
                        ;;
                *)
                        echo "Unknown argument: $1"
                        print_help
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
                Memory)
                        CheckMemory;;
                ActiveConns)
                        CheckCurrActiveConns;;
                IpsecTunnelNum)
                        CheckIpsecTunnelNum;;
                InfoGav)
                        CheckInfoGavService;;
                InfoIps)
                        CheckInfoIpsService;;
                *)
                        echo "Command incomplete!"
                        print_help
                        STATE=$STATE_UNK
        esac

fi

exit $STATE