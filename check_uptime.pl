#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_uptime.pl
# Version : 0.521
# Date    : Oct 4, 2012
# Authors : William Leibzon - william@leibzon.org
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
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
#  This plugin returns uptime of the system returning data in text (readable)
#  format as well as in minutes for performance graphing. The plugin can either
#  run on local system unix system (that supports standard 'uptime' command
#  or check remote system by SNMP. The plugin can report one CRITICAL or
#  WARNING alert if system has been rebooted since last check.
#
# ======================  SETUP AND PLUGIN USE NOTES  =========================
#
#  The plugin can either retrieve information from local system (when you
#  run it through check_nrpe for example) or by SNMP from remote system.
#
#  On local system it will execute standard unix 'uptime' and 'uname -a'.
#
#  On a remote system it'll retrieve data from sysSystem for system type
#  and use that to decide if further data should be retrieved from
#    sysUptime (OID 1.3.6.1.2.1.1.3.0) for windows or
#    hostUptime (OID 1.3.6.1.2.1.25.1.1.0) for unix system or
#    snmpEngineTime (OID 1.3.6.1.6.3.10.2.1.3) for cisco switches
#
#  For information on available options please execute it with --help i.e:
#    check_uptime.pl --help
#
#  As I dont have time for extensive documentation below is all very brief:
#
#  1. You can also specify warning and critical thresholds which will
#     give warning or critical alert if system has been up for lees then
#     specified number of minutes. Example:
#        check_uptime.pl -w 5
#     Will give warning alert if system has been up for less then 5 minutes
#
#  2. For performance data results you can use '-f' option which will give
#     total number of minutes the system has been up.
#
#  3. A special case is use of performance to feed data from previous run
#     back into the plugin. This is used to cache results about what type
#     of system it is (you can also directly specify this with -T option)
#     and also means -w and -c threshold values are ignored and instead
#     plugin will issue ONE alert (warning or critical) if system uptime
#     changes from highier value to lower
#
# ============================ EXAMPLES =======================================
#
# 1. Local server (use with NRPE or on nagios host), warning on < 5 minutes:
#
# define command {
#        command_name check_uptime
#        command_line $USER1$/check_uptime.pl -f -w 5
# }
#
# 2. Local server (use with NRPE or on nagios host),
#    one critical alert on reboot:
#
# define command {
#        command_name check_uptime
#        command_line $USER1$/check_uptime.pl -f -c -P "SERVICEPERFDATA$"
# }
#
# 3. Remote server SNMP v2, one warning alert on reboot,
#    autodetect and cache type of server:
#
# define command {
#        command_name check_snmp_uptime_v2
#        command_line $USER1$/check_uptime.pl -2 -f -w -H $HOSTADDRESS$ -C $_HOSTSNMP_COMMUNITY$ -P "$SERVICEPERFDATA$"
# }
#
# 4. Remote server SNMP v3, rest as above
#
#define command {
#        command_name check_snmp_uptime_v3
#        command_line $USER1$/check_uptime.pl -f -w -H $HOSTADDRESS$ -l $_HOSTSNMP_V3_USER$ -x $_HOSTSNMP_V3_AUTH$ -X $_HOSTSNMP_V3_PRIV$ -L sha,aes -P "$SERVICEPERFDATA$"
# }
#
# 5. Example of service definition using above
#
# define service{
#      use				std-service
#      hostgroup_name			all_snmp_hosts
#      service_description		SNMP Uptime
#      max_check_attempts               1
#      check_command			check_snmp_uptime
# }
#
# 6. And this is optional dependency definition for above which makes
#    every SNMP service (service beloning to SNMP servicegroup) on
#    same host dependent on this SNMP Uptime check. Then if SNMP
#    daemon goes down you only receive one alert
#
# define servicedependency{
#        service_description SNMP Uptime
#        dependent_servicegroup_name snmp
# }
#
# ============================= VERSION HISTORY ==============================
#
# 0.1 - sometime 2006 : Simple script for tracking local system uptime
# 0.2 - sometime 2008 : Update to get uptime by SNMP, its now alike my other plugins
# 0.3 -  Nov 14, 2009 : Added getting system info line and using that to decide
#		        format of uptime line and how to process it. Added support
#			for getting uptime with SNMP from windows systems.
#			Added documentation header alike my other plugins.
#			Planned to release it to public, but forgot.
# 0.4  - Dec 19, 2011 : Update to support SNMP v3, released to public
# 0.41 - Jan 13, 2012 : Added bug fix by Rom_UA posted as comment on Nagios Exchange
#			Added version history you're reading right now.
# 0.42 - Feb 13, 2012 : Bug fix to not report WARNING if uptime is not correct output
# 0.5  - Feb 29, 2012 : Added support for "netswitch" engine type that retrieves
#		        snmpEngineTime. Added proper support for sysUpTime interpreting
#			it as 1/100s of a second and converting to days,hours,minutes
#			Changed internal processing structure, now reported uptime
#			info text is based on uptime_minutes and not separate.
# 0.51 - Jun 05, 2012 : Bug fixed for case when when snmp system info is < 3 words.
# 0.52 - Jun 19, 2012 : For switches if snmpEngineTime OID is not available,
#		        the plugin will revert back to checking hostUptime and
#			then sysUptime. Entire logic has in fact been changed
#			to support trying more than just two OIDs. Also added
#			support to specify filename to '-v' option for debug
#		        output to go to instead of console and for '--debug'
#			option as an alias to '--verbose'.
# 0.521 - Oct 4, 2012 : Small bug in one of regex, see issue #11 on github
#
# TODO:
#   0) Add '--extra-opts' to allow to read options from a file as specified
#      at http://nagiosplugins.org/extra-opts. This is TODO for all my plugins
#   1) Add support for ">", "<" and other threshold qualifiers
#      as done in check_snmp_temperature.pl or check_mysqld.pl
#   2) Support for more types, in particular network equipment such as cisco: [DONE]
#      	     sysUpTime is a 32-bit counter in 1/100 of a second, it rolls over after 496 days
#            snmpEngineTime (.1.3.6.1.6.3.10.2.1.3) returns the uptime in seconds and will not
#            roll over, however some cisco switches (29xx) are buggy and it gets reset too.
#            Routers running 12.0(3)T or higher can use the snmpEngineTime object from
#            the SNMP-FRAMEWORK-MIB.  This keeps track of seconds since SNMP engine started.
#   3) Add threshold into perfout as ';warn;crit'
#
# ========================== START OF PROGRAM CODE ===========================

use strict;
use Getopt::Long;

# Nagios specific
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

# Version
my $Version='0.52';

# SNMP OID
my $oid_sysSystem = '1.3.6.1.2.1.1.1.0';	     # windows and some unix
my $oid_hostUptime = '1.3.6.1.2.1.25.1.1.0';         # hostUptime, usually unix systems
my $oid_sysUptime = '1.3.6.1.2.1.1.3.0';             # sysUpTime, windows
my $oid_engineTime = '1.3.6.1.6.3.10.2.1.3';         # SNMP-FRAMEWORK-MIB

my @oid_uptime_types = ( ['', '', ''],		      	      # type 0 is reserved
	   [ 'local', '', ''],                                # type 1 is local
           [ 'win', 'sysUpTime', $oid_sysUptime ], 	      # type 2 is windows
	   [ 'unix-host', 'hostUpTime', $oid_hostUptime ],    # type 3 is unix-host
	   [ 'unix-sys', 'sysUpTime', $oid_sysUptime ],       # type 4 is unix-sys
	   [ 'net', 'engineTime', $oid_engineTime ]);         # type 5 is netswitch

# Not used, but perhaps later
my $oid_hrLoad = '1.3.6.1.2.1.25.3.3.1.2.1';
my $oid_sysLoadInt1 = '1.3.6.1.4.1.2021.10.1.5.1';
my $oid_sysLoadInt5 = '1.3.6.1.4.1.2021.10.1.5.2';
my $oid_sysLoadInt15 = '1.3.6.1.4.1.2021.10.1.5.3';

# Standard options
my $o_host = 		undef; 	# hostname
my $o_timeout=  	undef;  # Timeout (Default 10)
my $o_help=		undef; 	# wan't some help ?
my $o_verb=		undef;	# verbose mode
my $o_version=		undef;	# print version
my $o_label=		undef;	# change label instead of printing uptime
my $o_perf=             undef;  # Output performance data (uptime in minutes)
my $o_prevperf=		undef;	# performance data given with $SERVICEPERFDATA$ macro
my $o_warn=             undef;  # WARNING alert if system has been up for < specified number of minutes
my $o_crit=             undef;  # CRITICAL alert if system has been up for < specified number of minutes
my $o_type=             undef;  # type of check (local, auto, unix, win)

# Login and other options specific to SNMP
my $o_port =		161;    # SNMP port
my $o_community =	undef; 	# community
my $o_version2	=	undef;	# use snmp v2c
my $o_login=		undef;	# Login for snmpv3
my $o_passwd=		undef;	# Pass for snmpv3
my $v3protocols=	undef;	# V3 protocol list.
my $o_authproto=	'md5';	# Auth protocol
my $o_privproto=	'des';	# Priv protocol
my $o_privpass= 	undef;	# priv password

## Additional global variables
my %prev_perf=	();     # array that is populated with previous performance data
my $check_type = 0;

sub p_version { print "check_uptime version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v [debugfilename]] [-T local|unix-host|unix-sys|win|net] [-H <host> (-C <snmp_community>) [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>) [-p <port>]] [-w <warn minutes> -s <crit minutes>] [-f] [-P <previous perf data from nagios \$SERVICEPERFDATA\$>] [-t <timeout>] | [-V] [--label <string>]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub div_mod { return int( $_[0]/$_[1]) , ($_[0] % $_[1]); }

sub help {
   print "\nUptime Plugin for Nagios (check_uptime) v. ",$Version,"\n";
   print "GPL licence, (c) 2008-2012 William Leibzon\n\n";
   print_usage();
   print <<EOT;

Debug & Console Options:
 -v, --verbose[=FILENAME], --debug[=FILENAME]
   print extra debugging information.
   if filename is specified instead of STDOUT the debug data is written to that file
 -h, --help
   print this help message
 -V, --version
   prints version number

Standard Options:
 -T, --type=auto|local|unix-host|unis-sys|windows|netswitch
   Type of system:
     local           : localhost (executes 'uptime' command), default if no -C or -l
     unix-host       : SNMP check from hostUptime ($oid_hostUptime) OID
     unix-sys        : SNMP check from sysUptime ($oid_sysUptime) OID
     win | windows   : SNMP check from sysUptime ($oid_sysUptime) OID
     net | netswitch : SNMP check from snmpEngineTime ($oid_engineTime) OID
     auto            : Autodetect what system by checking sysSystem OID first, default
 -w, --warning[=minutes]
   Report nagios WARNING alert if system has been up for less then specified
   number of minutes. If no minutes are specified but previous preformance
   data is fed back with -P option then alert is sent ONLY ONCE when
   uptime changes from greater value to smaller
 -c, --critical[=minutes]
   Report nagios CRITICAL alert if system has been up for less then
   specified number of minutes or ONE ALERT if -P option is used and
   system's previous uptime is larger then current on
 -f, --perfparse
   Perfparse compatible output
 -P, --prev_perfdata
   Previous performance data (normally put '-P \$SERVICEPERFDATA\$' in
   nagios command definition). This is recommended if you dont specify
   type of system with -T so that previously checked type of system info
   is reused. This is also used to decide on warning/critical condition
   if number of seconds is not specified with -w or -c.
 --label=[string]
   Optional custom label before results prefixed to results
 -t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: 15)

SNMP Access Options:
 -H, --hostname=HOST
   name or IP address of host to check (if not localhost)
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
 -p, --port=PORT
   SNMP port (Default 161)
EOT
}

# For verbose output (updated 06/06/12 to write to debug file if specified)
sub verb {
    my $t=shift;
    if (defined($o_verb)) {
        if ($o_verb eq "") {
                print $t,"\n";
        }
        else {
            if (!open(DEBUGFILE, ">>$o_verb")) {
                print $t, "\n";
            }
            else {
                print DEBUGFILE $t,"\n";
                close DEBUGFILE;
            }
        }
    }
}

# load previous performance data
sub process_perf {
 my %pdh;
 my ($nm,$dt);
 foreach (split(' ',$_[0])) {
   if (/(.*)=(.*)/) {
        ($nm,$dt)=($1,$2);
        verb("prev_perf: $nm = $dt");
	# in some of my plugins time_ is to profile how long execution takes for some part of plugin
        # $pdh{$nm}=$dt if $nm !~ /^time_/;
	$pdh{$nm}=$dt;
   }
 }
 return %pdh;
}

sub type_from_name {
  my $type=shift;
  for(my $i=1; $i<scalar(@oid_uptime_types); $i++) {
      if ($oid_uptime_types[$i][0] eq $type) {
          return $i;
      }
   }
   return -1;
}


sub check_options {
    Getopt::Long::Configure ("bundling");
	GetOptions(
   	'v:s'	=> \$o_verb,		'verbose:s'	=> \$o_verb,  "debug:s" => \$o_verb,
        'h'     => \$o_help,    	'help'        	=> \$o_help,
        'H:s'   => \$o_host,		'hostname:s'	=> \$o_host,
        'p:i'   => \$o_port,   		'port:i'	=> \$o_port,
        'C:s'   => \$o_community,	'community:s'	=> \$o_community,
	 '2'	=> \$o_version2,	'v2c'		=> \$o_version2,
	'l:s'	=> \$o_login,		'login:s'	=> \$o_login,
	'x:s'	=> \$o_passwd,		'passwd:s'	=> \$o_passwd,
	'X:s'	=> \$o_privpass,	'privpass:s'	=> \$o_privpass,
	'L:s'	=> \$v3protocols,	'protocols:s'	=> \$v3protocols,
        't:i'   => \$o_timeout,    	'timeout:i'	=> \$o_timeout,
	'V'	=> \$o_version,		'version'	=> \$o_version,
        'f'     => \$o_perf,            'perfparse'     => \$o_perf,
        'w:i'   => \$o_warn,       	'warning:i'   	=> \$o_warn,
        'c:i'   => \$o_crit,      	'critical:i'   	=> \$o_crit,
	'label:s'   => \$o_label,
	'P:s'	=> \$o_prevperf,	'prev_perfdata:s' => \$o_prevperf,
	'T:s'   => \$o_type,            'type:s'        => \$o_type,
    );
    if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};

    $o_type = "win" if defined($o_type) && $o_type eq 'windows';
    $o_type = "net" if defined($o_type) && $o_type eq 'netswitch';
    if (defined($o_type) && $o_type ne 'auto' && type_from_name($o_type)==-1) {
	print "Invalid system type specified\n"; print_usage(); exit $ERRORS{"UNNKNOWN"};
    }

    if (!defined($o_community) && (!defined($o_login) || !defined($o_passwd)) ) {
	 $o_type='local' if !defined($o_type) || $o_type eq 'auto';
	 if ($o_type ne 'local') {
            print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}
         }
	 if (defined($o_host)) {
	    print "Why are you specifying hostname without SNMP parameters?\n"; print_usage(); exit $ERRORS{"UNKNOWN"};
	 }
    }
    else {
         $o_type='auto' if !defined($o_type);
         if ($o_type eq 'local' ) {
	     print "Why are you specifying SNMP login for local system???\n"; print_usage(); exit $ERRORS{"UNKNOWN"}
         }
         if (!defined($o_host)) {
             print "Hostname required for SNMP check.\n"; print_usage(); exit $ERRORS{"UNKNOWN"};
         }
	 if ($no_snmp) {
	     print "Can't locate Net/SNMP.pm\n"; print_usage(); exit $ERRORS{"UNKNOWN"};
	 }
    }

    # check snmp information
    if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) )
	{ print "Can't mix snmp v1,2c,3 protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    if (defined ($v3protocols)) {
	if (!defined($o_login)) { print "Put snmp V3 login info with protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	my @v3proto=split(/,/,$v3protocols);
	if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {$o_authproto=$v3proto[0];  }	# Auth protocol
	if (defined ($v3proto[1])) {$o_privproto=$v3proto[1];	}	# Priv  protocol
	if ((defined ($v3proto[1])) && (!defined($o_privpass)))
	  { print "Put snmp V3 priv login info with priv protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    }

    if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60)))
	{ print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    if (!defined($o_timeout)) {$o_timeout=$TIMEOUT+5;}

    if (defined($o_prevperf)) {
        if (defined($o_perf)) {
               %prev_perf=process_perf($o_prevperf);
	       $check_type = $prev_perf{type} if $o_type eq 'auto' && exists($prev_perf{tye}) && exists($oid_uptime_types[$prev_perf{type}][0]);
	}
        else {
               print "need -f option first \n"; print_usage(); exit $ERRORS{"UNKNOWN"};
        }
    }

    if ($o_type eq 'auto') {
        $check_type=0;
    }
    else {
        $check_type = type_from_name($o_type);
    }
}

sub create_snmp_session {
  my ($session,$error);

  if ( defined($o_login) && defined($o_passwd)) {
    # SNMPv3 login
    if (!defined ($o_privpass)) {
     verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
     ($session, $error) = Net::SNMP->session(
      -hostname   	=> $o_host,
      -version		=> '3',
      -port      	=> $o_port,
      -username		=> $o_login,
      -authpassword	=> $o_passwd,
      -authprotocol	=> $o_authproto,
      -timeout          => $o_timeout
     );
    } else {
     verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
     ($session, $error) = Net::SNMP->session(
      -hostname   	=> $o_host,
      -version		=> '3',
      -username		=> $o_login,
      -port      	=> $o_port,
      -authpassword	=> $o_passwd,
      -authprotocol	=> $o_authproto,
      -privpassword	=> $o_privpass,
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

$SIG{'ALRM'} = sub {
 print "Alarm timeout\n";
 exit $ERRORS{"UNKNOWN"};
};

########## MAIN #######
my $system_info="";
my $uptime_info=undef;
my $uptime_minutes=undef;
my $perf_out="";
my $status=0;
my $uptime_output;
my ($days, $hrs, $mins);

check_options();

# Check gobal timeout if snmp screws up
if (defined($o_timeout)) {
  verb("Alarm at $o_timeout + 5");
  alarm($o_timeout+5);
}

if ($check_type==1) {  # local
  # Process unix uptime command output
  $uptime_output=`uptime`;
  verb("Local Uptime Result is: $uptime_output");
  if ($uptime_output =~ /(\d+)\s+days?,\s+(\d+)\:(\d+)/) {
     ($days, $hrs, $mins) = ($1, $2, $3);
  }
  elsif ($uptime_output =~ /up\s+(\d+)\shours?\s+(\d+)/) {
     ($days, $hrs, $mins) = (0, $1, $2);
  }
  elsif ($uptime_output =~ /up\s+(\d+)\:(\d+)/) {
     ($days, $hrs, $mins) = (0, $1, $2);
  }
  elsif ($uptime_output =~ /up\s+(\d+)\s+min/) {
     ($days, $hrs, $mins) = (0,0,$1);
  }
  elsif ($uptime_output =~ /up\s+(\d+)s+days?,s+(\d+)s+min/) {
     ($days, $hrs, $mins) = ($1,0,$2);
  }
  else {
     $uptime_info = "up ".$uptime_output;
  }
  if (defined($days) && defined($hrs) && defined($mins)) {
     $uptime_minutes = $days*24*60+$hrs*60+$mins;
  }
  my @temp=split(' ',`uname -a`);
  if (scalar(@temp)<3) {
        $system_info=`uname -a`;
  }
  else {
        $system_info=join(' ',$temp[0],$temp[1],$temp[2]);
  }
}
else {
  # SNMP connection
  my $session=create_snmp_session();
  my $result=undef;
  my $oid="";
  my $guessed_check_type=0;

  if ($check_type==0){
      $result = $session->get_request(-varbindlist=>[$oid_sysSystem]);
      if (!defined($result)) {
            printf("ERROR: Can not retrieve $oid_sysSystem table: %s.\n", $session->error);
            $session->close;
            exit $ERRORS{"UNKNOWN"};
      }
      verb("$o_host SysInfo Result from OID $oid_sysSystem: $result->{$oid_sysSystem}");
      if ($result->{$oid_sysSystem} =~ /Windows/) {
	  $guessed_check_type=2;
	  verb('Guessing Type: 2 = windows');
      }
      if ($result->{$oid_sysSystem} =~ /Cisco/) {
	  $guessed_check_type=5;
	  verb('Guessing Type: 5 = netswitch');
      }
      if ($guessed_check_type==0) {
	  $guessed_check_type=3; # will try hostUptime first
      }
      $oid=$oid_uptime_types[$guessed_check_type][2];
  }
  else {
      $oid=$oid_uptime_types[$check_type][2];
  }

  do {
      $result = $session->get_request(-varbindlist=>[$oid,$oid_sysSystem]);
      if (!defined($result)) {
          if ($check_type!=0) {
              printf("ERROR: Can not retrieve uptime OID table $oid: %s.\n", $session->error);
              $session->close;
              exit $ERRORS{"UNKNOWN"};
          }
          else {
              if ($session->error =~ /noSuchName/) {
		  if ($guessed_check_type==4) {
                      verb("Received noSuchName error for sysUpTime OID $oid. Giving up.");
                      $guessed_check_type=0;
		  }
	          if ($guessed_check_type==3) {
            	      verb("Received noSuchName error for hostUpTime OID $oid, will now try sysUpTime");
		      $guessed_check_type=4;
	          }
	          else {
		      verb("Received noSuchName error for OID $oid, will now try hostUpTime");
		      $guessed_check_type=3;
		  }
		  if ($guessed_check_type!=0) {
		      $oid=$oid_uptime_types[$guessed_check_type][2];
		  }
	      }
	      else {
		  printf("ERROR: Can not retrieve uptime OID table $oid: %s.\n", $session->error);
         	  $session->close;
         	  exit $ERRORS{"UNKNOWN"};
	      }
	  }
      }
      else {
          if ($check_type==0) {
	      $check_type=$guessed_check_type;
	  }
      }
  }
  while (!defined($result) && $guessed_check_type!=0);

  $session->close;
  if ($check_type==0 && $guessed_check_type==0) {
        printf("ERROR: Can not autodetermine proper uptime OID table. Giving up.\n");
        exit $ERRORS{"UNKNOWN"};
  }

  my ($days, $hrs, $mins);
  $uptime_output=$result->{$oid};
  verb("$o_host Uptime Result from OID $oid: $uptime_output");

  if ($uptime_output =~ /(\d+)\s+days?,\s+(\d+)\:(\d+)/) {
    ($days, $hrs, $mins) = ($1, $2, $3);
  }
  elsif ($uptime_output =~ /(\d+)\s+hours?,\s+(\d+)\:(\d+)/) {
    ($days, $hrs, $mins) = (0, $1, $2);
  }
  elsif ($uptime_output =~ /(\d+)\s+min/) {
    ($days, $hrs, $mins) = (0, 0, $1);
  }
  if (defined($days) && defined($hrs) && defined($mins)) {
    $uptime_minutes = $days*24*60+$hrs*60+$mins;
  }
  elsif ($uptime_output =~ /^(\d+)$/) {
    my $upnum = $1;
    if ($oid eq $oid_sysUptime) {
	$uptime_minutes = $upnum/100/60;
    }
    elsif ($oid eq $oid_engineTime) {
	$uptime_minutes = $upnum/60;
    }
  }
  else {
    $uptime_info = "up ".$uptime_output;
  }
  my @temp=split(' ',$result->{$oid_sysSystem});
  if (scalar(@temp)<3) {
	$system_info=$result->{$oid_sysSystem};
  }
  else {
	$system_info=join(' ',$temp[0],$temp[1],$temp[2]);
  }
}

if (defined($uptime_minutes) && !defined($uptime_info)) {
  ($hrs,$mins) = div_mod($uptime_minutes,60);
  ($days,$hrs) = div_mod($hrs,24);
  $uptime_info = "up ";
  $uptime_info .= "$days days " if $days>0;
  $uptime_info .= "$hrs hours " if $hrs>0;
  $uptime_info .= "$mins minutes";
}

verb("System Type: $check_type (".$oid_uptime_types[$check_type][0].")");
verb("System Info: $system_info") if $system_info;
verb("Uptime Text: $uptime_info") if defined($uptime_info);
verb("Uptime Minutes: $uptime_minutes") if defined($uptime_minutes);

if (!defined($uptime_info)) {
  $uptime_info = "Can not determine uptime";
  $status = 3;
}

if (defined($o_perf)) {
  $perf_out = "type=$check_type";
  $perf_out .= " uptime_minutes=$uptime_minutes" if defined($uptime_minutes);
}

if (defined($uptime_minutes)) {
  if (defined($o_prevperf)) {
   	$status = 1 if defined($o_warn) && exists($prev_perf{uptime_minutes}) && $prev_perf{uptime_minutes} > $uptime_minutes;
   	$status = 2 if defined($o_crit) && exists($prev_perf{uptime_minutes}) && $prev_perf{uptime_minutes} > $uptime_minutes;
  }
  else {
   	$status = 1 if defined($o_warn) && !isnnum($o_warn) && $o_warn >= $uptime_minutes;
   	$status = 2 if defined($o_crit) && !isnnum($o_crit) && $o_crit >= $uptime_minutes;
  }
}
alarm(0);

my $exit_status="UNKNOWN";
$exit_status="OK" if $status==0;
$exit_status="WARNING" if $status==1;
$exit_status="CRITICAL" if $status==2;
$exit_status="UNKNOWN" if $status==3;
$exit_status="$o_label $exit_status" if defined($o_label);
print "$exit_status: $system_info";
print " - $uptime_info";
print " | ",$perf_out if $perf_out;
print "\n";
exit $status;
