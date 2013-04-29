#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_linux_procstat.pl
# Version : 0.41
# Date    : Mar 25, 2012
# Author  : William Leibzon - william@leibzon.org
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
# This plugin parses data from /proc/stat on linux system and outputs CPU utilization
# and load data as well as several linux system schedule parameters
#
# It can be used either directly on the same machine, with check_nrpe or with SNMP,
# either directly or with check_by_snmp, see examples for more information
#
# The plugin outputs lots of useful performance data for graphing and pnp4nagios
# and nagiosgrapher templates are provided for your convinience or NagiosExchange
#
# ============================= SETUP NOTES ====================================
#
# To find all available options I recommend you do
#   ./check_linux_procstat.pl -help
#
# Usage: ./check_linux_procstat.pl [-v] [[-P <filename> | -] | [-O oid -H <host> (-C <snmp_community>) [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>) [-p <port>]]] [-w <warn cpu%> -c <crit cpu%>] [-f] [-t <timeout>] [-V] [-N <number of real cpus> [-n <number of cpu cores>]]
#
# In above options (none of which is actually required) mean:
#  -w and -c allow to specify cpu threshold above which warning or critical alert is issued
#  -N option allows to specify number of real CPUs, this is only used to make nice output
#  -n option allows to specify number of virtual cpus (as reported in /proc/stat),
#     this is used and if the number you specify here is different then what plugin
#     reports, CRITICAL alert will be issued. You can use to make sure you booted into
#     proper SMP kernel.
#  -P is used to specify file to read instead of /proc/stat. If you specify - instead
#     of file name, then data is read from standard input
#  -O, -H, -C, -l, -L, -x, -X are used to retrieve data by SNMP. This will be discontinued
#     in a future version in favor of using check_by_snmp with "-P -" option of this plugin
#  -f is used to active performance output
#
# Data for each CPU core provided in performance output includes amount of time
# each CPU spends in user, system, irq, iowait, idle time. Also provided is data
# on how many interrupts have been recorded, how many context switches, and
# number of processes being forked, and currently blocked and running processes.
#
# On some systems number of swap & memory pages in/out and disk io in/out paged data
# is also provided (mostly 2.4 kernel or similar kernel that had this info /proc/stat)
#
# ========================= SETUP EXAMPLES ==================================
#
# Here are examples of how to run plugin this plugin:
#
# 1) Configuration to run directly on the server
#
# define command {
#        command_name check_linux_cpustat
#        command_line $USER1$/check_linux_procstat.pl -f -w $ARG1$ -c $ARG2$
# }
#
# define service{
#       use                             prod-service
#       hostgroup_name                  linux
#       service_description             Linux CPU Load and System Scheduler
#       check_command                   check_linux_cpustat!75!95
#       notification_options            c,r
# }
#
# 2) Configuration to retrieve data from remote server that has this line
#    ---
#    exec .1.3.6.1.4.1.2021.201 cpustat /bin/cat /proc/stat
#    ----
#    in /etc/snmp/snmpd.conf (exact OID is your choice, but don't forget to adjust -O)
#
# define command {
#        command_name check_snmp_linuxcpustat
#        command_line $USER1$/check_linux_procstat.pl -O 1.3.6.1.4.1.2021.201 -H $HOSTADDRESS$ -L sha,aes -l $_HOSTSNMP_V3_USER$ -x $_HOSTSNMP_V3_AUTH$ -X $_HOSTSNMP_V3_PRIV$ -f -w $ARG1$ -c $ARG2$
# }
#
# Note that support for directly retrieving data through SNMP will be discontinued
# in the next version of this plugin, since this functionality can be achieved with
# check_by_snmp and by using -P switch which tells plugin which file to read
# instead of /proc/stat. Example of this is below:
#
# 3) Configuration to retieve data from remote server with help of check_by_snmp
#
# define command {
#        command_name check_snmp_linuxcpustat
#        command_line $USER1$/check_by_snmp -O 1.3.6.1.4.1.2021.201 -H $HOSTADDRESS$ -L sha,aes -l $_HOSTSNMP_V3_USER$ -x $_HOSTSNMP_V3_AUTH$ -X $_HOSTSNMP_V3_PRIV$ --exec $USER1$/check_linux_procstat.pl -f -w $ARG1$ -c $ARG2$ -P -
# }
#
# check_by_snmp can be obtained from my site at http://william.leibzon.org/nagios/
# or from Nagios Exchange and has been written in part based on check_linux_procstat
# in order to allow using this mechanism with other plugins.
#
# ---------------------------------------------------------------------#
# Here is example from manual run for reference:
#
# ./check_linux_procstat.pl
# OK - 4 CPU cores - CPU(all) 12.0% used, CPU0 17.0% used, CPU1 14.0% used, CPU2 11.0% used, CPU3 8.0% used
#
# And here is an older example (from 2007 on linux 2.4 kernel) with performance data:
# ./check_linux_procstat.pl -f -N 2 -n 4
# OK - 2 real (4 virtual) CPUs - CPU(all) 47.0% used,
# CPU0 49.0% used, CPU1 46.0% used, CPU2 46.0% used, CPU3 45.0% used |
# cpu0_idle=1170345521 cpu0_iowait=1552433 cpu0_irq=6108869 cpu0_nice=2711 cpu0_softirq=24130393
# cpu0_system=675077539 cpu0_used=1149243863 cpu0_user=442374629 cpu1_idle=1232342280 cpu1_iowait=1619125
# cpu1_irq=30412 cpu1_nice=2637 cpu1_softirq=2418804 cpu1_system=648929911 cpu1_used=1087246640
# cpu1_user=434248388 cpu2_idle=1241109963 cpu2_iowait=1469834 cpu2_irq=1071704 cpu2_nice=3461
# cpu2_softirq=8201800 cpu2_system=570765618 cpu2_used=1078478058 cpu2_user=496969102 cpu3_idle=1264914936
# cpu3_iowait=1417638 cpu3_irq=311765 cpu3_nice=3026 cpu3_softirq=3813543 cpu3_system=566769207
# cpu3_used=1054673617 cpu3_user=482361464 cpu_idle=4908712700 cpu_iowait=6059030 cpu_irq=7522750
# cpu_nice=11835 cpu_softirq=38564540 cpu_system=2461542275 cpu_used=4369642178 cpu_user=1855953583
# csum_idle=4908712700 csum_iowait=6059030 csum_irq=7522750 csum_nice=11835 csum_softirq=38564540
# csum_system=2461542275 csum_used=4369642178 csum_user=1855953583 ctxt=1838196018 data_paged_in=56490811
# data_paged_out=1400905968 disk_8_0_blksread=112980514 disk_8_0_blkswritten=2801811916
# disk_8_0_noinfo=508301268 disk_8_0_readio=2367335 disk_8_0_writeio=505933933 num_intr=3814846467
# origcpu_idle=613745404 processes=388538614 procs_blocked=0 procs_running=5
# swap_paged_in=1026 swap_paged_out=9099
#
# =================================== TODO ===================================
#
#  1. Update plugin to for Linux 2.6 kernel where lots of interesting data is
#     also available in /proc/vmstat
#  2. Have output currently mostly reported performance data be considered
#     "attributes" and alow to specify warning and critical threshold values
#     for each of those attributes as well as for multiple related attributes
#     (example: send alert if your CPU is 95 "iowait" or 95% system)
#  3. Send previous data back into plugin to alow to specifying alert based on
#     rate of change (example: #of processes or # context switches per second)
#
#  Versions:
#    0.3  - Sept 2007    : first public release
#    0.35 - Dec 25, 2011 : update to support snmp v3 and bug fixes
#			   the plugin will now add 'c' to perf data to indicate counter
#			   changed wording from "virtual CPU" to "CPU Core"
#    0.4  - Jan 09, 2012 : Added -P option that allows to specify /proc/stat file
#			   or get results from stdin. Removed origcpu_ from performance
#			   info and set all num_proces and similar info as 0 by default
#			   even if not present (all this needed for consistant graphing)
#			   Updated above documentation.
#    0.41 - Mar 25, 2012 : Added -m option to specify SNMP message size
#			   Fixed bug when # of cpus are mis-counted if data in
#			   SNMP repeats (which is really a bug from SNMP extend)
#
# ========================== START OF PROGRAM CODE ===========================

use strict;
use Getopt::Long;

# For some reason I was not able to get basic Math::BigInt to work within embedded perl
# interpreter - it returns an error saying
# **ePN ... /plugins/check_snmp_lincpustat.pl: "Argument "613200)" isn't numeric in addition (+) at /usr/lib/perl5/5.8.0/Math/BigInt/Calc.pm line 278,"
# I don't have time to deeply debug why right now so I'm forcing use of FastCalc
#
use Math::BigInt lib => 'FastCalc,Calc';

# Nagios specific
our $TIMEOUT;
our %ERRORS;
use lib "/usr/lib/nagios/plugins";
eval 'use utils qw(%ERRORS $TIMEOUT)';
if ($@) {
 $TIMEOUT = 15;
 %ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
}

our $no_snmp=0;
eval 'use Net::SNMP';
if ($@) {
  $no_snmp=1;
}

my $procstatfile = "/proc/stat";
my $o_procstat = undef;		# option to specify /proc/stat filename

my $o_help=     undef;          # help option
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # version info option
my $o_warn=     undef;          # warning level option
my $o_crit=     undef;          # Critical level option
my $o_perf=     undef;          # Performance data option
my $o_timeout=  5;              # Default 5s Timeout

my $o_realcpus= undef;          # number of real cpus
my $o_virtcpus= undef;		# number of virtual cpus
my $o_hyper=    undef;          # is it hyperthreaded system (total number of cpus reported is then doubled)
my $o_datacheck= undef;		# report result of datacheck to make sure sum of individual cpu data values is same as total

# Login and other options specific to SNMP
my $oid_ProcStat = 	undef;	# OID to retrieve the data
my $o_port =            161;    # SNMP port
my $o_community =       undef;  # community
my $o_version2  =       undef;  # use snmp v2c
my $o_login=            undef;  # Login for snmpv3
my $o_passwd=           undef;  # Pass for snmpv3
my $v3protocols=        undef;  # V3 protocol list.
my $o_authproto=        'md5';  # Auth protocol
my $o_privproto=        'des';  # Priv protocol
my $o_privpass=         undef;  # priv password
my $o_host=     	undef;  # hostname
my $o_msgsize=		10000;  # snmp msg size

my $Version='0.41';

sub p_version { print "check_linux_procstat version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] [[-P <filename> | -] | [-O oid -H <host> (-C <snmp_community>) [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>) [-p <port>]] [-m msgsize]] [-w <warn cpu%> -c <crit cpu%>] [-f] [-t <timeout>] [-V] [-N <number of real cpus> [-n <number of cpu cores>]] \n";
}

sub isnum { # Return true if arg is a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 1 ;}
  return 0;
}

# returns big integer object from larger number in input string
sub bint {
  (my $i = shift) =~ /^(\d+\.?\d*)|(^\.\d+)/;
  $i = "$1" if $1;
  return Math::BigInt->new("$i");
}

sub help {
   print "\nLinux /proc/stat Monitor for Nagios version ",$Version,"\n";
   print "GPL licence, (c) 2008-2012 William Leibzon\n\n";
   print_usage();
   print <<EOT;

Debug & Console Options:
 -v, --verbose
   print extra debugging information
 -h, --help
   print this help message
 -V, --version
   prints version number

Standard Options:
 -w, --warning[=load%]
   Report nagios WARNING alert if any CPU core is this % loaded
 -c, --critical[=load%]
   Report nagios CRITICAL alert if any CPU core is this loaded
 -f, --perfparse
   Perfparse compatible output
 -N, --realcpus=<number>
   Number of real CPUs on your system (used only used for output formatting)
 -n, --virtcpus=<number>
   Number of CPU cores on your system (typical CPUs now have > 1 core)
   this is optional parameter, but if you specify it and the number is not
   what plugin sees then CRITICAL alert will be issued
 -d, --datacheck
   Double-check CPU total by aggregating data from each CPU.
   This is good to catch overflow (which did happen in 2.4 kernel and system up > 2 months)
 -P, --procstat <filename> | -
   By default /proc/stat is read. This allows to modify that and have this plugin read
   specified file or get data from stdin if instead of file name - is specified
   This can not be combined with SNMP options below.

SNMP Access Options (if none of these are specified, local system is checked):
 -O, oid=<oid>
   OID number where /proc/cpuinfo data has been dumped with snmp exec
   You do it by adding the following to /etc/snmp/snmpd.conf
     "exec .1.3.6.1.4.1.2021.201 cpustat /bin/cat /proc/stat"
   And specifying this as '-O 1.3.6.1.4.1.2021.201' when calling this plugin
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
 -m, --msgsize=numbytes
   Maximum SNMP message, default is 10000
EOT

}

# For verbose output during debugging - don't use it right now
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

# Get the alarm signal (just in case snmp timout screws up)
$SIG{'ALRM'} = sub {
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $ERRORS{"UNKNOWN"};
};

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
	'P:s'   => \$o_procstat,	'procstat:s'	=> \$o_procstat,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'p:i'   => \$o_port,            'port:i'        => \$o_port,
        'C:s'   => \$o_community,       'community:s'   => \$o_community,
         '2'    => \$o_version2,        'v2c'           => \$o_version2,
        'l:s'   => \$o_login,           'login:s'       => \$o_login,
        'x:s'   => \$o_passwd,          'passwd:s'      => \$o_passwd,
        'X:s'   => \$o_privpass,        'privpass:s'    => \$o_privpass,
        'L:s'   => \$v3protocols,       'protocols:s'   => \$v3protocols,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'm:i'   => \$o_msgsize,         'msgsize'       => \$o_msgsize,
        'V'     => \$o_version,         'version'       => \$o_version,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
        'f'     => \$o_perf,            'perfdata'      => \$o_perf,
	'N:i'	=> \$o_realcpus,	'realcpus:i'	=> \$o_realcpus,
	'n:i'   => \$o_virtcpus,	'virtcpus:i'    => \$o_virtcpus,
	'Y'	=> \$o_hyper,		'hyperthreading' => \$o_hyper,    # this is old way to 2x number of real CPUs to virtual
	'O:s'	=> \$oid_ProcStat,	'oid:s'		=> \$oid_ProcStat,
        'd'     => \$o_datacheck,       'datacheck'     => \$o_datacheck, # double checks cpu total by aggregating data from each cpu
    );									  # this is a way to catch & ignore cpu overflows
    if (defined($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};

    # When -O option is used the plugin attempts to read data from SNMP
    # where the data is made available through snmpexec `/bin/cat /proc/stat`
    if (defined($oid_ProcStat)) {
	if (defined($o_procstat)) {
	    print "Can not combined -P with SNMP options.\n"; print_usage(); exit $ERRORS{"UNKNOWN"};
	}
        if (! defined($o_host) ) # check host and filter
        {
	    print "SNMP OID specified but not host name!\n"; print_usage(); exit $ERRORS{"UNKNOWN"};
	}
        if ($no_snmp) {
            print "Can't locate Net/SNMP.pm\n"; print_usage(); exit $ERRORS{"UNKNOWN"};
        }

    	# check snmp information
   	if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) )
        {
	    print "Can't mix snmp v1,2c,3 protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"};
	}
    	if (defined ($v3protocols)) {
        	if (!defined($o_login)) { print "Put snmp V3 login info with protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
        	my @v3proto=split(/,/,$v3protocols);
        	if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) { $o_authproto=$v3proto[0];  }  # Auth protocol
        	if (defined ($v3proto[1])) {$o_privproto=$v3proto[1];   }  # Priv protocol
        	if ((defined ($v3proto[1])) && (!defined($o_privpass)))
          	{ print "Put snmp V3 priv login info with priv protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
        }
        if (!defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
          { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    }
    else {
       if (defined($o_host) || defined($o_community)) {
	  print "You specified hostname or community but not SNMP OID string\n";
	  print_usage();
	  exit $ERRORS{"UNKNOWN"};
       }
    }
    if (defined($o_procstat)) {
	$procstatfile = $o_procstat;
    }
    if (defined($o_warn) && !isnum($o_warn)) {
	print "Your specified warning threshold $o_warn is not a number\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"};
    }
    if (defined($o_crit) && !isnum($o_crit)) {
        print "Your specified critical threshold $o_crit is not a number\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }
    # I still have one old install using -Y
    if (defined($o_realcpus) && !defined($o_virtcpus) && defined($o_hyper)) {
	$o_virtcpus=2*$o_realcpus;
    }
}

sub snmp_session {
  # Connect to host
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
      # SNMPv2 Login
      ($session, $error) = Net::SNMP->session(
        -hostname  => $o_host,
            -version   => 2,
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
    printf("ERROR opening session: %s with host %s\n", $error, $o_host);
    exit $ERRORS{"UNKNOWN"};
  }

  $session->max_msg_size($o_msgsize);

  return $session;
}

########## MAIN #######

check_options();

# Check gobal timeout if plugin screws up
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT");
  alarm($TIMEOUT);
} else {
  verb("no timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

my @lines; # main array where each line is from '/bin/cat /proc/stat`
my $line;  # one line data during processing
my %stats; # hash containing processed data

my $returncode = "OK";
my $statusdata = "";
my $countcpus=0;
my $cpu_percentused;
my $cn;
my $cpuinfo="";

# Use SNMP to get the info if -O is used
if (defined($oid_ProcStat)) {
   my $session = snmp_session();
   my $result = $session->get_table( -baseoid => $oid_ProcStat );

   if (!defined($result)) {
	printf("ERROR: retrieving OID %s table: %s.\n", $oid_ProcStat, $session->error);
	$session->close();
    	exit $ERRORS{"UNKNOWN"};
   }
   foreach my $i (Net::SNMP::oid_lex_sort(keys %{$result})) {
	push @lines, $result->{$i};
   }
   $session->close();
}
else {
   if ($procstatfile ne '-') {
      open CAT, "/bin/cat $procstatfile |"
        or die "Can not execute /bin/cat /proc/stat - $!";
      push @lines, $_ while (<CAT>);
      close CAT;
   }
   else {
      push @lines, $_ while(<STDIN>);
   }
   for (my $i=0;$i<scalar(@lines);$i++) { chop $lines[$i]; };
}

# this forces numbers to be 0 by default even if not present, need it for my graphing system
($stats{"ctxt"},$stats{"boot_time"},$stats{"processes"},
 $stats{"procs_running"},$stats{"procs_blocked"},$stats{"num_intr"}) = (0,0,0,0,0,0);

foreach $line (@lines) {
        verb("Processing line: ".$line);
        if ( $line =~ /(cpu\d{0,2})\s*(\d+)\s*(\d+)\s*(\d+)\s*(\d+)\s*(\d+)\s*(\d+)\s*(\d+)/ ) {
                ($stats{"$1_user"},$stats{"$1_nice"},$stats{"$1_system"},$stats{"$1_idle"},
		  $stats{"$1_iowait"},$stats{"$1_irq"},$stats{"$1_softirq"}) = ($2,$3,$4,$5,$6,$7,$8);
		##without bigint## $stats{"$1_used"}=$stats{"$1_user"}+$stats{"$1_nice"}+$stats{"$1_system"}+$stats{"$1_iowait"}+$stats{"$1_irq"}+$stats{"$1_softirq"};
		my $bnum = bint($stats{"$1_user"})+bint($stats{"$1_system"})+bint($stats{"$1_iowait"})+bint($stats{"$1_irq"})+bint($stats{"$1_softirq"});
		if (exists($stats{"$1_used"})) {
		    $stats{"$1_used"}=$bnum;
		}
		else {
		    $stats{"$1_used"}=$bnum;
		    $cn=$1;
                    $countcpus++;
		    if ($cn =~ /cpu\d{1,2}/) {
			foreach my $cp ("used", "user", "nice", "system", "idle", "iowait", "irq", "softirq") {
				if (defined($stats{"csum_".$cp})) {
					$stats{"csum_".$cp} = $stats{"csum_".$cp}->badd($stats{$cn."_".$cp});
				} else {
					$stats{"csum_".$cp} = bint($stats{$cn."_".$cp});
				}
			}
		    }
		}
        }
	elsif ( $line =~ /(cpu\d{0,2})\s*(\d+)\s*(\d+)\s*(\d+)\s*(\d+)/ ) {
		($stats{"$1_user"},$stats{"$1_nice"},$stats{"$1_system"},$stats{"$1_idle"}) = ($2,$3,$4,$5);
		##without bigint## $stats{"$1_used"}=$stats{"$1_user"}+$stats{"$1_nice"}+$stats{"$1_system"};
		$stats{"$1_used"}=bint($stats{"$1_user"})+bint($stats{"$1_system"});
		$cn=$1;
		$countcpus++;
                if ($cn =~ /cpu\d{1,2}/) {
                        foreach my $cp ("used", "user", "nice", "system", "idle") {
                                if (defined($stats{"csum_".$cp})) {
                                        $stats{"csum_".$cp} = $stats{"csum_".$cp}->badd($stats{$cn."_".$cp});
                                } else {
                                        $stats{"csum_".$cp} = bint($stats{$cn."_".$cp});
                                }
                        }
                }
	}
	if ( $line =~ /page\s*(\d+)\s*(\d+)/ ) {
		($stats{"data_paged_in"},$stats{"data_paged_out"}) = ($1, $2);
	}
	if ( $line =~ /swap\s*(\d+)\s*(\d+)/ ) {
		($stats{"swap_paged_in"},$stats{"swap_paged_out"}) = ($1, $2);
	}
	if ( $line =~ /ctxt\s*(\d+)/ ) {
		$stats{"ctxt"} = $1;
	}
	if ( $line =~ /btime\s*(\d+)"/ ) {
		$stats{"boot_time"} = $1;
	}
	if ( $line =~ /processes\s*(\d+)/ ) {
		$stats{"processes"} = $1;
	}
	if ( $line =~ /procs_running\s*(\d+)/ ) {
		$stats{"procs_running"} = $1;
	}
	if ( $line =~ /procs_blocked\s*(\d+)/ ) {
		$stats{"procs_blocked"} = $1;
	}
	if ( $line =~ /intr\s*(\d+)/ ) {
		$stats{"num_intr"} = $1;
	}
	if ($line =~ /disk_io:/) {
		while ($line =~ s/\((\d+),(\d+)\):\((\d+),(\d+),(\d+),(\d+),(\d+)\)//) {
			($stats{"disk_$1_$2_noinfo"},
			 $stats{"disk_$1_$2_readio"},
			 $stats{"disk_$1_$2_blksread"},
			 $stats{"disk_$1_$2_writeio"},
			 $stats{"disk_$1_$2_blkswritten"}
			) = ($3,$4,$5,$6,$7);
		}
	}
}

# page and swap data is not present in many systems
$stats{"data_paged_out"} = 0 if defined($stats{"data_paged_in"});
$stats{"swap_paged_out"} = 0 if defined($stats{"swap_paged_in"});

# Display count of cpus
$countcpus-- if defined($stats{"cpu_user"}) && defined($stats{"cpu0_user"});
$cpuinfo="$countcpus CPU cores";
if (defined($o_realcpus)) {
  $cpuinfo.=" ($o_realcpus real CPUs)";
}
if ((defined($o_virtcpus) && $o_virtcpus!=$countcpus) || (!defined($o_virtcpus) && defined($o_realcpus) && $o_realcpus>$countcpus)) {
	$returncode = "CRITICAL";
	$statusdata.= "should be ";
	$statusdata.= "$o_virtcpus virtual" if defined($o_virtcpus);
	$statusdata.= " and " if defined($o_virtcpus) && defined($o_realcpus);
	$statusdata.= "$o_realcpus real" if defined($o_realcpus);
	$statusdata.= " CPUs!";
}

# I've noticed that in some cases cpu_idle counter overloads since its 32-bit on 2.4 kernel
# the below will at least catch those cases on SMP systems if it seems cpu_idle not the same
# as total calculated by adding all of cpu?_idle
foreach my $cp ("used", "user", "nice", "system", "idle", "iowait", "irq", "softirq") {
	if (defined($stats{"csum_".$cp})) {
	   # $stats{"origcpu_".$cp} = $stats{"cpu_".$cp};
	   if ($stats{"csum_".$cp}->bcmp($stats{"cpu_".$cp})!=0) {
		# $returncode = "WARNING";
		$statusdata .= ", " if $statusdata;
		$statusdata .= sprintf "cpu_%s (%s) != sum[cpu0_%s .. cpu%d_%s] (%s) so setting cpu_%s to %s (possible counter overflow)", $cp, $stats{"cpu_".$cp}, $cp, $countcpus-1, $cp, $stats{"csum_".$cp}, $cp, $stats{"csum_".$cp} if defined($o_datacheck);
		$stats{"cpu_".$cp} = $stats{"csum_".$cp};
	   }
	}
}

# Check warning & critical conditions
# TODO:  Allow to specify threshold numbers for system' or 'iowait'
for (my $i=-1;$i<$countcpus;$i++) {
	$cpu_percentused=undef;
	$cpu_percentused=$stats{"cpu".$i."_used"}*100/($stats{"cpu".$i."_used"}+$stats{"cpu".$i."_idle"}) if $i>=0 && defined($stats{"cpu".$i."_used"}) && defined($stats{"cpu".$i."_idle"});
	$cpu_percentused=$stats{"cpu_used"}*100/($stats{"cpu_used"}+$stats{"cpu_idle"}) if $i==-1 && defined($stats{"cpu_used"}) && defined($stats{"cpu_idle"});
	$statusdata .= ", " if $statusdata;
	if (defined($cpu_percentused)) {
	    if (defined($o_crit) && $cpu_percentused->bcmp($o_crit)>0) {
		$statusdata .= sprintf "CPU%s %2.1f%% used > %s%%", ($i>=0?"$i":"(all)"), $cpu_percentused, $o_crit;
		$returncode = "CRITICAL";
	    }
	    elsif (defined($o_warn) && $cpu_percentused->bcmp($o_warn)>0) {
		$statusdata .= sprintf "CPU%s %2.1f%% used > %s%%", ($i>=0?"$i":"(all)"), $cpu_percentused, $o_warn;
		$returncode = "WARNING" if $returncode eq "OK";
	    }
	    else {
		$statusdata .= sprintf "CPU%s %2.1f%% used", ($i>=0?"$i":"(all)"), $cpu_percentused;
	    }
	}
}
print "$returncode - $cpuinfo";
print " - $statusdata" if $statusdata;

if (defined($o_perf)) {
  print " |";
  foreach my $i (sort keys %stats) {
        print ' '.$i.'='.$stats{$i};
	print 'c' if $i ne 'procs_blocked' && $i ne 'procs_running';
  }
}

print "\n";

exit $ERRORS{$returncode};
