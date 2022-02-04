# Check WatchGuard
<img src="https://img.shields.io/badge/Dev by-Kalarumeth-blueviolet?style=flat-square" alt="Dev">
<img src="https://img.shields.io/badge/Code-Bash-orange?style=flat-square&logo=GNU Bash&logoColor=orange" alt="Bash">
<img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="MIT License">

The following script is used to monitor the basic functions of the WatchGuard firewall via snmpwalk scripts and are processed to provide easy-to-read data. It can be run separately or integrated into Icinga2 as a monitoring plugin.

**Important**: *snmpwalk command is required for script to run correctly*


# Update Note

## 1.3 - Code improvements

    +Improved the code
    +Add check host alive before snmp
    +Merge InfoIps, InfoGav and IpsecTunnelNum to one check

<details>
<summary>1.2 - Fix</summary>

    +Fix Warning and Critical state
    +Add ability to set limits for waring and critical on percentage
    +Add ability to set maximum Active Connections for ActiveConns
    +Set default variable warning(80)
    +Set default variable critical(90)
    +Set default variable maximum active connections(3300000)
</details>

<details>
<summary>1.1 - Code improvements</summary>

    +Improved the code
    +Add Check Memory
    +Add Check Info Ips Service
    +Removed unnecessary code
</details>

<details>
<summary>1.0 - Release</summary>

    +Release Script
</details>

# Installation

1. Download the script and give it privilages for run
```
curl -LJO https://raw.githubusercontent.com/Kalarumeth/Check-WatchGuard/main/check_watchguard.sh
```

2. Move to Icinga Plugin Dir
```
Default location: /usr/lib/nagios/plugins
```

3. Add command to Icinga
```
object CheckCommand "check_watchguard" {
    import "plugin-check-command"
    command = [ PluginDir + "/check_watchguard.sh" ]
    arguments += {
        "-ac" = {
            order = 4
            value = "$watchguard_ac$"
        }
        "-c" = {
            order = 0
            required = true
            value = "$snmp_community$"
        }
        "-cr" = {
            order = 3
            value = "$crit$"
        }
        "-h" = {
            order = 1
            required = true
            value = "$address$"
        }
        "-t" = {
            order = 5
            required = true
            value = "$watchguard_type$"
        }
        "-wa" = {
            order = 2
            value = "$warn$"
        }
    }
    vars.snmp_community = "public"
}
```

# Functions

The Script is designed to monitor the following firewall functions:

- **[ac] ActiveConns:**
Active connections in use and total number of active connections;
```
OK! Active Connections used: 0.16%
Current Active Connections: 5.412 of 3.300.000
```
- **[cpu] Cpu:**
Cpu load;
```
OK! CPU used: 2%
```

- **[data] Transfer:**
Information of file size send and recive.
```
Send 1479 GB / Recive 1982 GB
WatchGuard transfer info:
Total Data Send:        1479 GB 1855886728 Pkg
Total Data Recive:      1982 GB 2466423320 Pkg
```

- **[info] Info:**
Information of Active VPN, Intrusion Prevention Service and Gateway Antivirus Service
```
VPN active:     7
Gateway Antivirus Service: gav_version:2022020
 Last Update: Fri, Feb 04 2022 11:54:03 AM
Intrusion Prevention Service: ips_version:18.196
 Last Update: Thu, Feb 03 2022 06:53:47 PM
```

- **[ram] Memory:**
Ram load;
```
OK! RAM used: 2,67 / 3,77 GB (71,00 %)
RAM free: 1,10 GB (29,13 %)
```

# How it work

Method to compose the execution string:

    ./check_watchguard.sh -c <SNMP community> -h <host> [-wa <value> -cr <value> -ac <value>] -t <object>

### OPTIONS:

```
-c  --community     SNMP v2 community string with Read access.
                     Default is: public.
-h  --host          [REQUIRED OPTION] Host name or IP address to check.
                     Default is: localhost.
-wa --allert-wa     Defines the threshold for Warning.
                     Default is: 80.
-cr --allert-cr     Defines the threshold for Critical.
                     Default is: 90.
-ac --activeconns   Defines the threshold for Max ActiveConnection.
                     Default is: 3300000
-t  --type          [REQUIRED OPTION] Field for select element to check on WatchGuard Device.
                     { ac | cpu | data | info | ram }.
-H  --help          Show script help.
-V  --version       Show script version.
```

# Credits

## Author

    Kalarumeth - https://github.com/Kalarumeth

## GitHub Supporters

    kelups

## License

    MIT License - Copyright 2022 Kalarumeth