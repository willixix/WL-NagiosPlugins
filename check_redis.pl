#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_redis.pl
# Version : 0.42
# Date    : Apr 28, 2012
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
# This is Redis Server Check plugin. It can measure response time, check replication
# sync and get other informational data. The plugin is based on check_mysqld.pl
#
# This program is written and maintained by:
#   William Leibzon - william(at)leibzon.org
#
# ============================= SETUP NOTES ====================================
#
# Make sure to install Redis perl  library from CPAN first.
#
# For help on what parameters this plugin accepts you can just do
#  ./check_redis.pl --help
#
# Example of Nagios Config Definitions
#
# Sample command and service definitions are below:
#
# define command {
#    command_name    check_memcached
#    command_line    $USER1$/check_memcached.pl -H $HOSTADDRESS$ -p $ARG1$ -T $ARG2$ -R $ARG3$ -U $ARG4$ -a curr_connections,evictions -w ~,~ -c ~,~ -f -A 'utilization,hitrate,response_time,curr_connections,evictions,cmd_set,bytes_written,curr_items,uptime,rusage_system,get_hits,total_connections,get_misses,bytes,time,connection_structures,total_items,limit_maxbytes,rusage_user,cmd_get,bytes_read,threads,rusage_user_ms,rusage_system_ms,cas_hits,conn_yields,incr_misses,decr_misses,delete_misses,incr_hits,decr_hits,delete_hits,cas_badval,cas_misses,cmd_flush,listen_disabled_num,accepting_conns,pointer_size,pid' -P "$SERVICEPERFDATA$"
# }
#
# Arguments and thresholds are:
#  ARG1 : Port
#  ARG2 : Hitrate Threshold. Below it is <60% for warning, <30% for critical
#  ARG3 : Response Time Threshold. Below it is  >0.1s for WARNING, >0.2s for critical
#  ARG4 : Utilization/Size Threshold. Below it is >95% for warning, >98% for critical
#
# define service {
#       use                     prod-service
#       service_description     Memcached: Port 11212
#       check_command           check_memcached!11212!'>0.1,>0.2'!'<60,<30'!'>95,>98'
#       hostgroups              memcached
# }
#
# Example of command-line use:
#   /usr/lib/nagios/plugins/check_memcached.pl -H localhost -a 'curr_connections,evications' -w ~,~ -c ~,~ -s misc,malloc,sizes -U -A -R -T -f -v
#
# In above the -v option means "verbose" and with it plugin will output some debugging
# information about what it is doing. The option is not intended to be used when plugin
# is called from nagios itself. 
#
# ======================= VERSION HISTORY and TODO ================================
#
# The plugins is written by reusing code my check_memcached.pl which itself is based
# on check_mysqld.pl. check_mysqld.pl has history going back to 2004.
#
#  [0.4  - Mar 2012] First version of the code based on check_mysqld.pl 0.93
#		     and check_memcached.pl 0.6. Internal work, not released.
#		     Version 0.4 because its based on a well developed code base
#  [0.41 - Apr 15, 2012] Added list of variables array and perf_ok regex.
#			 Still testing internally and not released yet.
#  [0.42 - Apr 28, 2012] Added total_keys, total_expired, nice uptime_info 
#			 and memory utilization
#  [0.43 - May ??, 2012] Planned first release. Documentation to be added above
#			 replacing check_memcached examples
#
# TODO or consider for future:
#
#  0. Add '--extra-opts' to allow to read options from a file as specified
#     at http://nagiosplugins.org/extra-opts. This is TODO for all my plugins
#
#  1. In plans are to allow long options to specify thresholds for known variables.
#     These would mean you specify '--connected_clients' in similar way to '--hitrate'
#     Internally these would be convered into -A, -w, -c as appropriate an used
#     together with these options. So in practice it will now allow to get any data
#     just a different way to specify options for this plugin. 
# 
#  2. REDIS Specific:
#     - Add option to check from master that slave is connected and working.
#     - Look into replication delay from master and how it can be done.
#     - How to better calculate memory utilization and get max memory available
#     - Special options to measure cpu use and set threshold 
#
#  Other users can recommand a new feature to be added here too. If so please email me at
#         william@leibzon.org.
#  And don't worry, I'm not a company with sme hidden agenda to use your idea
#  but an actual person who you can easily get hold of by email, find on forums
#  and on Nagios conferences. More info on my nagios work is at:
#         http://william.leibzon.org/nagios/
#  Above site should have PNP4Nagios template for this and other plugins.
#
# ============================ START OF PROGRAM CODE =============================

use strict;
use IO::Socket;
use Time::HiRes;
use Redis;
use Getopt::Long qw(:config no_ignore_case);

# default hostname, port, database, user and password, see NOTES above
my $HOSTNAME= 'localhost';
my $PORT=     6379;

# Add path to additional libraries if necessary
use lib '/usr/lib/nagios/plugins';
our $TIMEOUT;
our %ERRORS;
eval 'use utils qw(%ERRORS $TIMEOUT)';
if ($@) {
 $TIMEOUT = 20;
 %ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
}

my $Version='0.42';

# This is a list of known stat and info variables including variables added by plugin,
# used in order to designate COUNTER variables with 'c' in perfout for graphing programs
my %KNOWN_STATUS_VARS = ( 
	 'memory_utilization' => [ 'GAUGE', '%' ],      # calculated by plugin
	 'redis_version' => [ 'VERSION', '' ],		# version string variable
	 'response_time' => [ 'GAUGE', 's' ],		# measured by plugin
	 'total_keys' => [ 'GAUGE', '' ],		# total number of keys from all dbs
	 'total_expires' => ['GAUGE', '' ],		# total expires summed for all dbs
	 'last_save_time' => [ 'GAUGE', 's' ],
	 'bgsave_in_progress' => [ 'BOOLEAN', '' ],
	 'vm_enabled' => [ 'BOOLEAN', '' ],
	 'uptime_in_seconds' => [ 'COUNTER', 'c' ],
	 'total_connections_received' => [ 'COUNTER', 'c' ],
	 'used_memory_rss' => [ 'GAUGE', 'B' ],		# RSS - Resident Set Size
	 'used_cpu_sys' => [ 'GAUGE', '' ],
	 'redis_git_dirty' => [ 'BOOLEAN', '' ],
	 'loading' => [ 'BOOLEAN', '' ],
	 'latest_fork_usec' => [ 'GAUGE', '' ],
	 'connected_clients' => [ 'GAUGE', '' ],
	 'used_memory_peak_human' => [ 'GAUGE', '' ],
	 'mem_allocator' => [ 'TEXTINFO', '' ],
	 'uptime_in_days' => [ 'COUNTER', 'c' ],
	 'keyspace_hits' => [ 'COUNTER', 'c' ],
	 'client_biggest_input_buf' => [ 'GAUGE', '' ],
	 'gcc_version' => [ 'TEXTINFO', '' ],
	 'changes_since_last_save' => [ 'COUNTER', 'c' ],
	 'arch_bits' => [ 'GAUGE', '' ],
	 'lru_clock' => [ 'GAUGE', '' ], # is it page? not sure. LRU is page replacement algorithm
	 'role' => [ 'SETTING', '' ],
	 'multiplexing_api' => [ 'SETTING' , '' ],
	 'slave' => [ 'TEXTDATA', '' ],
	 'pubsub_channels' => [ 'GAUGE', '' ],
	 'redis_git_sha1' => [ 'TEXTDATA', '' ],
	 'used_cpu_user_children' => [ 'COUNTER', 'c' ],
	 'process_id' => [ 'GAUGE', '' ],
	 'used_memory_human' => [ 'GAUGE', '' ],
	 'keyspace_misses' => [ 'COUNTER', 'c' ],
	 'used_cpu_user' => [ 'COUNTER', 'c' ],
	 'total_commands_processed' => [ 'COUNTER', '' ],
	 'mem_fragmentation_ratio' => [ 'GAUGE', '' ],
	 'client_longest_output_list' => [ 'GAUGE', '' ],
	 'blocked_clients' => [ 'GAUGE', '' ],
	 'aof_enabled' => [ 'BOOLEAN', '' ],
	 'evicted_keys' => [ 'COUNTER', 'c' ],
	 'bgrewriteaof_in_progress' => [ 'BOOLEAN', '' ],
	 'expired_keys' => [ 'COUNTER', 'c', ],
	 'used_memory_peak' => [ 'GAUGE', 'B' ],
	 'connected_slaves' => [ 'GAUGE', '' ],
	 'used_cpu_sys_children' => [ 'GAUGE', '' ],
	);

# Here you can also specify which variables should go into perf data, 
# For right now it is 'GAUGE', 'COUNTER', 'DATA', and 'BOOLEAN'
# you may want to remove BOOLEAN if you don't want too much data
my $PERF_OK_STATUS_REGEX = 'GAUGE|COUNTER|^DATA$|BOOLEAN';

# ============= MAIN PROGRAM CODE - DO NOT MODIFY BELOW THIS LINE ==============

my $o_host=     undef;		# hostname
my $o_port=     undef;		# port
my $o_help=     undef;          # help option
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # version info option
my $o_variables=undef;          # list of variables for warn and critical
my @o_varsL=    ();             # array from above list
my $o_perfvars= undef;          # list of variables to include in perfomance data
my @o_perfvarsL=();             # array from above list
my $o_warn=     undef;          # warning level option
my @o_warnL=    ();             # array of warn data processing threshold 
my $o_crit=     undef;          # Critical level option
my @o_critL=    ();             # array of critical data processing thresholds 
my $o_perf=     undef;          # Performance data option
my $o_timeout=  undef;          # Timeout to use - note that normally timeout is from nagios
my $o_timecheck=undef;          # threshold spec for connection time
my $o_memutilization=undef;     # threshold spec for memory utilization%
my $o_totalmemory=undef;	# total memory on a system
my $o_hitrate=  undef;          # threshold spec for hitrate%
my $o_repdelay=undef;           # replication delay time

# previous performance data and ratio calculation related options
my $o_prevperf= undef;		# performance data given with $SERVICEPERFDATA$ macro
my $o_prevtime= undef;		# previous time plugin was run $LASTSERVICECHECK$ macro
my $o_ratelabel=undef;		# prefix and suffix for creating rate variables
my $o_rsuffix='';	
my $o_rprefix="&Delta_";	# default prefix	

## Additional global variables
my $redis= undef;               # DB connection object
my %prev_perf=  ();		# array that is populated with previous performance data
my @prev_time=  ();     	# timestamps if more then one set of previois performance data
my $perfcheck_time=undef;	# time when data was last checked 
my %dataresults= ();		# this is where data is loaded into

sub p_version { print "check_redis.pl version : $Version\n"; }

sub print_usage {
   print "Usage: $0 [-v] -H <host> [-p <port>] [-a <statistics variables> -w <variables warning thresholds> -c <variables critical thresholds>] [-A <performance output variables>] [-L <ratevar-prefix>[,<ratevar-suffix>]] [-T [conntime_warn,conntime_crit]] [-R [hitrate_warn,hitrate_crit]] [-m [mem_utilization_warn,mem_utilization_crit] [-M <maxmemory>[B|K|M|G]]] [-D replication_delay_time_warn,replication_delay_time_crit]  [-f] [-T <timeout>] [-V] [-P <previous performance data in quoted string>]\n";
   print "For more details on options do: $0 --help\n";
}

sub help {
   print "\nRedis Check for Nagios version ",$Version,"\n";
   print " by William Leibzon - william(at)leibzon.org\n\n";
   print "This monitoring plugin lets you do threshold checks on replication and other info\n";
   print "data which are also returned as performance output for graphing.\n\n";
   print_usage();
   print <<EOT;
 -v, --verbose
   print extra debugging information
 -h, --help
   Print this detailed help screen
 -H, --hostname=ADDRESS
   Hostname or IP Address to check
 -p, --port=INTEGER
   port number (default: 3306)
 -t, --timeout=NUMBER
   Allows to set timeout for execution of this plugin. This overrides nagios default.
 -a, --variables=STRING[,STRING[,STRING...]]
   List of variables from info data to do threshold checks on.
   The default (if option is not used) is not to monitor any variable.
   The variable name should be prefixed with '&' to chec its rate of
   change over time rather than actual value.
 -w, --warn=STR[,STR[,STR[..]]]
   This option can only be used if '--variables' (or '-a') option above
   is used and number of values listed here must exactly match number
   of variables specified with '-a'. The values specify warning threshold
   for when Nagios should send WARNING alert. These values are usually
   numbers and can have the following prefix modifiers:
      > - warn if data is above this value (default for numeric values)
      < - warn if data is below this value (must be followed by number)
      = - warn if data is equal to this value (default for non-numeric values)
      ! - warn if data is not equal to this value
      ~ - do not check this data (must not be followed by number or ':')
      ^ - for numeric values this disables check that warning < critical
   Threshold values can also be specified as range in two forms:
      num1:num2  - warn if data is outside range i.e. if data<num1 or data>num2
      \@num1:num2 - warn if data is in range i.e. data>=num1 && data<=num2
 -c, --crit=STR[,STR[,STR[..]]]
   This option can only be used if '--variables' (or '-a') option above
   is used and number of values listed here must exactly match number of
   variables specified with '-a'. The values specify critical threshold
   for when Nagios should send CRITICAL alert. The format is exactly same
   as with -w option except no '^' prefix.
 -T, --response_time=[WARN,CRIT]
   If this is used as just -T the plugin will measure and output connection 
   response time in seconds. With -f this would also be provided on perf variables.
   You can also specify values for this parameter, these are interprted as
   WARNING and CRITICAL thresholds (separated by ','). 
 -R, --hitrate=[WARN,CRIT]
   Calculates Hitrate %: cache_miss/(cache_hits+cache_miss). If this is used
   as just -R then this info just goes to output line. With '-R -f' these
   go as performance data. You can also specify values for this parameter,
   these are interprted as WARNING and CRITICAL thresholds (separated by ','). 
   The format for WARN and CRIT is same as what you would use in -w and -c.
 -m, --memory_utilization=[WARN,CRIT]
   This calculates percent of total memory on system used by redis, which is
      utilization=redis_memory_rss/total_memory*100.
   Total_memory on server must be specified with -M since Redis does not report
   it and can use maximum memory unless you enabled virtual memory and set a limit
   (I plan to test this case and see if it gets reported then).
   If you specify -U by itself, the plugin will just output this info,
   with '-f' it will also include it in performance data. You can also specify
   parameter value which are interpreted as WARNING and CRITICAL thresholds.
 -M, --memory=NUM[B|K|M|G]
   Amount of memory on a system for memory utilization calculations above.
   If it does not end with K,M,G then its assumed to be B (bytes)
 -D, --replication_delay=WARN,CRIT
   Allows to set threshold on replication delay info. Only valid if this is a slave!
   The treshold is in seconds and fractions are accepted.
 -f, --perfparse
   This should only be used with '-a' and causes variable data not only as part of
   main status line but also as perfparse compatible output (for graphing, etc).
 -A, --perfvars=[STRING[,STRING[,STRING...]]]
   This allows to list variables which values will go only into perfparse
   output (and not for threshold checking). The option by itself (emply value)
   is same as a special value '*' and specify to output all variables.
 -P, --prev_perfdata
   Previous performance data (normally put '-P \$SERVICEPERFDATA\$' in nagios
   command definition). This is used to calculate rate of change for counter
   statistics variables and for proper calculation of hitrate.
 -L, --rate_label=[PREFIX_STRING[,SUFFIX_STRING]]
   Prefix or Suffix label used to create a new variable which has rate of change
   of another base variable. You can specify PREFIX or SUFFIX or both. Default
   if not specified is '&Delta_' prefix string.
 -V, --version
   Prints version number
EOT
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

# Return true if arg is a number
sub isnum {
  my $num = shift;
  if (defined($num) && $num =~ /^[-|+]?((\d+\.?\d*)|(^\.\d+))$/ ) { return 1 ;}
  return 0;
}

sub div_mod { return int( $_[0]/$_[1]) , ($_[0] % $_[1]); }

# load previous performance data 
sub process_perf {
 my %pdh;
 my ($nm,$dt);
 foreach (split(' ',$_[0])) {
   if (/(.*)=(.*)/) {
       ($nm,$dt)=($1,$2);
        verb("prev_perf: $nm = $dt");
        # in some of my plugins time_ is to profile execution time for part of plugin
        # $pdh{$nm}=$dt if $nm !~ /^time_/;
        $pdh{$nm}=$dt;
        $pdh{$nm}=$1 if $dt =~ /(\d+)[cs]/; # 'c' or 's' maybe added
	# support for more than one set of previously cached performance data
        # push @prev_time,$1 if $nm =~ /.*\.(\d+)/ && (!defined($prev_time[0]) || $prev_time[0] ne $1);
   }
 }
 return %pdh;
}

# this function is used when checking data against critical and warn values
sub check_threshold {
    my ($attrib, $data, $th_array) = @_;
    my $mod = $th_array->[0];
    my $lv1 = $th_array->[1];
    my $lv2 = $th_array->[2];

    # verb("debug check_threshold: $mod : ".(defined($lv1)?$lv1:'')." : ".(defined($lv2)?$lv2:''));
    return "" if !defined($lv1) || ($mod eq '' && $lv1 eq ''); 
    return " " . $attrib . " is " . $data . " = " . $lv1 if $mod eq '=' && $data eq $lv1;
    return " " . $attrib . " is " . $data . " != " . $lv1 if $mod eq '!' && $data ne $lv1;
    return " " . $attrib . " is " . $data . " > " . $lv1 if $mod eq '>' && $data>$lv1;
    return " " . $attrib . " is " . $data . " > " . $lv2 if $mod eq ':' && $data>$lv2;
    return " " . $attrib . " is " . $data . " >= " . $lv1 if $mod eq '>=' && $data>=$lv1;
    return " " . $attrib . " is " . $data . " < " . $lv1 if ($mod eq '<' || $mod eq ':') && $data<$lv1;
    return " " . $attrib . " is " . $data . " <= " . $lv1 if $mod eq '<=' && $data<=$lv1;
    return " " . $attrib . " is " . $data . " in range $lv1..$lv2" if $mod eq '@' && $data>=$lv1 && $data<=$lv2;
    return "";
}

# this function is called when parsing threshold options data
sub parse_threshold {
    my $thin = shift;

    # link to an array that holds processed threshold data
    # array: 1st is type of check, 2nd is threshold value or value1 in range, 3rd is value2 in range, 4th is option, 5th is nagios spec string representation for perf out
    my $th_array = [ '', undef, undef, '', '' ]; 
    my $th = $thin;
    my $at = '';

    $at = $1 if $th =~ s/^(\^?[@|>|<|=|!]?~?)//; # check mostly for my own threshold format
    $th_array->[3]='^' if $at =~ s/\^//; # deal with ^ option
    $at =~ s/~//; # ignore ~ if it was entered
    if ($th =~ /^\:([-|+]?\d+\.?\d*)/) { # :number format per nagios spec
	$th_array->[1]=$1;
	$th_array->[0]=($at !~ /@/)?'>':'<=';
	$th_array->[5]=($at != /@/)?('~:'.$th_array->[1]):($th_array->[1].':');
    }
    elsif ($th =~ /([-|+]?\d+\.?\d*)\:$/) { # number: format per nagios spec
        $th_array->[1]=$1;
	$th_array->[0]=($at !~ /@/)?'<':'>=';
	$th_array->[5]=($at != /@/)?'':'@';
	$th_array->[5].=$th_array->[1].':';
    }
    elsif ($th =~ /([-|+]?\d+\.?\d*)\:([-|+]?\d+\.?\d*)/) { # nagios range format
	$th_array->[1]=$1;
	$th_array->[2]=$2;
	if ($th_array->[1] > $th_array->[2]) {
                print "Incorrect format in '$thin' - in range specification first number must be smaller then 2nd\n";
                print_usage();
                exit $ERRORS{"UNKNOWN"};
	}
	$th_array->[0]=($at !~ /@/)?':':'@';
	$th_array->[5]=($at != /@/)?'':'@';
	$th_array->[5].=$th_array->[1].':'.$th_array->[2];
    }
    if (!defined($th_array->[1])) {			# my own format (<,>,=,!)
	$th_array->[0] = ($at eq '@')?'<=':$at;
	$th_array->[1] = $th;
	$th_array->[5] = '~:'.$th_array->[1] if ($th_array->[0] eq '>' || $th_array->[0] eq '>=');
	$th_array->[5] = $th_array->[1].':' if ($th_array->[0] eq '<' || $th_array->[0] eq '<=');
	$th_array->[5] = '@'.$th_array->[1].':'.$th_array->[1] if $th_array->[0] eq '=';
	$th_array->[5] = $th_array->[1].':'.$th_array->[1] if $th_array->[0] eq '!';
    }
    if ($th_array->[0] =~ /[>|<]/ && !isnum($th_array->[1])) {
	print "Numeric value required when '>' or '<' are used !\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }
    # verb("debug parse_threshold: $th_array->[0] and $th_array->[1]");
    $th_array->[0] = '=' if !$th_array->[0] && !isnum($th_array->[1]) && $th_array->[1] ne '';
    if (!$th_array->[0] && isnum($th_array->[1])) { # this is just the number by itself, becomes 0:number check per nagios guidelines
	$th_array->[2]=$th_array->[1];
	$th_array->[1]=0;
	$th_array->[0]=':';
        $th_array->[5]=$th_array->[2];
    }
    return $th_array;
}

# this function checks that for numeric data warn threshold is within range of critical
# where within range depends on actual threshold spec and normally just means less
sub threshold_specok {
    my ($warn_thar,$crit_thar) = @_;

    return 1 if defined($warn_thar) && defined($warn_thar->[1]) &&
		defined($crit_thar) && defined($crit_thar->[1]) &&
		isnum($warn_thar->[1]) && isnum($crit_thar->[1]) &&
                $warn_thar->[0] eq $crit_thar->[0] && 
                (!defined($warn_thar->[3]) || $warn_thar->[3] !~ /\^/) &&
		(!defined($crit_thar->[3]) || $crit_thar->[3] !~ /\^/) &&
              (($warn_thar->[1]>$crit_thar->[1] && ($warn_thar->[0] =~ />/ || $warn_thar->[0] eq '@')) ||
               ($warn_thar->[1]<$crit_thar->[1] && ($warn_thar->[0] =~ /</ || $warn_thar->[0] eq ':')) ||
               ($warn_thar->[0] eq ':' && $warn_thar->[2]>=$crit_thar->[2]) ||
               ($warn_thar->[0] eq '@' && $warn_thar->[2]<=$crit_thar->[2]));
    return 0;  # return with 0 means specs check out and are ok
}

sub dataresults_addvar {
   my ($dnam, $dval) = @_;
   if (exists($dataresults{$dnam})) {
   	$dataresults{$dnam}[0] = $dval;
   }
   else { 
	$dataresults{$dnam} = [$dval, 0, 0];
   }
   if (defined($o_perfvars) && $o_perfvars eq '*') {
        push @o_perfvarsL, $dnam;
   }
}


sub uptime_info {
  my $uptime_seconds = shift;
  my $upinfo = "";
  my ($secs,$mins,$hrs,$days) = (undef,undef,undef,undef);
  ($mins,$secs) = div_mod($uptime_seconds,60);
  ($hrs,$mins) = div_mod($mins,60);
  ($days,$hrs) = div_mod($hrs,24);
  $upinfo .= "$days days " if $days>0;
  $upinfo .= "$hrs hours " if $hrs>0;
  $upinfo .= "$mins minutes" if $mins>0 && ($days==0 || $hrs==0);
  $upinfo .= "$secs seconds" if $secs>0 && $days==0 && $hrs==0; 
  return $upinfo;
}

# parse command line options
sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'p:i'   => \$o_port,            'port:i'        => \$o_port,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
	'a:s'   => \$o_variables,       'variables:s'   => \$o_variables,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
	'f:s'   => \$o_perf,            'perfparse:s'   => \$o_perf,
	'A:s'   => \$o_perfvars,        'perfvars:s'    => \$o_perfvars,
        'T:s'   => \$o_timecheck,       'response_time:s' => \$o_timecheck,
        'R:s'   => \$o_hitrate,         'hitrate:s'     => \$o_hitrate,
        'D:s'   => \$o_repdelay,        'replication_delay:s' => \$o_repdelay,
        'P:s'   => \$o_prevperf,        'prev_perfdata:s' => \$o_prevperf,
        'E:s'   => \$o_prevtime,        'prev_checktime:s'=> \$o_prevtime,
	'L:s'	=> \$o_ratelabel,	'rate_label:s'	=> \$o_ratelabel,
        'm:s'   => \$o_memutilization,  'memory_utilization:s' => \$o_memutilization,
	'M:s'	=> \$o_totalmemory,	'total_memory:s' => \$o_totalmemory,
    );
    if (defined($o_help)) { help(); exit $ERRORS{"UNKNOWN"} };
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"} };
    if (!defined($o_host)) { print "Please specify hostname (-H)\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; } 

    # below code is common for number of my plugins, including check_snmp_?, netstat, etc
    # it is mostly compliant with nagios threshold specification (except use of '~')
    # and adds number of additional format options using '>','<','!','=' prefixes
    my (@ar_warnLv,@ar_critLv);
    @o_perfvarsL=split( /,/ , lc $o_perfvars ) if defined($o_perfvars) && $o_perfvars ne '*';
    $o_perfvars='*' if defined($o_perfvars) && scalar(@o_perfvarsL)==0;
    for (my $i=0; $i<scalar(@o_perfvarsL); $i++) {
        $o_perfvarsL[$i] = '&'.$1 if $o_perfvarsL[$i] =~ /^$o_rprefix(.*)$o_rsuffix$/;
    }
    if (defined($o_warn) || defined($o_crit) || defined($o_variables) || (defined($o_timecheck) && $o_timecheck ne '') || (defined($o_hitrate) && $o_hitrate ne '') || (defined($o_repdelay) && $o_repdelay ne '')) {
	if (defined($o_variables)) {
	  @o_varsL=split( /,/ , lc $o_variables );
	  if (defined($o_warn)) {
	     $o_warn.="~" if $o_warn =~ /,$/;
	     @ar_warnLv=split( /,/ , lc $o_warn );
	  }
	  if (defined($o_crit)) {
	     $o_crit.="~" if $o_crit =~ /,$/;
    	     @ar_critLv=split( /,/ , lc $o_crit );
	  }
	}
	elsif (!defined($o_timecheck) && !defined($o_repdelay)) {
	  print "Specifying warning and critical levels requires '-a' parameter with list of variables\n";
	  print_usage();
	  exit $ERRORS{"UNKNOWN"};
        }
        if (defined($o_timecheck) && $o_timecheck ne '') {
          my @o_timeth=split(/,/, lc $o_timecheck);
          verb("Processing timecheck thresholds: $o_timecheck");
          if (scalar(@o_timeth)!=2) {
              printf "Incorrect value '%s' for Connection Time Thresholds. Connection time threshold must include both warning and critical thresholds separated by ','\n", $o_timecheck;
              print_usage();
              exit $ERRORS{"UNKNOWN"};
          }
          unshift(@o_varsL,"response_time");
          unshift(@ar_warnLv,$o_timeth[0]);
          unshift(@ar_critLv,$o_timeth[1]);
        }
        if (defined($o_hitrate) && $o_hitrate ne '') {
          my @o_hrate=split(/,/, lc $o_hitrate);
          verb("Processing hitrate thresholds: $o_hitrate");
          if (scalar(@o_hrate)!=2) {
              printf "Incorrect value '%s' for Hitrate Threshold. You must include both warning and critical thresholds separated by ','\n", $o_hitrate;
              print_usage();
              exit $ERRORS{"UNKNOWN"};
          }
          unshift(@o_varsL,"hitrate");
          unshift(@ar_warnLv,$o_hrate[0]);
          unshift(@ar_critLv,$o_hrate[1]);
        }
        if (defined($o_memutilization) && $o_memutilization ne '') {
          my @o_usize=split(/,/, lc $o_memutilization);
          verb("Processing memory utilization thresholds: $o_memutilization");
          if (scalar(@o_usize)!=2) {
              printf "Incorrect value '%s' for Utilization Threshold. You must include both warning and critical thresholds separated by ','\n", $o_memutilization;
              print_usage();
              exit $ERRORS{"UNKNOWN"};
          }
          unshift(@o_varsL,"memory_utilization");
          unshift(@ar_warnLv,$o_usize[0]);
          unshift(@ar_critLv,$o_usize[1]);
        }
       if (defined($o_repdelay) && $o_repdelay ne '') {
          my @o_rdelay=split(/,/, lc $o_repdelay);
          verb("Processing replication delay thresholds: $o_repdelay");
          if (scalar(@o_rdelay)!=2) {
              printf "Incorrect value '%s' for Replication Delay Threshold. You must include both warning and critical thresholds separated by ','\n", $o_repdelay;
              print_usage();
              exit $ERRORS{"UNKNOWN"};
          }
          unshift(@o_varsL,"replication_delay");
          unshift(@ar_warnLv,$o_rdelay[0]);
          unshift(@ar_critLv,$o_rdelay[1]);
        }
	if (scalar(@ar_warnLv)!=scalar(@o_varsL) || scalar(@ar_critLv)!=scalar(@o_varsL)) {
	  printf "Number of specified warning levels (%d) and critical levels (%d) must be equal to the number of attributes specified at '-a' (%d). If you need to ignore some attribute do it as ',,'\n", scalar(@ar_warnLv), scalar(@ar_critLv), scalar(@o_varsL); 
	  verb("Warning Levels: ".join(",",@ar_warnLv));
	  verb("Critical Levels: ".join(",",@ar_critLv));
	  print_usage();
	  exit $ERRORS{"UNKNOWN"};
	}
	for (my $i=0; $i<scalar(@o_varsL); $i++) {
	  $o_varsL[$i] = '&'.$1 if $o_varsL[$i] =~ /^$o_rprefix(.*)$o_rsuffix$/; # always lowercase here
	  if ($o_varsL[$i] =~ /^&(.*)/) {
		if (!defined($o_prevperf)) {
			print "Calculating rate variable such as ".$o_varsL[$i]." requires previous performance data. Please add '-P \$SERVICEPERFDATA\$' to your nagios command line.\n";
			print_usge();
			exit $ERRORS{"UNKNOWN"};
		}
		if (defined($KNOWN_STATUS_VARS{$1}) && $KNOWN_STATUS_VARS{$1}[0] ne 'COUNTER') {
                	print "$1 is not a COUNTER variable for which rate of changee should be calculated\n";
			print_usage();
                	exit $ERRORS{"UNKNOWN"};
		}
	  }
          $o_warnL[$i] = parse_threshold($ar_warnLv[$i]);
          $o_critL[$i] = parse_threshold($ar_critLv[$i]);
	  if (threshold_specok($o_warnL[$i],$o_critL[$i])) {
                 print "All numeric warning values must be less then critical (or greater then when '<' is used)\n";
                 print "Note: to override this check prefix warning value with ^\n";
                 print_usage();
                 exit $ERRORS{"UNKNOWN"};
           }
	}
    }
    if (defined($o_totalmemory)) {
	if ($o_totalmemory =~ /^(\d+)B/) {
	   $o_totalmemory = $1;
	}
	elsif ($o_totalmemory =~ /^(\d+K)/) {
	   $o_totalmemory = $1*1024;
	}
	elsif ($o_totalmemory =~ /^(\d+M)/) {
	   $o_totalmemory = $1*1024*1024;
	}
	elsif ($o_totalmemory =~ /^(\d+)G/) {
	   $o_totalmemory = $1*1024*1024*1024;
	}
	elsif ($o_totalmemory !~ /^(\d+)$/) {
		print "Total memory value $o_totalmemory can not be interpreted\n";
		print_usage();
		exit $ERRORS{"UNKNOWN"};
	} 
    }
    if (defined($o_prevperf)) {
        if (defined($o_perf)) {
                %prev_perf=process_perf($o_prevperf);
                # put last time nagios was checked in timestamp array
                if (defined($prev_perf{_ptime})) {
                        # push @prev_time, $prev_perf{ptime};
			$perfcheck_time=$prev_perf{_ptime};
                }
                elsif (defined($o_prevtime)) {
                        # push @prev_time, $o_prevtime;
                        # $prev_perf{ptime}=$o_prevtime;
			$perfcheck_time=$o_prevtime;
                }
                else {
                        # @prev_time=();
			$perfcheck_time=undef;
                }
                # numeric sort for timestamp array (this is from lowest time to highiest, i.e. to latest)
                # my %ptimes=();
                # $ptimes{$_}=$_ foreach @prev_time;
                # @prev_time = sort { $a <=> $b } keys(%ptimes);
        }
        else {
                print "need -f option first \n"; print_usage(); exit $ERRORS{"UNKNOWN"};
        }
    }

    # if (scalar(@o_varsL)==0 && scalar(@o_perfvarsL)==0) {
    #	print "You must specify list of attributes with either '-a' or '-A'\n";
    #	print_usage();
    #	exit $ERRORS{"UNKNOWN"};
    #    }

    $HOSTNAME = $o_host if defined($o_host);
    $PORT     = $o_port if defined($o_port);
    $TIMEOUT  = $o_timeout if defined($o_timeout);
}

# Get the alarm signal (just in case nagios screws up)
$SIG{'ALRM'} = sub {
     $redis->quit if defined($redis);
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $ERRORS{"UNKNOWN"};
};

########## MAIN #######

check_options();

# Check global timeout if plugin screws up
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT");
  alarm($TIMEOUT);
}
else {
  verb("no timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

my $sock = new IO::Socket::INET(
  PeerAddr => $HOSTNAME,
  PeerPort => $PORT,
  Proto => 'tcp',
);
if (!$sock) {
  print "CRITICAL ERROR - Can not connect to '$HOSTNAME' on port $PORT\n";
  exit $ERRORS{'CRITICAL'};
}
close($sock);

my $start_time;
my $dsn = $HOSTNAME.":".$PORT;
verb("connecting to $dsn"); 
$start_time = [ Time::HiRes::gettimeofday() ] if defined($o_timecheck);

$redis = Redis-> new ( server => $dsn );

if (!$redis) {
  print "CRITICAL ERROR - Redis Library Error connecting to '$HOSTNAME' on port $PORT\n"; 
  exit $ERRORS{'CRITICAL'};
}

if (!$redis->ping) {
  print "CRITICAL ERROR - Redis Library can not ping '$HOSTNAME' on port $PORT\n";
  exit $ERRORS{'CRITICAL'};
}

# This returns hashref of various statistics/info data
my $stats = $redis->info();

my $dbversion = "";
my $statuscode = "OK";
my $statusinfo = "";
my $statusdata = "";
my $perfdata = "";
my $vnam;
my $dnam;
my $vval;
my $chk = "";
my $i;

# load all data into internal hash array
$dataresults{$_} = [undef, 0, 0] foreach(@o_varsL);
$dataresults{$_} = [undef, 0, 0] foreach(@o_perfvarsL);
$dataresults{'total_keys'} = [0,0,0];
$dataresults{'total_expires'} = [0,0,0];
foreach $vnam (keys %{$stats}) {
     $vval = $stats->{$vnam};
     if (defined($vval)) {
    	verb("Stats Line: $vnam = $vval");
	if (exists($KNOWN_STATUS_VARS{$vnam}) && $KNOWN_STATUS_VARS{$vnam}[0] eq 'VERSION') {
		$dbversion .= $vval;
	}
	elsif ($vnam =~ /^db/) {
		foreach (split(/,/,$vval)) {
			my ($k,$d) = split(/=/,$_);
			dataresults_addvar($vnam.'_'.$k,$d); 
			verb(" - stats data added: ".$vnam.'_'.$k.' = '.$d);
			$dataresults{'total_keys'}[0]+=$d if $k eq 'keys' && isnum($d);
			$dataresults{'total_expires'}[0]+=$d if $k eq 'expires' && isnum($d);
		}
	}
	elsif ($vnam =~ /~slave/) {
		# TODO TODO TODO TODO
	}
	else {
		dataresults_addvar($vnam, $vval);
   	}
     }
     else {
        verb("Stats Data: $vnam = NULL");
     }
}
$redis->quit;
verb("Calculated Data: total_keys=".$dataresults{'total_keys'}[0]);
verb("Calculated Data: total_expires=".$dataresults{'total_expires'}[0]);

# Response Time
if (defined($o_timecheck)) {
    $dataresults{'response_time'}=[0,0,0] if !defined('response_time');
    $dataresults{'response_time'}[0]=Time::HiRes::tv_interval($start_time);;
    $statusdata .= sprintf(" response in %.3fs", $dataresults{'response_time'}[0]);
    $dataresults{'response_time'}[1]++;
    if ($o_timecheck eq '' && defined($o_perf)) {
        $perfdata .= ' response_time=' . $dataresults{'response_time'}[0].'s';
    }
}

# Calculate rate variables
my $timenow=time();
my $ptime=undef;
my $avar;
$ptime=$prev_perf{'_ptime'} if defined($prev_perf{'_ptime'});
if (defined($o_prevperf) && defined($o_perf)) {
   for ($i=0;$i<scalar(@o_varsL);$i++) {
	if ($o_varsL[$i] =~ /^&(.*)/) {
	    $avar = $1;
	    if (defined($dataresults{$avar}) && $dataresults{$avar}[2]==0) {
		$dataresults{$avar}[3]= $avar."=".$dataresults{$avar}[0];
		if (defined($KNOWN_STATUS_VARS{$avar})) {
                	$dataresults{$avar}[3].= $KNOWN_STATUS_VARS{$avar}[1];
          	}
	    }
	    if (defined($prev_perf{$avar}) && defined($ptime)) {
		$dataresults{$o_varsL[$i]}=[0,0,0] if !defined($dataresults{$o_varsL[$i]});
		$dataresults{$o_varsL[$i]}[0]= sprintf("%.2f",
		   ($dataresults{$avar}[0]-$prev_perf{$avar})/($timenow-$ptime));
		verb("Calculating Rate of Change for $avar : ".$o_varsL[$i]."=".$dataresults{$o_varsL[$i]}[0]);
	    }
	}
   }
}

# Hitrate
my $hits_total=0;
my $hits_hits=undef;
my $hitrate_all=0;
if (defined($o_hitrate) && defined($dataresults{'keyspace_hits'}) && defined($dataresults{'keyspace_misses'})) {
    for $avar ('keyspace_hits', 'keyspace_misses') {
        if (defined($o_prevperf) && defined($o_perf) && $dataresults{$avar}[2]==0) {
                $dataresults{$avar}[3]= $avar."=".$dataresults{$avar}[0].'c';
        }
        $hits_hits = $dataresults{'keyspace_hits'}[0] if $avar eq 'keyspace_hits';
        $hits_total += $dataresults{$avar}[0];
    }
    verb("Calculating Hitrate : total=".$hits_total." hits=".$hits_hits);
    if (defined($hits_hits) && defined($prev_perf{'keyspace_hits'}) && defined($prev_perf{'keyspace_misses'}) && $hits_hits > $prev_perf{'keyspace_hits'}) {
        $hitrate_all = $hits_hits/$hits_total*100 if $hits_total!=0;
        $hits_hits -= $prev_perf{'keyspace_hits'};
        $hits_total -= $prev_perf{'keyspace_misses'};
        $hits_total -= $prev_perf{'keyspace_hits'};
        verb("Calculating Hitrate. Adjusted based on previous values. total=".$hits_total." hits=".$hits_hits);
    }
    if (defined($hits_hits)) {
        $dataresults{'hitrate'}=[0,0,0] if !defined($dataresults{'hitrate'});
        if ($hits_total==0) {
                $dataresults{'hitrate'}[0]=0;
        }
        else {
                $dataresults{'hitrate'}[0]=sprintf("%.4f", $hits_hits/$hits_total*100);
        }
        $statusdata.=',' if $statusdata;
        $statusdata .= sprintf(" hitrate is %.2f%%", $dataresults{'hitrate'}[0]);
        $statusdata .= sprintf(" (%.2f%% from launch)", $hitrate_all) if ($hitrate_all!=0);
        $dataresults{'hitrate'}[1]++;
        if ($o_hitrate eq '' && defined($o_perf)) {
                $perfdata .= sprintf(" hitrate=%.4f%%", $dataresults{'hitrate'}[0]);
        }
     }
}

# Replication Delay 
#   TODO: 'master_link_down_since_seconds' will have time if slave entirely disconnected
my $repl_delay=0;
if (defined($o_repdelay) && defined($dataresults{'master_last_io_seconds_ago'}) && defined($dataresults{'role'})) {
    if ($dataresults{'role'}[0] eq 'slave') {
        if (defined($o_prevperf) && defined($o_perf) && $dataresults{'master_last_io_seconds_ago'}[2]==0) {
		$dataresults{'master_last_io_seconds_ago'}[3] = "replication_delay=".$dataresults{'master_last_io_seconds_ago'}[0];
	}
	$repl_delay = $dataresults{'master_last_io_seconds_ago'}[0];
    	$dataresults{'replication_delay'}=[0,0,0] if !defined($dataresults{'replication_delay'});
	if ($repl_delay==0) {
		$dataresults{'replication_delay'}[0]=0;
	}
	else {
		$dataresults{'replication_delay'}[0]=$repl_delay;
	}
	$statusdata.=',' if $statusdata;
	$statusdata .= sprintf(" replication_delay is %.2f%%", $dataresults{'replication_delay'}[0]);
	$dataresults{'replication_delay'}[1]++;
	if ($o_repdelay eq '' && defined($o_perf)) {
		$perfdata .= sprintf(" replication_delay=%.5f%%", $dataresults{'replication_delay'}[0]);
	}
     }
}

# Memory Use Utilization
if (defined($o_memutilization) && defined($dataresults{'used_memory_rss'})) {
    if (defined($o_totalmemory)) {
	$dataresults{'memory_utilization'}=[0,1,0];
        $dataresults{'memory_utilization'}[0]=$dataresults{'used_memory_rss'}[0]/$o_totalmemory*100;
	verb('memory utilization % : '.$dataresults{'memory_utilization'}[0].' = '.$dataresults{'used_memory_rss'}[0].' (used_memory_rss) / '.$o_totalmemory.' * 100');
    }
    elsif ($o_memutilization ne '') {
	print "ERROR: Can not calculate memory utilization if you do not specify total memory on a system (-M option)\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"};
    }
    if (defined($dataresults{'memory_utilization'}) && $o_memutilization eq '' && defined($o_perf)) {
        $perfdata .= sprintf(" memory_utilization=%.5f%%", $dataresults{'memory_utilization'}[0]);
    }
    if (defined($dataresults{'used_memory_human'}) && defined($dataresults{'used_memory_peak_human'})) {
	$statusdata.=', ' if $statusdata;
	$statusdata.="memory use is ".$dataresults{'used_memory_human'}[0]." (";
	$statusdata.='peak '.$dataresults{'used_memory_peak_human'}[0];
	if (defined($dataresults{'memory_utilization'})) {
		$statusdata.= sprintf(", %.2f%% of max", $dataresults{'memory_utilization'}[0]);
	}
	if (defined($dataresults{'mem_fragmentation_ratio'})) {
		$statusdata.=", fragmentation ".$dataresults{'mem_fragmentation_ratio'}[0].'%';
	}
	$statusdata.=")";
    }
}

# We split into prefix/suffix again but without lowercasing $o_ratelabel first
($o_rprefix,$o_rsuffix)=split(/,/,$o_ratelabel) if defined($o_ratelabel) && $o_ratelabel ne '';

# main loop to check if warning & critical attributes are ok
for ($i=0;$i<scalar(@o_varsL);$i++) {
  $avar=$o_varsL[$i];
  my $avar_out = $avar;
  if ($avar =~ /^&(.*)/) {
	$avar_out = $o_rprefix.$1.$o_rsuffix;
  }
  if (defined($dataresults{$avar}[0])) {
    if ($avar ne 'hitrate' || $dataresults{$avar}[0]>0) {
        if ($chk = check_threshold($avar,lc $dataresults{$avar}[0],$o_critL[$i])) {
	    $dataresults{$avar}[1]++;
	    $statuscode = "CRITICAL";
            $statusinfo .= $chk;
        }
        elsif ($chk = check_threshold($avar,lc $dataresults{$avar}[0],$o_warnL[$i])) {
	    $dataresults{$avar}[1]++;
	    $statuscode="WARNING" if $statuscode eq "OK";
	    $statusinfo .= $chk;
	}
    }
    if ($dataresults{$avar}[1]==0) {
	  $dataresults{$avar}[1]++;
	  $statusdata .= ", " if $statusdata;
	  $statusdata .= $avar_out . " is " . $dataresults{$avar}[0];
    }
    if (defined($o_perf) && $dataresults{$avar}[2]==0) {
	  $dataresults{$avar}[3]=$avar_out."=".$dataresults{$avar}[0];
	  if (defined($KNOWN_STATUS_VARS{$avar})) {
		$dataresults{$avar}[3] .= $KNOWN_STATUS_VARS{$avar}[1];
	  }
	  if (defined($o_warnL[$i][5]) && defined($o_critL[$i][5])) {
	    $dataresults{$avar}[3] .= ';' if $o_warnL[$i][5] ne '' || $o_critL[$i][5] ne '';
	    $dataresults{$avar}[3] .= $o_warnL[$i][5] if $o_warnL[$i][5] ne '';
	    $dataresults{$avar}[3] .= ';'.$o_critL[$i][5] if $o_critL[$i][5] ne '';
	  }
    }
  }
  else {
	$statuscode="CRITICAL";
	$statusinfo .= " $o_varsL[$i] data is missing";
  }
}

# add performance data variables
for ($i=0;$i<scalar(@o_perfvarsL);$i++) {
  $avar=$o_perfvarsL[$i];
  if (defined($dataresults{$avar}[0]) && $dataresults{$avar}[2]==0 && 
	(!defined($KNOWN_STATUS_VARS{$avar}) || 
         $KNOWN_STATUS_VARS{$avar}[0] =~ /$PERF_OK_STATUS_REGEX/ )) {
    if (defined($dataresults{$avar}[3])) {
	$perfdata .= " " . $dataresults{$avar}[3];
    }
    else {
        $perfdata .= " " . $avar . "=" . $dataresults{$avar}[0];
        if (defined($KNOWN_STATUS_VARS{$avar})) {
            $perfdata .= $KNOWN_STATUS_VARS{$avar}[1];
        }
    }
    $dataresults{$avar}[2]++;
  }
}
if (defined($o_prevperf)) {
  $perfdata .= " _ptime=".$timenow;
}
foreach $avar (keys %dataresults) {
  if (defined($dataresults{$avar}[3]) && $dataresults{$avar}[2]==0) {
    $perfdata .= " " . $dataresults{$avar}[3];
    $dataresults{$avar}[2]++;
  }
}

# now output the results
print $statuscode . $statusinfo." ";
print "- " if $statusinfo;
print "REDIS " . $dbversion . ' on ' . $HOSTNAME. ':'. $PORT;
print ' up '.uptime_info($dataresults{'uptime_in_seconds'}[0]) if defined($dataresults{'uptime_in_seconds'}); 
print " -" . $statusdata if $statusdata;
print " |" . $perfdata if $perfdata;
print "\n";

# end exit
exit $ERRORS{$statuscode};
