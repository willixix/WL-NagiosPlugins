#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_snmp_baytech_pdu.pl
# Version : 0.25
# Date    : Dec 19, 2011
# Author  : William Leibzon - william@leibzon.org
# Summary : This is a nagios plugin that checks Baytech PDUs.
#           It will report Current, Temperature, Power when you
#	    give it name of the PDU to be checked.
# Licence : GPL - summary below, text at http://www.fsf.org/licenses/gpl.txt
#
# =========================== PROGRAM LICENSE =================================
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
# ===================== INFORMATION ABOUT THIS PLUGIN =========================
#
# This is a nagios plugin that checks Baytech PDUs. It will report Current,
# Voltage, Power, Temperature when you give it name of the PDU to be checked.
#
# This program is written and maintained by:
#   William Leibzon - william(at)leibzon.org
#
# ============================= SETUP NOTES ====================================
#
# Make sure to check and if necessary adjust the the path to utils.pm
# Make sure you have Net::SNMP perl module installed
#
# This plugin will first read RPC names table to find which RPCs you have.
# It will then compare that to name given with '-n' and if there is a match
# will further lookup data for that RPC. If no name is specifed with '-n'
# the plugin will report data for all RPCs which can be up to 16 and that
# is a lot of data especially you each RPC has multiple breakers you all check
#
# The data plugin can lookup for each RPC is: Current in Amps, Potential
# difference in Volts, Power use in Watts and Temperature (which you can
# choose to receive in Celsius or Fahrenheit). The plugin is designed to
# report instant values that is why "Max Current" which is also available
# from PDU data is not used (if you need that modify plugin code yourself -
# its easy to replace 'current' with that and I provided OID below).
#
# You can choose to just report particular data or to check data and
# have plugin report WARNING or CRITICAL if its outside of expected range.
# To just report the data specify for example "--current" with no
# additional values after. If you want to have thereshold for it then
# specify parameter as for example "--current=5,15". That means you
# want WARNING if current is <5A or >15A. Critical levels follow WARNING,
# so it could be "--current=5,15,1,19". If you want to specify some but
# not other thresholds, then just don't specify value between ",," so
# for example if you want CRITICAL alert at above 19A and no other
# thresholds, it would be "--current=,,,15".
#
# In addition each RPC can have multiple breakers. I've dealt with the
# ones that have 4 breakers per RPC corresponding to outlets A1-12,
# A13-24, B1-12, B13-14. In order to get breakers data use "--breakers"
# as a parameter. Irregardless of actual outlets the breakers will only
# be numbered (1,2,3,4,etc) and when reported by plugin will be specified
# as B1, B2, etc. Normally individual breaker values are not checked
# against the thresholds (often enough people use RPC as redundant power
# source so one breaker would have all the load while the other one none).
# If you do want to check against thresholds then use "--breakers=check".
#
# For temperature as mentioned you can specify output format to be either
# Celsius, Fahrenheit or more "real" (physically for formulas, etc) Kelvin.
# You specify it with "-o" followed by C or F or K, for example for
# Fahrenheit: "-o F". The default for this plugin is Celsius.
#
# Two other important options need to be mentioned:
# '-s' or '--showvalues' causes plugin to report actual data values as part
#     of the output (otherwise it would just report 'Baytech PDU OK' which is
#     not much fun...). This is done is somewhat compact way, here is an example:
# ./check_snmp_baytech_pdu.pl -H <host> -C public -s -f --voltage --current --temperature --power --breakers -o F -n CAB1
# Baytech PDU OK - CAB1 RPS26DE[2.1] is 119.2V/16.2A/1919W/90.5F (B1 is 119.2V/4.2A/492W, B2 is 119.3V/3.9A/461W, B3 is 119.8V/3.9A/469W, B4 is 120V/4.2A/497W)
# '-f' or '--perfdata' causes all data to be reported back in performance variables
# You want this if you're going to post-proces the data for example to graph it
#
# Finally if you have any doubt as to what data is available I recommend
# trying to use this plugin in "debug" mode:
#        check_snmp_baytech_pud.pl -d -H <host> -C <community> ...
#
# ========================= SETUP EXAMPLES ==================================
#
# define command {
#        command_name check_baytech
#        command_line $USER1$/check_snmp_baytech_pdu.pl -f -s -H $HOSTADDRESS$ -o F --breakers --temperature --current --power --voltage -C $ARG1$ -n $ARG2$
# }
#
# define service{
#       use                             std-service
#       host_name                 	baytech
#       service_description             Baytech PDU Data - Cabinet4
#       check_command                   check_cisco_temperature!foo!CAB4
# }
#
# ==================== CHANGES/RELEASE, TODO  ===================================
#
# 0.1  - April 2008   : Code from check_snmp_temperature used as as base for this plugin.
#                       The plugin is quite unstable and does not yet work
#
# 0.2  - May 28, 2008 : First working release. Documentation above is written too.
#
# 0.25 - Dec 19, 2011 : Full support for SNMP v3, small do & bug fixes
#
# ========================== START OF PROGRAM CODE ============================

use strict;
use Getopt::Long;

# Nagios specific
use lib "/usr/lib/nagios/plugins";
our $TIMEOUT;
our %ERRORS;
eval 'use utils qw(%ERRORS $TIMEOUT)';
if ($@) {
 $TIMEOUT = 10;
 %ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
}

our $no_snmp=0;
eval 'use Net::SNMP';
if ($@) {
  $no_snmp=1;
}

my $oid_rpc_names=".1.3.6.1.4.1.4779.1.3.5.5.1.4";
my $oid_rpc_current=".1.3.6.1.4.1.4779.1.3.5.5.1.6";
my $oid_rpc_maxcurrent=".1.3.6.1.4.1.4779.1.3.5.5.1.7"; 	    # not used right now
my $oid_rpc_voltage=".1.3.6.1.4.1.4779.1.3.5.5.1.8";
my $oid_rpc_power=".1.3.6.1.4.1.4779.1.3.5.5.1.9";
my $oid_rpc_temperature=".1.3.6.1.4.1.4779.1.3.5.5.1.10";
my $oid_rpc_numbreakers=".1.3.6.1.4.1.4779.1.3.5.5.1.21";
my $oid_breakers_current=".1.3.6.1.4.1.4779.1.3.5.10.1.5";
my $oid_breakers_maxcurrent=".1.3.6.1.4.1.4779.1.3.5.10.1.6"; # not used right now
my $oid_breakers_voltage=".1.3.6.1.4.1.4779.1.3.5.10.1.7";
my $oid_breakers_power=".1.3.6.1.4.1.4779.1.3.5.10.1.8";
my $oid_breakers_va=".1.3.6.1.4.1.4779.1.3.5.10.1.9";	    # not used right now

my $Version='0.25';

my $o_host=     undef;          # hostname
my $o_help=     undef;          # help option
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # version info option
my $o_perf=     undef;          # Performance data option
my $o_show=	undef;		# Show values data option
my $o_timeout=  5;              # Default 5s Timeout

# Login and other options specific to SNMP
my $o_port =            161;    # SNMP port
my $o_community =       undef;  # community
my $o_version2  =       undef;  # use snmp v2c
my $o_login=            undef;  # Login for snmpv3
my $o_passwd=           undef;  # Pass for snmpv3
my $v3protocols=        undef;  # V3 protocol list.
my $o_authproto=        'md5';  # Auth protocol
my $o_privproto=        'des';  # Priv protocol
my $o_privpass=         undef;  # priv password

my $o_name=	undef;		# Name regex
my $o_checkbreakers=undef;	# Check breakers parameter
my $o_current=  undef;          # Current level option
my @o_currentL= ();             # array for above list
my $o_voltage=  undef;          # Voltage level option
my @o_voltageL= ();             # array for above list
my $o_power=	undef;		# Power level option
my @o_powerL=	();		# array for above list
my $o_temperature=undef;	# Temperature level option
my @o_temperatureL=();		# array for above list

my $o_ounit= 	'C';		# Output Temperature Measurement Units - can be 'C', 'F' or 'K'
my $o_iunit=	'10C';		# Incoming Temperature Measurement Units

sub print_version { print "$0: $Version\n" };

sub print_usage {
	print "Usage: $0 [-d] -H <host> (-C <snmp_community>) [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>) [-p <port>] [-P <port>] [-T <timeout>] [-n <RPS name>] [--breakers[=check]] [--voltage=<warnmin>,<warnmax>,<critmin>,<critmax>] [--current=<warnmin>,<warnmax>,<critmin>,<critmax>] [--power=<warnmin>,<warnmax>,<critmin>,<critmax>] [--temperature=<warnin>,<warnmax>,<critmin>,<critmax>] [-s] [-f] [-o <out_temp_unit: C|F|K>] [-V]\n";
}

# Return true if arg is a number
sub isnum {
	my $num = shift;
	if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 1 ;}
	return 0;
}

sub help {
	print "\nSNMP Baytech PDU Plugin for Nagios version ",$Version,"\n";
	print " by William Leibzon - william(at)leibzon.org\n\n";
	print_usage();
	print <<EOD;
-d, --debug
	print extra debugging information
-h, --help
	print this help message
-V, --version
        prints version number
-T, --timeout=INTEGER
        timeout for SNMP in seconds (Default: 5)
-H, --hostname=HOST
	name or IP address of host to check
-C, --community=COMMUNITY NAME
	community name for the SNMP agent (used with v1 or v2c protocols)
-2, --v2c
	use snmp v2c (can not be used with -l, -x)
-l, --login=LOGIN ; -x, --passwd=PASSWD
	Login and auth password for snmpv3 authentication
	If no priv password exists, implies AuthNoPriv
-X, --privpass=PASSWD
	Priv password for snmpv3 (AuthPriv protocol)
-L, --protocols=<authproto>,<privproto>
	<authproto> : Authentication protocol (md5|sha : default md5)
	<privproto> : Priv protocols (des|aes : default des)
-P, --port=PORT
	SNMP port (Default 161)
-n, --name=NAME_REGEX
	The name of the RPS to check. The name is configured on the Baytech itself,
	see manual on how to do it (the default is something like RPS26). What you
	specify here is used as regex however usually its either single name or
	if you just want all, then dont specify this and all will be checked.
-b, --breakers[=check]
	In addition to getting data for each PDU also find info about
	each individual breaker on that PDU (you usually want this!)
	If you specify --breakers=check then their values are also checked
	against thresholds (see below)
-c, --current=WARNING_MIN,WARNING_MAX,CRITICAL_MIN,CRITICAL_MAX
	Current levels for nagios to report WARNING or CRITICAL alert
	Current is specified in Amps.
-v, --voltage=WARNING_MIN,WARNING_MAX,CRITICAL_MIN,CRITICAL_MAX
	Voltage levels for nagios alerts. Specified in (unsurisingly) Volts.
-p, --power=WARNING_MIN,WARNING_MAX,CRITICAL_MIN,CRITICAL_MAX
	Power levels for nagios alerts. Specified in Watts
-t, --temperature=WARNING_MIN,WARNING_MAX,CRITICAL_MIN,CRITICAL_MAX
	Temperature. Specified in output units (see below)
-o  --out_temp_unit=C|F|K
        What temperature measurement units are used for output and warning/critical - 'C', 'F' or 'K' - default is 'C'
-s, --showvalues
	Show actual values (current, power, etc) in a result line of this plugin
	(otherwise will only print 'PDU OK')
-f, --perfdata
        Perfparse output (data received returned as performance variables)
EOD
}

# For verbose output - don't use it right now
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

# Get the alarm signal (just in case snmp timout screws up)
$SIG{'ALRM'} = sub {
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $ERRORS{"UNKNOWN"};
};

# converts temperature from input format unit into output format units
sub convert_temp {
    my ($temp, $in_unit, $out_unit) = @_;

    # that is not super great algorithm if both input and output are F
    my $in_mult = 1;
    my $ctemp = undef;
    $in_mult = $1 if $in_unit =~ /(\d+)\w/;
    $in_unit =~ s/\d+//;
    $ctemp = $temp / $in_mult if $in_unit eq 'C';
    $ctemp = ($temp / $in_mult - 32) / 1.8 if $in_unit eq 'F';
    $ctemp = $temp / $in_mult - 273.15 if $in_unit eq 'K';
    $ctemp = $temp / $in_mult if !defined($ctemp);
    return $ctemp if $out_unit eq "C";
    return $ctemp * 1.8 + 32 if $out_unit eq "F";
    return $ctemp + 273.15 if $out_unit eq "K";
    return $ctemp; # should not get here
}

# function that justs provides input to output
sub convert_divide {
    my ($in, $in_mult, $out_unit) = @_;
    return $in / $in_mult;
}

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'd'     => \$o_verb,            'verbose'       => \$o_verb,	'debug'	=> \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'P:i'   => \$o_port,            'port:i'        => \$o_port,
        'C:s'   => \$o_community,       'community:s'   => \$o_community,
         '2'    => \$o_version2,        'v2c'           => \$o_version2,
        'l:s'   => \$o_login,           'login:s'       => \$o_login,
        'x:s'   => \$o_passwd,          'passwd:s'      => \$o_passwd,
        'X:s'   => \$o_privpass,        'privpass:s'    => \$o_privpass,
        'L:s'   => \$v3protocols,       'protocols:s'   => \$v3protocols,
        'T:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
        'f'     => \$o_perf,            'perfparse'     => \$o_perf,
	's'	=> \$o_show,		'showvalues'	=> \$o_show,
	'n:s'	=> \$o_name,		'name:s'	=> \$o_name,
	'o:s'	=> \$o_ounit,		'out_temp_unit:s' => \$o_ounit,
	'b:s'	=> \$o_checkbreakers,	'breakers:s'    => \$o_checkbreakers,
	'v:s'	=> \$o_voltage,		'voltage:s'	=> \$o_voltage,
	'c:s'	=> \$o_current,		'current:s' 	=> \$o_current,
	'p:s'	=> \$o_power,		'power:s'	=> \$o_power,
	't:s'	=> \$o_temperature,	'temperature:s'	=> \$o_temperature,
    );
    if (defined($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}; }
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}; }

    if (! defined($o_host) ) # check host and filter
        { print "No host defined!\n";print_usage(); exit $ERRORS{"UNKNOWN"}; }
    if ($no_snmp)
       { print "Can't locate Net/SNMP.pm\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }

    # check snmp information
    if (!defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
        { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
    if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) )
        { print "Can't mix snmp v1,2c,3 protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    if (defined ($v3protocols)) {
        if (!defined($o_login)) { print "Put snmp V3 login info with protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
        my @v3proto=split(/,/,$v3protocols);
        if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {$o_authproto=$v3proto[0];  }       # Auth protocol
        if (defined ($v3proto[1])) {$o_privproto=$v3proto[1];   }       # Priv  protocol
        if ((defined ($v3proto[1])) && (!defined($o_privpass)))
          { print "Put snmp V3 priv login info with priv protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    }

    $o_ounit =~ tr/[a-z]/[A-Z]/;
    if ($o_ounit ne 'C' && $o_ounit ne 'F' && $o_ounit ne 'K')
	{ print "Invalid output measurement unit specified!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
    if (defined($o_checkbreakers) && $o_checkbreakers ne "" && $o_checkbreakers ne 'check')
	{ print "The only valid values are --breakers or --breakers=check\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
    if (defined($o_voltage)) {
	if ($o_voltage =~ /(\d*)\w*(,(\d*)\w*(,(\d*)\w*(,(\d*)\w*(,(\d+))?)?)?)?/ ) { @o_voltageL=($1,$3,$5,$7,$9); }
	else { print "Invalid format for --voltage alert levels\n"; print_usage(); exit $ERRORS{"UNKNWON"}; }
    }
    if (defined($o_current)) {
        if ($o_current =~ /(\d*)\w*(,(\d*)\w*(,(\d*)\w*(,(\d*)\w*(,(\d+))?)?)?)?/ ) { @o_currentL=($1,$3,$5,$7,$9); }
        else { print "Invalid format for --current alert levels\n"; print_usage(); exit $ERRORS{"UNKNWON"}; }
    }
    if (defined($o_power)) {
        if ($o_power =~ /(\d*)\w*(,(\d*)\w*(,(\d*)\w*(,(\d*)\w*(,(\d+))?)?)?)?/ ) { @o_powerL=($1,$3,$5,$7,$9); }
        else { print "Invalid format for --power alert levels\n"; print_usage(); exit $ERRORS{"UNKNWON"}; }
    }
    if (defined($o_temperature)) {
        if ($o_temperature =~ /(\d*)\w*(,(\d*)\w*(,(\d*)\w*(,(\d*)\w*(,(\d+))?)?)?)?/ ) { @o_temperatureL=($1,$3,$5,$7,$9); }
        else { print "Invalid format for --temperature alert levels\n"; print_usage(); exit $ERRORS{"UNKNWON"}; }
    }
}

sub create_snmp_session {
  my ($session,$error);

  if ( defined($o_login) && defined($o_passwd)) {
    # SNMPv3 login
    if (!defined ($o_privpass)) {
     verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
     ($session, $error) = Net::SNMP->session(
      -hostname         => $o_host,
      -version          => '3',
      -port             => $o_port,
      -username         => $o_login,
      -authpassword     => $o_passwd,
      -authprotocol     => $o_authproto,
      -timeout          => $o_timeout
     );
    } else {
     verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
     ($session, $error) = Net::SNMP->session(
      -hostname         => $o_host,
      -version          => '3',
      -username         => $o_login,
      -port             => $o_port,
      -authpassword     => $o_passwd,
      -authprotocol     => $o_authproto,
      -privpassword     => $o_privpass,
      -privprotocol     => $o_privproto,
      -timeout          => $o_timeout
     );
    }
  } else {
    if (defined ($o_version2)) {
    # SNMPv2c Login
      verb("SNMP v2c login");
      ($session, $error) = Net::SNMP->session(
       -hostname  => $o_host,
       -version   => 2,
       -community => $o_community,
       -port      => $o_port,
       -timeout   => $o_timeout
      );
    } else {
    # SNMPV1 login
      verb("SNMP v1 login");
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

  return $session;
}


sub perf_name {
  my ($iname,$vtype) = @_;
  $iname =~ s/'\/\(\)/_/g; #'
  $iname =~ s/\s/_/g;
  return $iname."_".$vtype;
}

sub prepare_dataresults {
    my ($dataresults,$varlist,$oid,$type,$is_hasbreakers,$oid_base,$levels_array) = @_;

    $dataresults->{$oid}{$type} = [ undef, $oid_base.$oid, undef ];
    $dataresults->{$oid}{$type}[0] = [] if $is_hasbreakers && defined($o_checkbreakers);
    push @{$dataresults->{$oid}{$type}}, @{$levels_array};
    push @{$varlist}, $dataresults->{$oid}{$type}[1];
    verb ("now set to retrieve $type oid ".$dataresults->{$oid}{$type}[1]);
}

sub set_dataresults_rpc {
    my ($dataresults,$snmpresult,$varlist,$attr,$type,$oid_base,$levels_array) = @_;

    my ($oid,$i);
    if (exists($dataresults->{$attr}{$type}) && defined($snmpresult->{$dataresults->{$attr}{$type}[1]})) {
        $dataresults->{$attr}{$type}[2] = $snmpresult->{$dataresults->{$attr}{$type}[1]};
        verb("RPC ".$dataresults->{$attr}{name}. " id ".$dataresults->{$attr}{id}." $type is ".$dataresults->{$attr}{$type}[2]);
        if (defined($oid_base) && exists($dataresults->{$attr}{breakers}) && $dataresults->{$attr}{breakers} > 0) {
            $dataresults->{$attr}{$type}[0] = [];
            for ($i=0;$i<($dataresults->{$attr}{breakers});$i++) {
                $oid = $oid_base.$attr.'.'.($i+1);
                $dataresults->{$attr}{$type}[0][$i] = [ undef, $oid, undef ]; # 1st undef totally ignored
                push @{$dataresults->{$attr}{$type}[0][$i]}, @{$levels_array} if defined($o_checkbreakers) && $o_checkbreakers eq 'check';
                push @{$varlist}, $oid;
                verb ("now set to retrieve $type breaker ".($i+1)." oid ".$oid);
             }
        }
    }
}

sub set_dataresults_breakers {
    my ($dataresults,$snmpresult,$varlist,$attr,$type) = @_;

    if (exists($dataresults->{$attr}{$type}) && exists($dataresults->{$attr}{breakers}) && $dataresults->{$attr}{breakers}>0) {
	for (my $i=0;$i<$dataresults->{$attr}{breakers};$i++) {
		$dataresults->{$attr}{$type}[0][$i][2] = $snmpresult->{$dataresults->{$attr}{$type}[0][$i][1]};
        	verb("RPC ".$dataresults->{$attr}{name}." breaker ".($i+1)." ".$type." is ".$dataresults->{$attr}{$type}[0][$i][2]);
        }
    }
}

sub check_dataresults_val {
    # $dt is reference to array [ undef/ignore, oid, value, WARNING_MIN, WARNING_MAX, CRITICAL_MIN, CRITICAL_MAX, DEFAULT_VALUE ]
    my ($dt,$name_full,$name_perf,$in_unit,$out_unit,$convert_func,$is_show,$is_perf,$statuscode,$statusinfo,$perfdata,$statusdata) = @_;

    my $result=undef;
    if (!defined($dt->[2]) && defined($dt->[7])) {
	verb ("No data found for $name_full. Using default value of ".$dt->[7]);
	$result = $dt->[7];
    }
    if (defined($dt->[2])) {
	if (!isnum($dt->[2])) {
		$$statuscode="CRITICAL";
		$$statusinfo .= " AND" if $$statusinfo;
		$$statusinfo .= " $name_full is " .$dt->[2] ." not a number!";
	}
	else {
	   $result = $convert_func->($dt->[2], $in_unit, $out_unit) if !defined($result);
	   if (defined($dt->[6]) && isnum($dt->[6]) && $result > $dt->[6]) {
		$$statuscode="CRITICAL";
		$$statusinfo .= " AND" if $$statusinfo;
		$$statusinfo .= " $name_full is " .$result . $out_unit ." > ". $dt->[6];
	   }
	   elsif (defined($dt->[5]) && isnum($dt->[5]) && $result < $dt->[5]) {
		$$statuscode="CRITICAL";
		$$statusinfo .= " AND" if $$statusinfo;
		$$statusinfo .= " $name_full is " . $result . $out_unit ." < ". $dt->[5];
	   }
	   elsif (defined($dt->[4]) && isnum($dt->[4]) && $result > $dt->[4]) {
		$$statuscode="WARNING" if $$statuscode ne "CRITICAL";
		$$statusinfo .= " AND" if $$statusinfo;
		$$statusinfo .= " $name_full is " . $result . $out_unit ." > ". $dt->[4];
	   }
	   elsif (defined($dt->[3]) && isnum($dt->[3]) && $result < $dt->[3]) {
		$$statuscode="WARNING" if $$statuscode ne "CRITICAL";
		$$statusinfo .= " AND" if $$statusinfo;
		$$statusinfo .= " $name_full is " . $result . $out_unit . " < ". $dt->[3];
	   }
	   if ($is_show) {
		$$statusdata .= "/" if $$statusdata;
        	$$statusdata .= $result . $out_unit;
	   }
	   if ($is_perf) {
		$$perfdata .= " " . $name_perf . "=" . $result;
	   }
	}
    }
    else {
	$$statuscode="CRITICAL";
	$$statusinfo.= " AND" if $$statusinfo;
	$$statusinfo.= " NO RESULTS for $name_full";
    }
}

sub check_dataresults_rpc {
    my ($dataresults,$attr,$type,$in_out,$out_unit,$convert_func,$statuscode,$statusinfo,$perfdata,$statusdata_array) = @_;

    if (exists($dataresults->{$attr}{$type})) {
	my $ph_name = $dataresults->{$attr}{name}.'['.$dataresults->{$attr}{id}.']';
	$statusdata_array->{$ph_name} = [] if !defined($statusdata_array->{$ph_name});
	$statusdata_array->{$ph_name}[0] = "" if !defined($statusdata_array->{$ph_name}[0]);
    	check_dataresults_val($dataresults->{$attr}{$type},
		$dataresults->{$attr}{name}.'['.$dataresults->{$attr}{id}.'] '.$type,
		perf_name($dataresults->{$attr}{name}.'.'.$dataresults->{$attr}{id},$type),
		$in_out,$out_unit,$convert_func, $dataresults->{$attr}{show}, $dataresults->{$attr}{perf},
		$statuscode,$statusinfo,$perfdata,\$statusdata_array->{$ph_name}[0]);
    }
    else {
	$$statuscode="CRITICAL";
	$$statusinfo.=" NO DATA for $attr $type";
    }
}

sub check_dataresults_breakers {
    my ($dataresults,$attr,$type,$in_unit,$out_unit,$convert_func,$statuscode,$statusinfo,$perfdata,$statusdata_array) = @_;

    if (exists($dataresults->{$attr}{$type})) {
    	if (exists($dataresults->{$attr}{breakers}) && $dataresults->{$attr}{breakers}>0) {
            for (my $i=0;$i<$dataresults->{$attr}{breakers};$i++) {
       		my $ph_name = $dataresults->{$attr}{name}.'['.$dataresults->{$attr}{id}.']';
        	$statusdata_array->{$ph_name} = [] if !defined($statusdata_array->{$ph_name});
		$statusdata_array->{$ph_name}[$i+1] = "" if !defined($statusdata_array->{$ph_name}[$i+1]);
		if (exists($dataresults->{$attr}{$type}[0][$i])) {
        	    check_dataresults_val($dataresults->{$attr}{$type}[0][$i],
                	$dataresults->{$attr}{name}.'['.$dataresults->{$attr}{id}.']/'.($i+1)." ".$type,
                	perf_name($dataresults->{$attr}{name}.'.'.$dataresults->{$attr}{id}.'/'.($i+1),$type),
                	$in_unit,$out_unit,$convert_func, $dataresults->{$attr}{show}, $dataresults->{$attr}{perf},
                	$statuscode,$statusinfo,$perfdata,\$statusdata_array->{$ph_name}[$i+1]);
		}
		else {
			$$statuscode="CRITICAL";
			$$statusinfo.=" NO DATA for $attr $type breaker ".($i+1);
		}
	    }
	}
    }
    else {
        $$statuscode="CRITICAL";
        $$statusinfo.=" NO DATA for $attr $type";
    }
}


########## MAIN #######

check_options();

# Check global timeout if something goes wrong
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT");
  alarm($TIMEOUT);
} else {
  verb("no timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

# SNMP connection, build list of attributes to be retrieve
my ($session,$result,$oid,$line,$attr);
$session=create_snmp_session();

my @varlist = ();
my $dataresults = {};
my $statuscode = "OK";
my $statusinfo = "";
my $statusdata = "";
my $statusdata_array = {};
my $perfdata = "";

# 1st SNMP request - retrieve RPC names table and build list of RPC oids to check
# - here would be if check for future cached list of names
    verb("Retrieving SNMP table $oid_rpc_names to find RPC ids to be retrieved");
    $result = $session->get_table( -baseoid => $oid_rpc_names );
    if (!defined($result)) {
        printf("ERROR: Problem retrieving OID %s table: %s.\n", $oid_rpc_names, $session->error);
        $session->close();
        exit $ERRORS{"UNKNOWN"};
    }
    foreach $oid (Net::SNMP::oid_lex_sort(keys %{$result})) {
        $line=$result->{$oid};
        verb("got $oid : $line");
	if (!defined($o_name) || $line =~ /$o_name/) {
		$line =~ s/\s*$//g;
		$oid =~ s/$oid_rpc_names//;
		$dataresults->{$oid} = { matched_name=>$o_name, name=>$line, id=>$oid };
		$dataresults->{$oid}{id} =~ s/\.//;
		$dataresults->{$oid}{show} = 1 if defined($o_show);
		$dataresults->{$oid}{perf} = 1 if defined($o_perf);
		if (defined($o_checkbreakers)) {
			$dataresults->{$oid}{breakers} = 0;
			push @varlist, $oid_rpc_numbreakers.$oid;
			verb ("now set to retrieve #breakers oid ".$oid_rpc_numbreakers.$oid);
		}
		if (defined($o_voltage)) {
			prepare_dataresults($dataresults,\@varlist,$oid,'voltage',1,$oid_rpc_voltage,\@o_voltageL);
		}
		if (defined($o_current)) {
			prepare_dataresults($dataresults,\@varlist,$oid,'current',1,$oid_rpc_current,\@o_currentL);
		}
                if (defined($o_power)) {
			prepare_dataresults($dataresults,\@varlist,$oid,'power',1,$oid_rpc_power,\@o_powerL);
		}
                if (defined($o_temperature)) {
			prepare_dataresults($dataresults,\@varlist,$oid,'temperature',0,$oid_rpc_temperature,\@o_temperatureL);
                }
	}
    }
# }  - below would be code for future caching

# 2nd SNMP request - Data for RPCs
verb("Getting SNMP data for oids " . join(",",@varlist));
$result = $session->get_request(
	-Varbindlist => \@varlist
);
if (!defined($result)) {
        printf("ERROR: Can not retrieve OID(s) %s: %s.\n", join(" ",@varlist), $session->error);
        $session->close();
        exit $ERRORS{"UNKNOWN"};
}
else {
	@varlist=();
	foreach $attr (keys %{$dataresults}) {
	    if (exists($dataresults->{$attr}{breakers}) && defined($$result{$oid_rpc_numbreakers.$attr})) {
		$dataresults->{$attr}{breakers} = $$result{$oid_rpc_numbreakers.$attr};
		verb("RPC ".$dataresults->{$attr}{name}. " id ".$dataresults->{$attr}{id}." has ".$dataresults->{$attr}{breakers}." breakers");
	    }
	    set_dataresults_rpc($dataresults,$result,\@varlist,$attr,'voltage',$oid_breakers_voltage,\@o_voltageL);
	    set_dataresults_rpc($dataresults,$result,\@varlist,$attr,'current',$oid_breakers_current,\@o_currentL);
	    set_dataresults_rpc($dataresults,$result,\@varlist,$attr,'power',$oid_breakers_power,\@o_powerL);
	    set_dataresults_rpc($dataresults,$result,\@varlist,$attr,'temperature',undef,\@o_temperatureL);
	}
}

# 3rd SNMP request - Data for Breakers
if (scalar(@varlist)>0) {
    verb("Getting SNMP data for oids" . join(",",@varlist));
    $result = $session->get_request(
        -Varbindlist => \@varlist
    );
    if (!defined($result)) {
        printf("ERROR: Can not retrieve OID(s) %s: %s.\n", join(" ",@varlist), $session->error);
        $session->close();
        exit $ERRORS{"UNKNOWN"};
    }
    else {
        foreach $attr (keys %{$dataresults}) {
            set_dataresults_breakers($dataresults,$result,\@varlist,$attr,'voltage');
            set_dataresults_breakers($dataresults,$result,\@varlist,$attr,'current');
            set_dataresults_breakers($dataresults,$result,\@varlist,$attr,'power');
        }
    }
}
$session->close;

# loop to check if warning & critical attributes are ok
foreach $attr (keys %{$dataresults}) {
    check_dataresults_rpc($dataresults,$attr,'voltage',10,'V',\&convert_divide,\$statuscode,\$statusinfo,\$perfdata,$statusdata_array);
    check_dataresults_rpc($dataresults,$attr,'current',10,'A',\&convert_divide,\$statuscode,\$statusinfo,\$perfdata,$statusdata_array);
    check_dataresults_rpc($dataresults,$attr,'power',1,'W',\&convert_divide, \$statuscode,\$statusinfo,\$perfdata,$statusdata_array);
    check_dataresults_rpc($dataresults,$attr,'temperature',$o_iunit,$o_ounit,\&convert_temp, \$statuscode,\$statusinfo,\$perfdata,$statusdata_array);
    check_dataresults_breakers($dataresults,$attr,'voltage',10,'V',\&convert_divide, \$statuscode,\$statusinfo,\$perfdata,$statusdata_array);
    check_dataresults_breakers($dataresults,$attr,'current',10,'A',\&convert_divide, \$statuscode,\$statusinfo,\$perfdata,$statusdata_array);
    check_dataresults_breakers($dataresults,$attr,'power',1,'W',\&convert_divide, \$statuscode,\$statusinfo,\$perfdata,$statusdata_array);
}

# Getting nice display of values for all RPCs & breakers is somewhat complex
if (defined($o_show) && scalar(keys %{$statusdata_array})>0) {
    my $rpc_name;
    foreach $rpc_name (keys %{$statusdata_array}) {
	$statusdata .= ', ' if $statusdata;
	$statusdata .= $rpc_name ." is ". $statusdata_array->{$rpc_name}[0];
	if (scalar(@{$statusdata_array->{$rpc_name}})>1) {
	    $statusdata .= ' (';
	    for (my $i=1; $i<scalar(@{$statusdata_array->{$rpc_name}}); $i++) {
		$statusdata .= ', ' if $i>1;
		$statusdata .= "B".$i." is ";
		$statusdata .= $statusdata_array->{$rpc_name}[$i];
	    }
	    $statusdata .= ')';
	}
    }
}

print "Baytech PDU ". $statuscode . $statusinfo;
print " - ".$statusdata if $statusdata;
print " |".$perfdata if $perfdata;
print "\n";

exit $ERRORS{$statuscode};
