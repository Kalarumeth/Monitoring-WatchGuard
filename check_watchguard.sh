#!/bin/bash

# - VAR

# - Bash info
APPNAME=$(basename $0)
NAME="Check WatchGuard"
AUTHOR="Kalarumeth"
VERSION="v1.3"
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
STATE=$STATE_OK

# - Range Variables
WA=80
CR=90
maxActiveConns=3300000

# - OID

WatchGuard.OIDS() {
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
}

# - MAIN CODE

Source.HostAlive() {
    for host in $HOST_NAME; do
        ping -c1 -W1 -q $host &>/dev/null
        if [[ $? != 0 ]] ; then
            printf "%s\n" "$host is unreachable"
            exit $STATE_UNK
        fi
    done
}

Source.SNMP() {
    snmpwalk -v $SNMPVERSION -r 1 -t 10 -Oe -c $COMMUNITY $HOST_NAME $1
}

# - WatchGuard Health Monitoring

WatchGuard.Main() {
    Source.HostAlive

    case $1 in
        ac)
            WatchGuard.ActiveConns ;;
        cpu)
            WatchGuard.Cpu ;;
        data)
            WatchGuard.TransferData ;;
        info)
            WatchGuard.Info ;;
        ram)
            WatchGuard.Ram ;;
        *)
            echo "Unknown Monitoring: $1"
            Help.WatchGuard
            STATE=$STATE_UNK ;;
    esac
}

WatchGuard.GetData() {
    WatchGuard.OIDS

    case $1 in
        data)
            totalSendGb=$(Source.SNMP $OID_wgSystemTotalSendBytes | cut -d " " -f 4 | awk '{ byte = $1 /1024/1024/1024; print byte }' | xargs printf "%.0f")
            totalRecvGb=$(Source.SNMP $OID_wgSystemTotalRecvBytes | cut -d " " -f 4 | awk '{ byte = $1 /1024/1024/1024; print byte }' | xargs printf "%.0f")
            totalSendPackets=$(Source.SNMP $OID_wgSystemTotalSendPackets | cut -d " " -f 4)
            totalRecvPackets=$(Source.SNMP $OID_wgSystemTotalRecvPackets | cut -d " " -f 4) ;;
        cpu)
            cpuPercentage=$(Source.SNMP $OID_wgSystemCpuUtil1 | cut -d " " -f 4 | awk '{ cpu = $1 /100; print cpu }') ;;
        ram)
            rawRamAll=$(Source.SNMP $OID_wgMemTotalReal | cut -d " " -f 4)
            rawRamFree=$(Source.SNMP $OID_wgMemAvailReal | cut -d " " -f 4)
            valueRamAllGb=$(echo "$rawRamAll" | awk '{ gbyte = $1 /1024/1024; print gbyte }'  | xargs printf "%.2f")
            valueRamFreeGb=$(echo "$rawRamFree" | awk '{ gbyte = $1 /1024/1024; print gbyte }'  | xargs printf "%.2f")
            printPercetageRam=$(echo "$rawRamFree" "$rawRamAll" | awk '{ ramp = $1 /$2 *100; print ramp }' | xargs printf "%.2f")
            printPercetageRamUsed=$(echo "$printPercetageRam" | awk '{ ramup = 100 - $1; print ramup }')
            rangePercetageRam=$(echo "$printPercetageRamUsed" | cut -d "." -f1)
            rawRamUsed=$(echo "$rawRamAll" "$rawRamFree" | awk '{ used = $1 -$2; print used }')
            valueRamUsedGb=$(echo "$rawRamUsed" | awk '{ gbyte = $1 /1024/1024; print gbyte }'  | xargs printf "%.2f") ;;
        ac)
            rawActiveConns=$(Source.SNMP $OID_wgSystemCurrActiveConns | cut -d " " -f 4)
            rawPercetageActiveConns=$(echo "$rawActiveConns $maxActiveConns" | awk '{ perc = $1 /$2 *100; print perc; }')
            rangeActiveConns=$(echo "$rawPercetageActiveConns" | cut -d "." -f 1 )
            printPercetageActiveConns=$(echo "$rawPercetageActiveConns" | xargs printf "%.2f")
            printValueActiveConns=$(echo "$rawActiveConns" | perl -pe 's/(\d{1,3})(?=(?:\d{3}){1,5}\b)/\1./g')
            printMaxActiveConns=$(echo "$maxActiveConns" | perl -pe 's/(\d{1,3})(?=(?:\d{3}){1,5}\b)/\1./g') ;;
        info)
            ipsecNum=$(Source.SNMP $OID_wgIpsecTunnelNum | cut -d " " -f 4)
            rawInfoGav=$(Source.SNMP $OID_wgInfoGavService)
            InfoGavVers=$(echo "$rawInfoGav" | cut -d "<" -f 2 | cut -d ">" -f 1)
            InfoGavData=$(echo "$rawInfoGav" | cut -d "(" -f 2 | cut -d ")" -f 1)
            rawInfoIps=$(snmpwalk -v $SNMPVERSION -c $COMMUNITY $HOST_NAME $OID_wgInfoIpsService 2>&1 | sed 's/Timeout: No Response.*/Idle/')
            if [ "$rawInfoIps" != "Idle" ] ; then
                rawInfoIps=$(echo $rawInfoIps)
            fi
            InfoIpsVers=$(echo "$rawInfoIps" | cut -d "<" -f 2 | cut -d ">" -f 1)
            InfoIpsData=$(echo "$rawInfoIps" | cut -d "(" -f 2 | cut -d ")" -f 1) ;;
    esac
}

WatchGuard.TransferData() {
    WatchGuard.GetData data
    
    printf "%s\n" "Send $totalSendGb GB / Recive $totalRecvGb GB"
    printf "%s\n" "WatchGuard transfer info:"
    printf "%s\t%s\t%s\n" "Total Data Send:" "$totalSendGb GB" "$totalSendPackets Pkg"
    printf "%s\t%s\t%s\n" "Total Data Recive:" "$totalRecvGb GB" "$totalRecvPackets Pkg"
}

WatchGuard.Cpu() {
    WatchGuard.GetData cpu

    for value in $cpuPercentage; do
        case 1 in
            $(($value <= $WA-1)))
                echo "OK! CPU used: $value%" && exit $STATE_OK ;;
            $(($value <= $CR-1)))
                echo "WARRING! CPU used: $value%" && exit $STATE_WARN ;;
            $(($value > $CR-1)))
                echo "CRITICAL! CPU used: $value%" && exit $STATE_CRIT ;;
        esac
    done
}

WatchGuard.Ram() {
    WatchGuard.GetData ram

    case 1 in
        $(($rangePercetageRam <= $WA-1)))
            printf "%s\n" "OK! RAM used: $valueRamUsedGb / $valueRamAllGb GB ($printPercetageRamUsed%)" "RAM free: $valueRamFreeGb GB ($printPercetageRam%)" && exit $STATE_OK ;;
        $(($rangePercetageRam <= $CR-1)))
            printf "%s\n" "WARRING! RAM used: $valueRamUsedGb / $valueRamAllGb GB ($printPercetageRamUsed%)" "RAM free: $valueRamFreeGb GB ($printPercetageRam%)" && exit $STATE_WARN ;;
        $(($rangePercetageRam > $CR-1)))
            printf "%s\n" "CRITICAL! RAM used: $valueRamUsedGb / $valueRamAllGb GB ($printPercetageRamUsed%)" "RAM free: $valueRamFreeGb GB ($printPercetageRam%)" && exit $STATE_CRIT ;;
    esac
}

WatchGuard.ActiveConns() {
    WatchGuard.GetData ac

    case 1 in
        $(($rangeActiveConns <= $WA-1)))
            printf "%s\n" "OK! Active Connections used: $printPercetageActiveConns%" "Current Active Connections: $printValueActiveConns of $printMaxActiveConns" && exit $STATE_OK ;;
        $(($rangeActiveConns <= $CR-1)))
            printf "%s\n" "WARRING! Active Connections used: $printPercetageActiveConns%" "Current Active Connections: $printValueActiveConns of $printMaxActiveConns" && exit $STATE_WARN ;;
        $(($rangeActiveConns > $CR-1)))
            printf "%s\n" "CRITICAL! Active Connections used: $printPercetageActiveConns%" "Current Active Connections: $printValueActiveConns of $printMaxActiveConns" && exit $STATE_CRIT ;;
    esac
}

WatchGuard.Info() {
    WatchGuard.GetData info
    
    printf "%s\t%s\n\n" "VPN active:" "$ipsecNum"
    printf "%s\n%s\n\n" "Gateway Antivirus Service: $InfoGavVers" " Last Update: $InfoGavData"
    printf "%s\n" "Intrusion Prevention Service: $InfoIpsVers" " Last Update: $InfoIpsData"
}

# - HELP
Help.Main() {
    echo "Script bash for moninitoring WatchGuard Health"
    echo ''
    Help.Usage
    echo ''
    Help.Option
    echo ''
    Help.WatchGuard
    echo ''
    Help.Support
    echo ''
    Help.Info
    echo ''
    exit $STATE_UNK
}

Help.Usage() {
    printf "%s\n" "Method to compose the execution string:" "./$APPNAME -c <SNMP community> -h <host> [-wa <value> -cr <value> -ac <value>] -t <object>"
}

Help.Option() {
    printf "%s\n" "OPTIONS:"
    printf "%s\t%s\t%s\n\t\t\t%s\n" "-c" "--community" "SNMP v2 community string with Read access." " Default is: $COMMUNITY."
    printf "%s\t%s\t\t%s\n\t\t\t%s\n" "-h" "--host" "Host name or IP address to check." " Default is: $HOST_NAME."
    printf "%s\t%s\t%s\n\t\t\t%s\n" "-wa" "--allert-wa" "Defines the threshold for Warning." " Default is: $WA."
    printf "%s\t%s\t%s\n\t\t\t%s\n" "-cr" "--allert-cr" "Defines the threshold for Critical." " Default is: $CR."
    printf "%s\t%s\t%s\n\t\t\t%s\n" "-ac" "--activeconns" "Defines the threshold for Max ActiveConnection." " Default is: $maxActiveConns."
    printf "%s\t%s\t\t%s\n\t\t\t%s\n" "-t" "--type" "[REQUIRED OPTION] Field for select element to check on WatchGuard Device." " { ac | cpu | data | info | ram }"
    printf "%s\t%s\t\t%s\n" "-H" "--help" "Show script help."
    printf "%s\t%s\t%s\n" "-V" "--version" "Show script version."
}

Help.WatchGuard() {
    printf "\n%s\n\n" "WatchGuard Check Function"
    printf "%s\t%s\n\n" "Check" "Description"
    printf "%s\t%s\n" "ac" "Monitoring Active Connection."
    printf "%s\t%s\n" "cpu" "Monitoring Cpu load."
    printf "%s\t%s\n" "data" "Monitoring Data Tranfer."
    printf "%s\t%s\n" "info" "Monitoring Ip Sec, Info Gav Service and Info Ips Service."
    printf "%s\t%s\n" "ram" "Monitoring RAM load."
}

Help.Support(){
    printf "%s\n" "GitHub Supporters:"
    printf "\t%s\n" "kelups"
}

Help.Info() {
    printf "%s\t%s\t%s\n" "INFO:" "$NAME" "$VERSION" "" "$AUTHOR" "$URL"
}

# - COMMAND LINE ENCODER

# - Prompt
while test -n "$1"; do
    case "$1" in
        --host|-h)
            HOST_NAME=$2
            shift ;;
        --comunity|-c)
            COMMUNITY=$2
            shift ;;
        --activeconns|-ac)        
            maxActiveConns=$2
            shift ;;
        --allert-wa|-wa)
            WA=$2
            shift ;;
        --allert-cr|-cr)
            CR=$2
            shift ;;
        --type|-t)
            WatchGuard.Main $2
            shift ;;
        --help|-H)
            Help.Main ;;
        --version|-V)
            Help.Info
            exit $STATE ;;
        *)
            echo "Unknown argument: $1"
            Help.Main
            exit $STATE_UNK ;;
    esac
    shift
done
exit $STATE