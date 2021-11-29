# Check WatchGuard

The following script is used to monitor the basic functions of the WatchGuard M370 firewall via snmpwalk scripts and are processed to provide easy-to-read data. It can be run separately or integrated into **Icinga2** as a monitoring plugin.

# Functions

The Script is designed to monitor the following firewall functions:

- **ActiveConns:**
Active connections in use and total number of active connections;
```
OK! Active Connections used: 0.10%
Current Active Connections: 3265 of 3.300.000
```
- **Cpu:**
Cpu load;
```
OK! CPU used: 2%
```
- **InfoIps:**
Last version of Intrusion Prevention Service and last update date;
```
Intrusion Prevention Service: ips_version:18.184
Last Update: Tue, Nov 23 2021 07:01:25 PM
```
- **InfoGav:**
Last version of Gateway Antivirus Service and last update date;
```
Gateway Antivirus Service: gav_version:20210720
Last Update: Tue, Jul 20 2021 12:00:00 PM
```
- **IpsecTunnelNum:**
Counter of current active VPN;
```
VPN active: 6
```
- **Memory:**
Ram load;
```
OK! RAM used: 2,67 / 3,77 GB (71,00 %)
RAM free: 1,10 GB (29,13 %)
```
- **Transfer:**
Information of file size send and recive.
```
Send 801 GB / Recive 744 GB
WatchGuard transfer info:
Total Data Send:
898739895 pkg
801.21 GB
Total Data Recive:
810715453 pkg
744.17 GB
```

# How it work

Script bash for check WatchGuard OIDs

    ./check_watchguard.sh -C <SNMP community> -H <host/ip> -t <type to check>


### OPTIONS:

**-C|--community**
SNMP v2 community string with Read access. Default is public.`

**-H|--host**
*[REQUIRED OPTION]* Host name or IP address to check. Default is localhost.

**-t|--type**
*[REQUIRED OPTION]* { ActiveConns | Cpu | InfoIps | InfoGav | IpsecTunnelNum | Memory | Transfer }.

**-h|--help**
Show help.

### INFO: Check Watchguard v1.1

    Kalarumeth - https://github.com/Kalarumeth/Check-WatchGuard

### GitHub Supporters:

    kelups

### EXAMPLES:

    ./check_watchguard.sh -C public -H localhost -t InfoGav

