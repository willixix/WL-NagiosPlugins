#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_snmp_dell_powersupply.pl
# Version : 0.32
# Date    : Dec 22 2007
# Author  : William Leibzon - william@leibzon.org
# Summary : This is nagios plugin that uses SNMP to check status of
#           power supplys and related electricity probes on Dell server
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# =========================== PROGRAM LICENSE ================================
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ===================== INFORMATION ABOUT THIS PLUGIN ========================
#
# This is a nagios plugin that checks status of Power Supplies on Dell servers.
# The plugin can also check voltage probes and battery status.
#
# Quick setup notes:
# 1. The monitoring system should have Dell Openmanage with data available by SNMP.
#    For proper work this should be openmanage 4.x or 5.x or later
# 2. Make sure to check and if necessary adjust the the path to utils.pm
# 3. Make sure you have Net::SNMP perl module installed
#
# Run this with "-h" to find current list of options as documentation is incomplete.
#
# Quick notes on parameters - required are '-n' which is expected number of
# power supplies in the system and for newer systems that report status of
# CPU power supplies (like Dell 1850) you should also specify number of
# CPUs with '-c'. For 1850s and 1950s you can also add '-o' to check status
# of voltage probes and with 1950s you can also add '-b' to check status
# of batteries.
#
# Here is an example for 1850 server with 2 CPUs and 2 power supplies:
#
# define command {
#        command_name check_snmp_dell_powersupplystatus
#        command_line $USER1$/check_snmp_dell_powersupply.pl -H $HOSTADDRESS$ -C $ARG1$ -n $ARG2$ -c $ARG3$ --voltage_probe
# }
#
# define service{
#        use                             generic-service
#        servicegroups                   snmp,env
#        hostgroup_name                  dell_1850
#        service_description             Dell Power Supply Status
#        check_command                   check_snmp_dell_powersupplystatus!foo!2!2
# }
#
# ========================= CHANGES AND TODO =================================
#
# Changes:
#   June 24, 2006 - first version of the plugin
#   June 15, 2007 - bug fixes and top text
#   Nov 20, 2007  - optionally check voltage probes
#   Nov 27, 2007  - optionally check battery status
#   Dec 21, 2007  - bug fixes (forgot to add alarm function,
#                   bad spec for UNKNOWN status), updates docs on top
#
# ToDo:
#
# 1. Rather then being Dell-specific this could possibly be extended
#    to become general plugin for other types of servers
#
# ========================== START OF PROGRAM CODE ===========================

use strict;

use Net::SNMP;
use Getopt::Long;
use lib "/usr/lib/nagios/plugins";
use utils qw(%ERRORS $TIMEOUT);
# my $TIMEOUT = 15;
# my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

my $oid_powersupplystatus=".1.3.6.1.4.1.674.10892.1.600.12.1.10.1";
my $oid_voltageprobe_status=".1.3.6.1.4.1.674.10892.1.600.20.1.16"; #5
my $oid_voltageprobe_names=".1.3.6.1.4.1.674.10892.1.600.20.1.8";
my $oid_battery_state="1.3.6.1.4.1.674.10892.1.600.50.1.6";
my $oid_battery_names="1.3.6.1.4.1.674.10892.1.600.50.1.7";

# these are bitmasks for .1.3.6.1.4.1.674.10892.1.600.12.1.10.1
my %powersupply_statuscodes  = ( 1 => ["OK", "presenceDetected", "The power supply's presence is detected"],
		     2 => ["CRITICAL", "psFailureDetected", "The power supply failure is detected"],
		     4 => ["WARNING", "predictiveFailure", "The power supply sensor detects predictive failure"],
		     8 => ["CRITICAL", "psACLost", "The power supply's AC power is lost"],
		     16 => ["CRITICAL", "acLostOrOutOfRange", "The power supply's AC power is lost or out of range."],
		     32 => ["WARNING", "acOutOfRangeBugPresent", "The power supply's AC power is present, but it is out of range."],
		     64 => ["UNKNOWN", "configurationError", "The power supply sensor detects a configuration error."]
		   );

# these are bit-masks for 1.3.6.1.4.1.674.10892.1.600.50.1.6
my %battery_readings = ( 1 => ["WARNING", "predictiveFailure", "Battery sensor detects predictive failure"],
			 2 => ["CRITICAL", "failed", "Battery has failed"],
			 4 => ["OK", "presenceDetected", "Battery is ok"]
		   );
my $battery_reading_ok = "4"; # that is value from "OK" from above

my $Version='0.32';

my $o_help	=	undef;	# Help me!
my $o_host 	=	undef;	# Hostname variable
my $o_community =	undef;	# Community variable
my $o_port	=	161;	# SNMP port
my $o_verb	=	undef;	# Verbose option
my $o_version	=	undef;	# Version option
my $o_timeout	=	5;	# Request timeout
my $o_numpower  =	2;	# Number of power supplies in the system
my $o_numcpus	=	0;	# Number of cpus for which system reports VRM data
my $o_version2= undef;          # use snmp v2c
# SNMPv3 specific
my $o_login=    undef;          # Login for snmpv3
my $o_passwd=   undef;          # Pass for snmpv3
my $o_datatblretr= undef;       # Retrieve data together as one table instead if individual attribute OIDs
my $o_voltagecheck= undef;	# Check voltage probes
my $o_batterycheck= undef;	# Check battery status

sub print_version { print "check_dell_powersupply.pl: $Version\n" };

sub print_usage {
	print "Usage: $0 [-v] -H <host> -C <snmp_community> | [-P <port>] [-t <timeout>] [-V] [--voltage_probe] [--battery_check] [-n <number of power supplies>] [-c <number of CPUs with their VRM data reported>\n";
}

# Return true if arg is a number
sub isnum {
        my $num = shift;
        if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 1 ;}
        return 0;
}

sub help {
	print "\nDell Power Supply Status Monitor for Nagios version ",$Version,"\n";
	print "Written by William Leibzon - william(at)leibzon.org\n\n";
	print_usage();
	print <<EOD;
-v, --verbose
	print extra debugging information
-h, --help
	print this help message
-H, --hostname=HOST (STRING)
	name or IP address of host to check
-C, --community=COMMUNITY NAME (STRING)
	community name for the host's SNMP agent (implies v 1 protocol)
-2, --v2c
        use SNMP v2 (instead of SNMP v1)
-P, --port=PORT (INTEGER)
	SNMPd port (Default 161)
-t, --timeout=seconds (INTEGER)
	timeout for SNMP in seconds (Default : 5)
-n, --numsupplies=INTEGER
	number of power supplies in the system (Default: 2)
-c  --numcpus=INTEGER
	if your system reports CPU power supply status (1850's do), then add number of active cpus here
-o, --voltage_probe
	Also check voltage probes status (use with 1850s and 1950s)
-b, --battery_check
	Also check status of batteries (use with 1950s)
-V, --version
	prints version number
EOD
}

# Verbose output

sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub check_options {
	Getopt::Long::Configure ("bundling");
	GetOptions(
	'v'	=> \$o_verb,			'verbose'		=> \$o_verb,
	'h'	=> \$o_help,			'help'			=> \$o_help,
	'H:s'	=> \$o_host,			'hostname:s'		=> \$o_host,
	'P:i'	=> \$o_port,			'port:i'		=> \$o_port,
	'C:s'	=> \$o_community,		'community:s'		=> \$o_community,
	't:i'	=> \$o_timeout,			'timeout:i'		=> \$o_timeout,
	'V'	=> \$o_version,			'version'		=> \$o_version,
        '2'     => \$o_version2,        	'v2c'			=> \$o_version2,
	'n:i'   => \$o_numpower,		'numsupplies:i'		=> \$o_numpower,
	'c:i'	=> \$o_numcpus,			'numcpus:i'		=> \$o_numcpus,
	'o'	=> \$o_voltagecheck,		'voltage_probe'		=> \$o_voltagecheck,
	'b'	=> \$o_batterycheck,		'battery_check'		=> \$o_batterycheck,
	'R'     => \$o_datatblretr,		'retreive_tablewalk'	=> \$o_datatblretr
	);

	if (defined ($o_help)) { help(); exit $ERRORS{"UNKNOWN"}};
	if (defined ($o_version)) { print_version(); exit $ERRORS{"UNKNOWN"}};
	if ( ! defined($o_host)) { print_usage(); exit $ERRORS{"UNKNOWN"}};
	if ( ! defined($o_community)) { print "Include SNMP Community\n"; print_usage(); exit $ERRORS{"UNKNOWN"}};
};

sub exit_snmperror {
	my ($ses,$err)=@_;
	printf("%s: %s\n", $err, $ses->error);
	$ses->close();
	exit $ERRORS{"UNKNOWN"};
}

# Get the alarm signal (just in case snmp timout screws up)
$SIG{'ALRM'} = sub {
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $ERRORS{"UNKNOWN"};
};

# MAIN CODE

check_options();

# Check global timeout if something goes wrong
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT");
  alarm($TIMEOUT);
} else {
  verb("no timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

# SNMP Connection to the host
my ($session,$error);
if (defined($o_login) && defined($o_passwd)) {
  # SNMPv3 login
  verb("SNMPv3 login");
  ($session, $error) = Net::SNMP->session(
      -hostname         => $o_host,
      -version          => '3',
      -username         => $o_login,
      -authpassword     => $o_passwd,
      -authprotocol     => 'md5',
      -privpassword     => $o_passwd,
      -timeout          => $o_timeout
   );
} else {
   if (defined ($o_version2)) {
     # SNMPv2 Login
         ($session, $error) = Net::SNMP->session(
        -hostname  => $o_host,
        -version   => 'snmpv2c',
        -community => $o_community,
        -port      => $o_port,
        -timeout   => $o_timeout
     );
   } else {
    # SNMPV1 login
    ($session, $error) = Net::SNMP->session(
       -hostname  => $o_host,
       -community => $o_community,
       -port      => $o_port,
       -timeout   => $o_timeout
    );
  }
}

if (!defined($session)) {
	printf("ERROR opening session: %s.\n", $error);
	exit $ERRORS{"UNKNOWN"};
}

my $statuscode = "OK";
my $statusinfo = "";
my $perfdata = "";
my @varlist = ();
my $snmpstatus = "";
my $i;
my $j;
my $result;
my $oid;

if (defined($o_datatblretr)) {
	verb("Retrieving SNMP table $oid_powersupplystatus");
        $result = $session->get_table( -baseoid => $oid_powersupplystatus );
	exit_snmperror($session,sprintf("ERROR: Problem retrieving OID %s table", $oid_powersupplystatus)) if !defined($result);
}
else {
	for ($i=1; $i<=$o_numpower+$o_numcpus; $i++) {
        	push (@varlist, $oid_powersupplystatus.".$i");
	}
	$result = $session->get_request( -Varbindlist => \@varlist );
       	exit_snmperror($session,sprintf("ERROR: Can not retrieve OID(s) %s", join(@varlist))) if !defined($result);
}

for ($i=1; $i<=$o_numpower+$o_numcpus; $i++) {
	$snmpstatus=$result->{$oid_powersupplystatus.".$i"};
	verb("Power Supply $i: $oid_powersupplystatus.$i : $snmpstatus") if $i<=$o_numpower;
	verb("CPU#".($i-$o_numpower)." VRM $oid_powersupplystatus.$i : $snmpstatus") if $i>$o_numpower;
	if (!isnum($snmpstatus)) {
		$statusinfo.= " Problem with Power Supply $i - SNMP returned: ".$snmpstatus;
		$statuscode = "UNKNOWN";
	}
	elsif ($snmpstatus eq "1") {
		$statusinfo .= ", " if $statusinfo;
		$statusinfo .= "Power Supply $i is OK" if $i<=$o_numpower;
		$statusinfo .= " CPU#" . ($i-$o_numpower) . " VRM is OK" if $i>$o_numpower;
	}
	else {
		$statusinfo .= ", " if $statusinfo;
		$statusinfo .= "Problem with Power Supply $i:" if $i<=$o_numpower;
		$statusinfo .= " Problem with CPU#" . ($i-$o_numpower) . " VRM:" if $i>$o_numpower;
		foreach $j (keys %powersupply_statuscodes) {
			if ($snmpstatus % $j == 0) {
				$statusinfo .= " " . $powersupply_statuscodes{$j}[2];
				$statuscode = $powersupply_statuscodes{$j}[0] if $ERRORS{$statuscode} < $ERRORS{$powersupply_statuscodes{$j}[0]};
				verb("Problem $powersupply_statuscodes{$j}[1] with supply $i: $powersupply_statuscodes{$j}[2]. Setting state to $powersupply_statuscodes{$j}[0]");
			}
		}
	}
}

if (defined($o_voltagecheck)) {
        verb("Retrieving SNMP table $oid_voltageprobe_status");
        $result = $session->get_table( -baseoid => $oid_voltageprobe_status );
        exit_snmperror($session,sprintf("ERROR: Problem retrieving voltage OID %s table", $oid_voltageprobe_status)) if !defined($result);
	my $num_okvprobes=0;
	foreach $oid (keys %{$result}) {
		verb("Voltage table: $oid = ".$result->{$oid});
		if ($result->{$oid} ne 1) { # 1 is "ok" for voltage probe, 2 is "bad"
			$oid =~ s/$oid_voltageprobe_status/$oid_voltageprobe_names/;
			my $result2 = $session->get_request( -Varbindlist => [ $oid ] );
			exit_snmperror($session, "ERROR: Can not retrieve voltage names OID ".$oid) if !defined($result2);
			$statusinfo .= ", " if $statusinfo;
			$statusinfo .= " Voltage Probe '".$result2->{$oid}."' reports failure";
			$statuscode = "CRITICAL";
		}
		else {
			$num_okvprobes++;
		}
	}
	if ($num_okvprobes>0) {
		$statusinfo .= ", " if $statusinfo;
		$statusinfo .= "$num_okvprobes Voltage Probes are OK";
	}
}

if (defined($o_batterycheck)) {
        verb("Retrieving SNMP table $oid_battery_state");
        $result = $session->get_table( -baseoid => $oid_battery_state );
        exit_snmperror($session,sprintf("ERROR: Problem retrieving battery OID %s table", $oid_battery_state)) if !defined($result);
	my $num_okbats=0;
        foreach $oid (keys %{$result}) {
		$snmpstatus = $result->{$oid};
		verb("Battery table: $oid = $snmpstatus");
		if (!isnum($snmpstatus)) {
			$statusinfo .= ", " if $statusinfo;
                	$statusinfo.= "Unknown Problem with battery probe - SNMP ".$oid." returned: ".$snmpstatus;
                	$statuscode = "UNKNOWN";
        	}
		elsif ($snmpstatus eq $battery_reading_ok) {
			$num_okbats++;
        	}
        	else {
                        $oid =~ s/$oid_battery_state/$oid_battery_names/;
                        my $result2 = $session->get_request( -Varbindlist => [ $oid ] );
                        exit_snmperror($session, "ERROR: Can not retrieve battery names OID ".$oid) if !defined($result2);
			$statusinfo .= ", " if $statusinfo;
                        $statusinfo .= "Problem with Battery '".$result2->{$oid}."':";
                	foreach $j (keys %battery_readings) {
                        	if ($snmpstatus % $j == 0) {
                                	$statusinfo .= " " . $battery_readings{$j}[2];
                                	$statuscode = $battery_readings{$j}[0] if $ERRORS{$statuscode} < $ERRORS{$battery_readings{$j}[0]};
                                	verb("Problem $battery_readings{$j}[1] with battery $result2->{$oid}: $battery_readings{$j}[2]. Setting state to $battery_readings{$j}[0]");
                        	}
                	}
		}
        }
	if ($num_okbats>0) {
		$statusinfo .= ", " if $statusinfo;
		$statusinfo .= "$num_okbats Batteries are OK";
	}
}


$session->close();

print $statuscode . " - " . $statusinfo . "\n";
exit $ERRORS{$statuscode};
