#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_memcached.pl
# Version : 0.7
# Date    : July 18, 2012
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
# This is Memcached Check plugin. It gets stats variables and allows to set thresholds
# on their value or their rate of change. It can measure response time, calculate
# hitrate, memory utilization and other data. The plugin is based on check_mysqld.pl.
#
# It also returns status variables as perfomance data for further nagios 2.0
# post-processing, you can find graph templates NagiosGrapher & PNP4Nagios at:
#   http://william.leibzon.org/nagios/
#
# This program is written and maintained by:
#   William Leibzon - william(at)leibzon.org
#
# ============================= SETUP NOTES ====================================
#
# Make sure to install perl Cache::Memcached library from CPAN first.
#
# This plugin checks Memcached and measures response which can be used for
# threshold checks. It also retrieves various statistics data available with
# memcache 'stats' command (what you get when you telnet to the port and
# do 'stats') and allows to set thresholds either on their direct values
# or on rate of change of those variables. Plugin also calculates other useful
# statistics like Hitrate (calculated on rate of change unlike all other plugins
# that do it based on totals for all the time) and Memory Utilization and allows
# to set thresholds on their values. All variables can be returned back as
# performance data for graphing and pnp4nagios template should be available
# with this plugin on the same site you downloaded it from.
#
# For help on what parameters this plugin accepts you can just do
#  ./check_memcached.pl --help
#
# 1. Connection Parameters
#
#   Plugin currently does not support authentication so the only connection
#   parameters are "-H hostname" and "-p port". The default port is 11211
#   and you must specify the hostname (if localhost specify it as -H 127.0.0.1)
# 
# 2. Response Time, HitRate, Memory Utilization
#
#   To get response time you use "-T" or "--response_time" option. By itself
#   it will cause output of respose time at the status line. You can also use
#   it as "-T warn,crit" to specify warning and critical thresholds.
#
#   To get hitrate the option is "-R" or "--hitrate". If previous performance
#   data is not feed to plugin (-P option, see below) the plugin calculates
#   it as total hitrate over life of memcached process. If -P is specified
#   and previous performance data is feed back, the data is based on real
#   hitrate with lifelong info also given in paramphesis. As with -T you
#   can specify -R by itself or with thresholds as -R warn,crit
# 
#   Memory utilization corresponds to what some others call "size". This is
#   percent of max memory currently in use. The option is -U or --utilization
#   and as you probably guessed can be used by itself or as -U warn,crit
#
# 3. Memcache Statistics Variables and calculating their Rate of Change
#
#   All statistics variables from memcached 'stats' can be checked with the plugin. 
#   And as some people know there are actually several stats arrays in memcached. 
#   By default the plugin will get statistics for 'misc' and 'malloc'. You can
#   specify a list of statistics array names (corresponding to 'stats name'
#   command in memcached) with -s or --stats command. Known arrays are:
#     misc, malloc, sizes, maps, cachedump, slabs, items 
#   And example of trying to retrieve all of them is:
#     -s misc,malloc,sizes,maps,cachedump,slabs,items
#   However not all of them will have data in your system and arrays like
#   sizes provide too much data (how many items stored on each size)
#   for standard use.
#
#   To see stat variables in plugin status output line and or specify thresholds
#   based on their values you would use -a or --variables argument. For example:
#       -a curr_connections,evictions
#   You must specify same number of warning and critical thresholds with 
#   -w or --warn and -c or --crit argument as a number of variables specified
#   in -a. If you simply want variable values on status without checking their value
#   then either use ~ in place of threshold value or nothing at all. For example:
#           -a curr_connections,evictions -w ~,~ -c ~,~
#      OR   -a curr_connections,evictions -w , -c ,
#
#
#   If you want to check rate of change rather than actual value you can do this
#   by specifying it as '&variable' such as "&total_connections" or "variable_rate"
#   which is "total_connections_rate" and is similar to 'curr_connections' variable.
#   By default it would be reported in the output as 'variable_rate' though '&variable'
#   is a format used internally by plugin. As an alternative you can specify how to
#   label these with --rate_label option where you can specify prefix and/or suffix.
#   For example '--rate_label=dt_' would have the output being "dt_total_connections'
#   where as '---rate_label=,_rate' is plugin default giving 'total_connections_rate'. 
#   You can use these names with -a and -A such as:
#           --rate_label=,_rate -a total_connections_rate -w 1000 -c ~
#
#   Now in order to be able to calculate rate of change, the plugin needs to
#   know values of the variables from when it was run the last time. This
#   is done by feeding it previous performance data with a -P option.
#   In commands.cfg this would be specified as:
#     -P "$SERVICEPERFDATA$"
#   And don't forget the quotes, in this case they are not just for documentation.
# 
# 4. Threshold Specification
#
#   The plugin fully supports Nagios plug-in specification for specifying thresholds:
#     http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT
#
#   And it supports an easier format with the following one-letter prefix modifiers:
#     >value : issue alert if data is above this value (default for numeric value)
#     <value : issue alert if data is below this value (must be followed by number)
#     =value : issue alert if data is equal to this value (default for non-numeric)
#     !value : issue alert if data is NOT equal to this value
#
#   There are two two specifications of range formats as with other nagios plugins:
#     number1:number2   issue alert if data is OUTSIDE of range [number1..number2]
#	                i.e. alert if data<$number1 or data>$number2
#     @number1:number2  issue alert if data is WITHIN range [number1..number2] 
#		        i.e. alert if data>=$number and $data<=$number2
#
#   The plugin will attempt to check that WARNING values is less than CRITICAL
#   (or greater for <). A special prefix modifier '^' can be used to disable these
#   checks. A quick example of such special use is '--warn=^<100 --crit=>200' which
#   means warning alert if value is < 100 and critical alert if its greater than 200.
#
# 5. Performance Data
#
#   Using '-f' option causes values of all variables you specified in -a as
#   well as response time from -T, hitrate from -R and memory use from -U
#   to go out as performance data for Nagios graphing programs that can use it.
#
#   You may also directly specify which variables are to be return as performance data
#   with '-A' option. If you use '-A' by itself and not specify any variables or use
#   special special value of '*' (as in '-A *') the plugin will output all variables,
#   which is really useful for finding what data you can chck with this plugin.
#
#   The plugin will output threshold values as part of performance data as specified at
#     http://nagiosplug.sourceforge.net/developer-guidelines.html#AEN201
#   And don't worry about using non-standard >,<,=,~ prefixes, all of that would get
#   converted into nagios threshold format for performance output
#
#   The plugin is smart enough to add 'c' suffix for known COUNTER variables to
#   values in performance data. Known variables are specifed in an array you can
#   find at the top of the code (further below) and plugin author does not claim
#   to have identified all variables correctly. Please email if you find an error
#   or want to add more variables.
# 
#   As noted above performance data is also used to calcualte rate of change
#   by feeding it back with -P option. In that regard even if you did not specify
#   -f or -A but you have specified &variable, its actual data would be sent out
#   in performance output. Additionally last time plugin was run is also in
#   performance data as special _ptime variable.
#
# 6. Example of Nagios Config Definitions
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
#   /usr/lib/nagios/plugins/check_memcached.pl -H localhost -a 'curr_connections,evictions' -w ~,~ -c ~,~ -s misc,malloc,sizes -U -A -R -T -f -v
#
# In above the -v option means "verbose" and with it plugin will output some debugging
# information about what it is doing. The option is not intended to be used when plugin
# is called from nagios itself. 
#
# ======================= VERSION HISTORY and TODO ================================
#
# The plugins is written by reusing code my check_mysqld.pl which similarly to
# this plugin allows to get STATUS variables and use these for nagios tests.
# check_mysqld.pl has history going back to 2004.
#
#  [0.5 - Mar 2012] First version of the code based on check_mysqld.pl 0.93
#		    This is being released as 0.5 because its coming from
#		    a very mature code of check_mysqld and has a lot of options
#		    If there are no major issues found with this plugin, next
#		    version will be 1.0
#
#  [0.6 - Apr 2012] Added support for re-using old performance data to calculate
#		    rate of change for certain variables. This also changes how
#		    hitrate is calcualted as now if previous performance data
#		    is available, hitrate would be #misses/#total from last check
#		    rather than #misses/#total from start of statistics.
#  [0.61 - Apr 2012] Documentation fixes and small bugs
#  [0.62 - May 2012] Cache::Memcached library has bugs and not always provided hash of
#	             array with results for each statistics just giving raw memcached
#		     data. This effected 'items' and 'slabs' statistics and maybe others.
#		     Plugin can now handle parsing such data into separate variables.
#  [0.63 - Jun 10 2012] Documentation fixes.
#		        Default rate variable name changed from &Delta_variable to
#                       variable_rate to be in sync with check_redis.pl. One of the reasons
#                       is that in the future I'll plan to add variables that are real 
#                       delta i.e new_value-old_value and not (new_value-old_value)/time
#		        Also I've decided that specifying prefix & suffix or rate label
#                       variables will not be one-letter option and only long-name option
#                       As such -L option has been depreciated. I'm doing it all early
#                       because only few currently use this and its not too late to change
# [0.64 - Jun 16, 2012] Added support to specify filename to '-v' option
#			for debug output and '--debug' as alias to '--verbose'
#
# [0.7  - July 18, 2012] Rewrote parts of thresholds checking code and moved code
#			 that checks and parses thresholds from main into separate
#			 functions that are to become part of plugin library.
#			 Added support for variable thresholds specified as:
#			   option=WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL,ZERO:..
#			 which are to be used for stats-variable based long options such as
#			   --connected_clients=WARN:threshold,CRIT:threshold
#			 and added DISPLAY:YES|NO and PERF specifiers for above too.
#
# TODO or consider for future:
#
#  1. Library Enhancements (will apply to multiple plugins that share common code)
#     (a) Add '--extra-opts' to allow to read options from a file as specified
#         at http://nagiosplugins.org/extra-opts. This is TODO for all my plugins
#     (b) [DONE]
#	  In plans are to allow long options to specify thresholds for known variables.
#         These would mean you specify '--connected_clients' in similar way to '--hitrate'
#         Internally these would be convered into -A, -w, -c as appropriate an used
#         together with these options. So in practice it will now allow to get any data
#         just a different way to specify options for this plugin. 
#     (c) Allow regex when selecting variable name(s) with -a, this will be enabled with
#	  a special option and not be default
#
#  2. Memcached Specific
#     (a) Support SASL Authentication
#     (b). There has been a request to allow to specify threshold checks both for each slab
#          (which is possible to do now starting with 0.62 version of the plugin) and for
#          all slabs as well. This applies to "items" and "slabs" statistics and will probably
#          be implimented by allowing regex checks in place of specific variable name.
#
#  Others are welcome recommand a new feature to be added here. If so please email to 
#         william@leibzon.org.
#  And don't worry, I'm not a company with some hidden agenda to use your idea
#  but an actual person who you can easily get hold of by email, find on forums
#  and on Nagios conferences. More info on my nagios work is at:
#         http://william.leibzon.org/nagios/
#  Above site should also have PNP4Nagios template for this and other plugins.
#
# ============================ START OF PROGRAM CODE =============================

use strict;
use IO::Socket;
use Time::HiRes;
use Cache::Memcached;
use Getopt::Long qw(:config no_ignore_case);

# default hostname, port, database, user and password, see NOTES above
my $HOSTNAME= 'localhost';
my $PORT=     11211;

# Add path to additional libraries if necessary
use lib '/usr/lib/nagios/plugins';
our $TIMEOUT;
our %ERRORS;
eval 'use utils qw(%ERRORS $TIMEOUT)';
if ($@) {
 $TIMEOUT = 20;
 %ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
}

my $Version='0.7';

# This is a list of known statistics variables (plus few variables added by plugin),
# used in order to designate COUNTER variables with 'c' in perfout for graphing programs
my %KNOWN_STATUS_VARS = (
	 'version' =>  [ 'VERSION', '' ],		# memcached version
	 'utilization' => [ 'GAUGE', '%' ],		# calculated by plugin
	 'hitrate' => [ 'GAUGE', '%' ],			# calculated by plugin
	 'response_time' => [ 'GAUGE', 's' ],		# measured by plugin
	 'curr_connections' => [ 'GAUGE', '', "Number of Current Connections" ],
	 'evictions' => [ 'COUNTER', 'c', "Total Number of Evictions from Start" ],
	 'bytes' => [ 'GAUGE', 'B', "Amount of Data Stored in Bytes" ],
	 'connection_structures' => [ 'GAUGE', '', "Number of Connection Structures" ],
	 'time' => [ 'COUNTER', 's' ],
	 'total_items' => [ 'COUNTER', 'c', "Total Items Stored from Start" ],
	 'cmd_set' => [ 'COUNTER', 'c' ],
	 'bytes_written' => [ 'COUNTER', 'c', "Total Number of Bytes Written to Cache" ],
	 'curr_items' => [ 'GAUGE', '', "Number of Items Currently Stored" ],
	 'limit_maxbytes' => [ 'GAUGE', 'B', "Maximum memory available for storage" ],
	 'uptime' => [ 'COUNTER', 's', "Uptime in Seconds" ],
	 'rusage_user' => [ 'COUNTER', 's' ],
	 'cmd_get' => [ 'COUNTER', 'c', "Total Number of Get Commands from Start" ],
	 'rusage_system' => [ 'COUNTER', 's' ],
	 'get_hits' => [ 'COUNTER', 'c', "Total Number of Hits from Start" ],
	 'bytes_read' => [ 'COUNTER', 'c', "Total Number of Bytes Read from Cache" ],
	 'threads' => [ 'GAUGE', '', "Number of running Threads" ],
	 'rusage_user_ms' => [ 'COUNTER', 'c' ],    	# this is round(rusage_user*1000)
	 'rusage_system_ms' => [ 'COUNTER', 'c' ],	# this is round(rusage_system*1000)
	 'total_connections' => [ 'COUNTER', 'c', "Number of Connections made from Start" ],
	 'get_misses' => [ 'COUNTER', 'c', "Total Misses from Start" ],
	 'total_free' => [ 'GAUGE', 'B', "Amount of Free Memory in bytes" ],
	 'releasable_space' => [ 'GAUGE', 'B' ],
	 'free_chunks' => [ 'GAUGE', '' ],
	 'fastbin_blocks' => [ 'GAUGE', '' ],
	 'arena_size' => [ 'GAUGE', '' ],
	 'total_alloc' => [ 'GAUGE', 'B' ],
	 'max_total_alloc' => [ 'GAUGE', '' ],
	 'mmapped_regions' => [ 'GAUGE', '' ],
	 'mmapped_space' => [ 'GAUGE', '' ],
	 'fastbin_space' => [ 'GAUGE', '' ],
	 'auth_cmds' => [ 'COUNTER', 'c', "Total Number of Auth Commands from Start" ],
	 'auth_errors' => [ 'COUNTER', 'c', "Total Number of Auth Errors from Start" ],
	);

# Here you can also specify which variables should go into perf data, 
# For right now it is 'GAUGE', 'COUNTER', 'DATA' (but not 'TEXTDATA'), and 'BOOLEAN'
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
my $o_crit=     undef;          # Critical level option
my $o_perf=     undef;          # Performance data option
my $o_timeout=  undef;          # Timeout to use - note that normally timeout is take from nagios anyway
my $o_mdsopt=	undef;		# Stat List to get data for
my @o_mdslist= ('misc','malloc'); # Default List, if -S option is entered, this is replaced 
my $o_timecheck=undef;          # threshold spec for connection time
my $o_hitrate=	undef;		# threshold spec for hitrate%
my $o_utilsize=	undef;		# threshold spec for utilization%
my $o_prevperf= undef;		# performance data given with $SERVICEPERFDATA$ macro
my $o_prevtime= undef;		# previous time plugin was run $LASTSERVICECHECK$ macro
my $o_ratelabel=undef;		# prefix and suffix for creating rate variables
my $o_rsuffix='_rate';		# default rate variable name suffix
my $o_rprefix="";

## Additional global variables
my @allVars = ();		# all variables after options processing
my @ar_warnLv = ();		# used in options processing
my @ar_critLv = ();		# used in options processing
my @query=();			# array of queries with each entry being keyed hash of processedoption data on howto query
my %thresholds=();		# this replaces @o_warnL and @o_critL with a hash array of all threshold data
my $memd= undef;                # DB connection object
my %prev_perf=  ();		# array that is populated with previous performance data
my @prev_time=  ();     	# timestamps if more then one set of previois performance data
my $perfcheck_time=undef;	# time when data was last checked 
my %dataresults= ();		# this is where data is loaded into
my $statuscode = "OK";		# final status code
my $statusinfo = "";		# if there is an error, this has human info about what it is
my $statusdata = "";		# if there is no error but we want some data in status line, this var gets it
my $perfdata = "";		# this variable collects performance data line

sub p_version { print "check_memcached.pl version : $Version\n"; }

sub print_usage_line {
   print "Usage: $0 [-v [debugfilename]] -H <host> [-p <port>] [-s <memcache stat arrays>] [-a <memcache statistics variables> -w <variables warning thresholds> -c <variables critical thresholds>] [-A <performance output variables>] [-T [conntime_warn,conntime_crit]] [-R [hitrate_warn,hitrate_crit]] [-U [utilization_size_warn,utilization_size_crit]] [-f] [-T <timeout>] [-V] [-P <previous performance data in quoted string>]\n";
}

sub print_usage {
   print_usage_line();
   print "For more details on options do: $0 --help\n";
}

sub help {
   print "Memcache Check for Nagios version ",$Version,"\n";
   print " by William Leibzon - william(at)leibzon.org\n\n";
   print "This memcached monitoring plugin lets you do threshold checks on status variables\n";
   print "and returnes performance data for graphing and other processing.\n\n";
   print_usage_line();
   print <<EOT;

General and Server Connection Options:
 -v, --verbose[=FILENAME], --debug[=FILENAME]
   Print extra debugging information.
   If filename is specified instead of STDOUT the debug data is written to that file.
 -h, --help
   Print this detailed help screen
 -H, --hostname=ADDRESS
   Hostname or IP Address to check
 -p, --port=INTEGER
   port number (default: 3306)
 -t, --timeout=NUMBER
   Allows to set timeout for execution of this plugin. This overrides nagios default.
 -s, --stat=<list of stat arrays>
   This allows to list stat arrays that would be queried (separated by ',').
   Supported memcache statistics array are:
      misc, malloc, sizes, maps, cachedump, slabs, items
   If this option is not specified, the plugin will check only 'misc' and 'malloc'
 -V, --version
   Prints version number

Variables and Thresholds Set as List:
 -a, --variables=STRING[,STRING[,STRING...]]
   List of variables from memcache statistics data to do threshold checks on.
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

Performance Data Processing Options:
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
 --rate_label=[PREFIX_STRING[,SUFFIX_STRING]]
   Prefix or Suffix label used to create a new variable which has rate of change
   of another base variable. You can specify PREFIX or SUFFIX or both. Default
   if not specified is '_rate' suffix string i.e. --rate_label=,_rate

Measured/Calculated Data:
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
 -U, --utilization=[WARN,CRIT]
   This calculates percent of space in use, which is bytes/limit_maxbytes
   In some other places this is called size, but since this plugin can
   actually get objects of different size, utilization is more appropriate.
   If you specify -U by itself, the plugin will just output this info,
   with '-f' it will also include it in performance data. You can also specify
   parameter value which are interpreted as WARNING and CRITICAL thresholds.

Stats Variable Options (this is alternative to specifying them as list with -a):
  These options are all --long_name=<list of specifiers separated by ,>
  where specifiers are one or more of:
    WARN:threshold  - warning alert threshold
    CRIT:threshold  - critical alert threshold
      Where threshold is a value which may have the following prefix:
        > - warn if data is above this value (default for numeric values)
        < - warn if data is below this value (must be followed by number)
        = - warn if data is equal to this value (default for non-numeric values)
        ! - warn if data is not equal to this value
      Threshold can also be specified as range in two forms:
        num1:num2  - warn if data is outside range i.e. if data<num1 or data>num2
        \@num1:num2 - warn if data is in range i.e. data>=num1 && data<=num2
    ABSENT:OK|WARNING|CRITICAL|UNKNOWN - Nagios alert (or lock of thereof) if data is absent
    ZERO:OK|WARNING|CRITICAL|UNKNOWN   - Nagios alert (or lock of thereof) if result is 0
    DISPLAY:YES|NO  - Specifies if data should be included in nagios status line output
    PERF:YES|NO     - Output results as performance data or not (always YES if asked for rate)

EOT
  # add more options based on KNOWN_STATUS_VARS array
  my ($vname,$vname2) = (undef,undef);
  foreach (keys(%KNOWN_STATUS_VARS)) {
     $vname = $_;
     $vname2=$o_rprefix.$vname.$o_rsuffix;
     if (exists($KNOWN_STATUS_VARS{$vname}[2])) {
	print ' --'.$vname."=WARN:threshold,CRIT:threshold,<other specifiers>\n";
	print "   ".$KNOWN_STATUS_VARS{$vname}[2]."\n";
	if ($KNOWN_STATUS_VARS{$vname}[0] eq 'COUNTER') {
	    print ' --'.$vname2."=WARN:threshold,CRIT:threshold,<other specifiers>\n";
	    print "   Rate of Change of ".$KNOWN_STATUS_VARS{$vname}[2]."\n";
	}
     }
  }
  printf("\n");
}

############################ START OF THE LIBRARY FUNCTIONS #################################

sub div_mod { return int( $_[0]/$_[1]) , ($_[0] % $_[1]); }

# this converts uptime in seconds to nice & short output format
sub uptime_info {
  my $uptime_seconds = shift;
  my $upinfo = "";
  my ($secs,$mins,$hrs,$days) = (undef,undef,undef,undef);
  ($mins,$secs) = div_mod($uptime_seconds,60);
  ($hrs,$mins) = div_mod($mins,60);
  ($days,$hrs) = div_mod($hrs,24);
  $upinfo .= "$days days" if $days>0;
  $upinfo .= (($upinfo ne '')?' ':'').$hrs." hours" if $hrs>0;
  $upinfo .= (($upinfo ne '')?' ':'').$mins." minutes" if $mins>0 && ($days==0 || $hrs==0);
  $upinfo .= (($upinfo ne '')?' ':'').$secs." seconds" if $secs>0 && $days==0 && $hrs==0; 
  return $upinfo;
}

# For verbose output (updated 06/06/12 to write to debug file if specified)
sub verb {
    my $t=shift;
    if (defined($o_verb)) {
	if ($o_verb eq "") {
		print $t, "\n";
	}
	else {
	    if (!open (DEBUGFILE, ">>$o_verb")) {
		print $t, "\n";
	    }
	    else {
		print DEBUGFILE $t,"\n";
		close DEBUGFILE;
	    }
	}
    }
}

# Return true if arg is a number
sub isnum {
  my $num = shift;
  if (defined($num) && $num =~ /^[-|+]?((\d+\.?\d*)|(^\.\d+))$/ ) { return 1 ;}
  return 0;
}

sub trim {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}

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

sub add_to_statusinfo {
    my @IN = @_;
    my $sline="";
    $sline .= $_ foreach(@IN);
    $sline = trim($sline);
    $statusinfo .= ", " if $statusinfo;
    $statusinfo .= $sline;
}

sub add_to_statusdata {
    my ($avar,$adata) = @_;
    if ((!exists($thresholds{$avar}{'DISPLAY'}) || $thresholds{$avar}{'DISPLAY'} eq 'YES') &&
        (!exists($dataresults{$avar}[1]) || $dataresults{$avar}[1]==0)) {
           if (defined($adata)) {
              $statusdata .= ", " if $statusdata;
              $statusdata .= trim($adata);
           }
           elsif (exists($dataresults{$avar}[0])) {
              $statusdata .= ", " if $statusdata;
              $statusdata .= $avar ." is ".$dataresults{$avar}[0];
           }
           $dataresults{$avar}[1]++;
    }
}

sub add_to_perfdata {
    my ($avar,$adata) = @_;
    if ((!exists($thresholds{$avar}{'PERF'}) || $thresholds{$avar}{'PERF'} eq 'YES') &&
        (!exists($dataresults{$avar}[2]) || $dataresults{$avar}[2]<1)) {
           if (defined($adata)) {
              $perfdata .= " " if $perfdata;
              $perfdata .= trim($adata);
           }
           elsif (exists($dataresults{$avar}[0])) {
              $perfdata .= " " if $perfdata;
              $perfdata .= $avar."=".$dataresults{$avar}[0];
              if (defined($KNOWN_STATUS_VARS{$avar})) {
                 $perfdata .= $KNOWN_STATUS_VARS{$avar}[1];
              }
           }
	   $dataresults{$avar}[2]=0 if $dataresults{$avar}[2]<0;
           $dataresults{$avar}[2]++;
    }
}

sub preset_perfdata {
    my ($avar,$adata) = @_;
    $dataresults{$avar}=[undef,0,0,''] if !defined($dataresults{$avar});
    $dataresults{$avar}[2]=-1;
    $dataresults{$avar}[3]=$adata;
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
    # array: 1st is type of check, 2nd is threshold value or value1 in range, 3rd is value2 in range,
    #        4th is extra options such as ^, 5th is nagios spec string representation for perf out
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

sub thresholds_addvar {
    my ($var,$th) = @_;
    push @allVars, $var if !exists($thresholds{$var});
    $thresholds{$var}=$th;
}

# this function parses "WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL|UNKNOWN" text
# parsing of actual threshold after WARN, CRIT is done by parse_threshold function
sub parse_thresholds_optionsline {
   my $in = shift;
   my $thres = {};
   my @tin = split (',', uc $in);
   # old format with =warn,crit thresolds without specifying which one
   if (exists($tin[0]) && $tin[0] !~ /^WARN/ && $tin[0] !~ /^CRIT/ && $tin[0] !~ /^ABSENT/ && $tin[0] !~ /^ZERO/ && $tin[0] !~ /^DISPLAY/ && $tin[0] !~ /^PERF/) {
	if (scalar(@tin)==2) {
	     $thres->{'WARN'} = parse_threshold($tin[0]); 
	     $thres->{'CRIT'} = parse_threshold($tin[1]);
	}
	else {
	     print "Can not parse. Unknown threshold specification: $in\n";
	     print "Threshold line should be either both warning and critical thresholds separated by ',' or \n";
	     print "new format of: WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL|UNKNOWN\n";
	     print "which allows to specify all 3 (CRIT,WARN,ABSENT) checks or any one of them in any order\n";
             print_usage();
             exit $ERRORS{"UNKNOWN"};
	}
   }
   # new format with prefix specifying if its WARN or CRIT and support of ABSENT
   else {
	foreach(@tin) {
	     if (/^WARN\:(.*)/) {
		    $thres->{'WARN'} = parse_threshold($1);
	     }
	     elsif (/^CRIT\:(.*)/) {
		    $thres->{'CRIT'} = parse_threshold($1);
	     }
	     elsif (/^ABSENT\:(.*)/) {
		    if (exists($ERRORS{$1})) {
			$thres->{'ABSENT'} = $1;
		    }
		    else {
			print "Invalid value $1 after ABSENT. Acceptable values are: OK, WARNING, CRITICAL, UNKNOWN\n";
			print_usage();
			exit $ERRORS{"UNKNOWN"};
		    }
	     }
	     elsif (/^ZERO\:(.*)/) {
		    if (exists($ERRORS{$1})) {
			$thres->{'ZERO'} = $1;
		    }
		    else {
			print "Invalid value $1 after ZERO. Acceptable values are: OK, WARNING, CRITICAL, UNKNOWN\n";
			print_usage();
			exit $ERRORS{"UNKNOWN"};
		    }
	     }
	     elsif (/^DISPLAY\:(.*)/) {
		   if ($1 eq 'YES' || $1 eq 'NO') {
			$thres->{'DISPLAY'} = $1;
		   }
		   else {
			print "Invalid value $1 after DISPLAY. Specify this as YES or NO.\n";
			print_usage();
			exit $ERRORS{"UNKNOWN"};
		   }
	     }
	     elsif (/^PERF\:(.*)/) {
                  if ($1 eq 'YES' || $1 eq 'NO') {
                        $thres->{'PERF'} = $1;
                   }
                   else {
                        print "Invalid value $1 after PERF. Specify this as YES or NO.\n";
                        print_usage();
                        exit $ERRORS{"UNKNOWN"};
                   }
             }
	     else {
		    print "Can not parse. Unknown threshold specification: $_\n";
		    print "Threshold line should be WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL|UNKNOWN,ZERO:OK|WARNING|CRITICAL|UNKNOWN\n";
		    print_usage();
		    exit $ERRORS{"UNKNOWN"};
	     }
	}
   }
   if (exists($thres->{'WARN'}) && exists($thres->{'CRIT'})) {
	  if (threshold_specok($thres->{'WARN'},$thres->{'CRIT'})) {
                 print "All numeric warning values must be less then critical (or greater then when '<' is used)\n";
                 print "Note: to override this check prefix warning value with ^\n";
                 print_usage();
                 exit $ERRORS{"UNKNOWN"};
          }
   }
   return $thres;
}

sub additional_options_list {
    my @VarOptions = ();
    foreach(keys %KNOWN_STATUS_VARS) {
        my $v = $_;
        my $v2 = $o_rprefix.$v.$o_rsuffix;
        if (exists($KNOWN_STATUS_VARS{$v}[2]) && $KNOWN_STATUS_VARS{$v}[2] ne '') {
              push @VarOptions,$v."=s";
              push @VarOptions,$v2."=s" if $KNOWN_STATUS_VARS{$v}[0] eq 'COUNTER'; 
        }
    }
    return @VarOptions;
}

sub options_startprocessing {
    my $Options = shift;
    # Processing of variables-list -a, -A and thresholds -w, -c options
    @ar_warnLv = ();
    @ar_critLv = ();
    ($o_rprefix,$o_rsuffix)=split(/,/,lc $o_ratelabel) if defined($o_ratelabel) && $o_ratelabel ne '';
    @o_perfvarsL=split( /,/ , lc $o_perfvars ) if defined($o_perfvars) && $o_perfvars ne '*';
    $o_perfvars='*' if defined($o_perfvars) && scalar(@o_perfvarsL)==0;
    for (my $i=0; $i<scalar(@o_perfvarsL); $i++) {
        $o_perfvarsL[$i] = '&'.$1 if $o_perfvarsL[$i] =~ /^$o_rprefix(.*)$o_rsuffix$/;
    }
    if (defined($o_warn) || defined($o_crit) || defined($o_variables)) {
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
	else {
	  print "Specifying warning and critical thresholds with -w and -c requires '-a' parameter with list of variables to be checked\n";
	  print_usage();
	  exit $ERRORS{"UNKNOWN"};
	}
    }
    # this is a special loop to check stats-variables options such as "connected_clients=WARN,CRIT"
    # which are specified as long options
    my ($vname,$vname2) = (undef,undef);
    foreach (keys(%KNOWN_STATUS_VARS)) {
	$vname = $_;
	$vname2=$o_rprefix.$vname.$o_rsuffix;
	if (exists($KNOWN_STATUS_VARS{$vname}[2])) {
	    if (exists($Options->{$vname})) {
		 verb("Option $vname found with spec parameter: ".$Options->{$vname});
		 thresholds_addvar($vname,parse_thresholds_optionsline($Options->{$vname}));
	    }
	    if (exists($Options->{$vname2})) {
		 verb("Rate option $vname2 found with spec parameter: ".$Options->{$vname2});
		 thresholds_addvar('&'.$vname,parse_thresholds_optionsline($Options->{$vname2}));
	    }
	}
    }
}

# sets thresholds for given list of variables after options have been processed
sub options_setthresholds {
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
                	print "$1 is not a COUNTER variable for which rate of change should be calculated\n";
			print_usage();
                	exit $ERRORS{"UNKNOWN"};
		}
	  }
	  if (!exists($thresholds{$o_varsL[$i]})) {
	      my $warn = parse_threshold($ar_warnLv[$i]);
	      my $crit = parse_threshold($ar_critLv[$i]);
	      if (threshold_specok($warn,$crit)) {
                 print "All numeric warning values must be less then critical (or greater then when '<' is used)\n";
                 print "Note: to override this check prefix warning value with ^\n";
                 print_usage();
                 exit $ERRORS{"UNKNOWN"};
	      }
	      thresholds_addvar($o_varsL[$i], {'WARN'=>$warn,'CRIT'=>$crit} );
	  }
    }
}

# processes previous perf data if present
sub options_processprevperf {
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
}

# this is the main function called closer to end of the code that checks al checks all variables
# (after we assigned values to them) against thresholds that had been processed before
sub main_checkvars {
    # We split into prefix/suffix again but without lowercasing $o_ratelabel first
    ($o_rprefix,$o_rsuffix)=split(/,/,$o_ratelabel) if defined($o_ratelabel) && $o_ratelabel ne '';

    my ($avar,$avar_out,$chk)=(undef,undef,undef);
    # main loop to check for warning & critical thresholds
    for (my $i=0;$i<scalar(@allVars);$i++) {
	$avar=$allVars[$i];
	$avar_out = $avar;
	# this is for output of rate variables which name internally start with &
	if ($avar =~ /^&(.*)/) {
	    $avar_out = $o_rprefix.$1.$o_rsuffix;
	}
	if (defined($dataresults{$avar}[0])) {
	    # main check
	    if ($dataresults{$avar}[0]==0 && exists($thresholds{$avar}{'ZERO'})) {
		$statuscode=$thresholds{$avar}{'ZERO'} if $statuscode ne 'CRITICAL' && $statuscode ne 'OK';
		add_to_statusinfo("$avar is zero") if $statuscode ne 'OK';
	    }
	    else {
		$chk=undef;
		if (exists($thresholds{$avar}{'CRIT'})) {
		    $chk = check_threshold($avar,lc $dataresults{$avar}[0], $thresholds{$avar}{'CRIT'});
		    if ($chk) {
		    	$dataresults{$avar}[1]++;
		    	$statuscode = "CRITICAL";
		    	add_to_statusinfo($chk);
		    }
		}
		if (exists($thresholds{$avar}{'WARN'}) && (!defined($chk) || !$chk)) {
		    $chk = check_threshold($avar,lc $dataresults{$avar}[0], $thresholds{$avar}{'WARN'});
		    if ($chk) {
		    	$dataresults{$avar}[1]++;
		   	 $statuscode="WARNING" if $statuscode eq "OK";
		    	 add_to_statusinfo($chk);
		    }
		}
	    }
	    # if we did not output to status line yet, do so
	    add_to_statusdata($avar,$avar_out." is ".$dataresults{$avar}[0]);

	    # if we were asked to output performance, prepare it but do not output until later loop
	    if (($dataresults{$avar}[2]<0 || 
		 ($dataresults{$avar}[2]==0 &&
		   (!exists($dataresults{$avar}[3]) || $dataresults{$avar}[3] eq '')
		)) &&
		((defined($o_perf) && !exists($thresholds{$avar}{'PERF'})) || 
		 (exists($thresholds{$avar}{'PERF'}) && $thresholds{$avar}{'PERF'} eq 'YES'))) {
		if (!exists($dataresults{$avar}[3]) || $dataresults{$avar}[3] eq '') {
		    $dataresults{$avar}[3]=$avar_out."=".$dataresults{$avar}[0];
		    if (defined($KNOWN_STATUS_VARS{$avar})) {
		    	$dataresults{$avar}[3] .= $KNOWN_STATUS_VARS{$avar}[1];
		    }
		}
		$dataresults{$avar}[2]=0;
		if (exists($thresholds{$avar}{'WARN'}[5]) || exists($thresholds{$avar}{'CRIT'}[5])) {
		    $dataresults{$avar}[3] .= ';' if (exists($thresholds{$avar}{'WARN'}[5]) && $thresholds{$avar}{'WARN'}[5] ne '') || (exists($thresholds{$avar}{'CRIT'}[5]) && $thresholds{$avar}{'CRIT'}[5] ne '');
		    $dataresults{$avar}[3] .= $thresholds{$avar}{'WARN'}[5] if exists($thresholds{$avar}{'WARN'}[5]) && $thresholds{$avar}{'WARN'}[5] ne '';
		    $dataresults{$avar}[3] .= ';'.$thresholds{$avar}{'CRIT'}[5] if exists($thresholds{$avar}{'CRIT'}[5]) && $thresholds{$avar}{'CRIT'}[5] ne '';
		}
	    }
	}
	else {
	    if (exists($thresholds{$avar}{'ABSENT'})) {
		$statuscode=$thresholds{$avar}{'ABSENT'} if $statuscode ne "CRITICAL" && $thresholds{$avar}{'ABSENT'} ne "OK";
	    }
	    else {
		$statuscode="CRITICAL";
	    }
	    add_to_statusinfo("$avar data is missing");
	}
    }
    $statusinfo=trim($statusinfo);
    $statusdata=trim($statusdata);
}

# adds performance variables data to performance data line
sub main_perfvars {
    my $avar;
    for (my $i=0;$i<scalar(@o_perfvarsL);$i++) {
	$avar=$o_perfvarsL[$i];
	if (defined($dataresults{$avar}[0]) &&
	    (!defined($KNOWN_STATUS_VARS{$avar}) || $KNOWN_STATUS_VARS{$avar}[0] =~ /$PERF_OK_STATUS_REGEX/ )) {
		if (defined($dataresults{$avar}[3])) {
		    add_to_perfdata($avar,$dataresults{$avar}[3]);
		}
		else {
		    add_to_perfdata($avar);
		}
	}
    }
    if (defined($o_prevperf)) {
        $perfdata .= " _ptime=".time();
    }
    foreach $avar (keys %dataresults) {
        if (defined($dataresults{$avar}[3])) {
            add_to_perfdata($avar,$dataresults{$avar}[3]);
        }
    }
    $perfdata = trim($perfdata);
}

# Calculate rate variables
sub calculate_ratevars {
    my $avar;
    my $timenow=time();
    my $ptime=undef;
    $ptime=$prev_perf{'_ptime'} if defined($prev_perf{'_ptime'});
    if (defined($o_prevperf) && defined($o_perf)) {
	for (my $i=0;$i<scalar(@allVars);$i++) {
	    if ($allVars[$i] =~ /^&(.*)/) {
		$avar = $1;
		# this forces perfdata output if it was not already
		if (defined($dataresults{$avar}) && $dataresults{$avar}[2]<1 &&
		    (!defined($dataresults{$avar}[3]) || $dataresults{$avar}[3] eq '')) {
		        my $ptemp = $avar."=".$dataresults{$avar}[0];
		    	if (defined($KNOWN_STATUS_VARS{$avar})) {
                	    $ptemp .= $KNOWN_STATUS_VARS{$avar}[1];
		    	}
			$thresholds{$avar}={} if !defined($thresholds{$avar});
			$thresholds{$avar}{'PERF'}='YES';
			preset_perfdata($avar,$ptemp);
		}
		if (defined($prev_perf{$avar}) && defined($ptime)) {
		    $dataresults{$allVars[$i]}=[0,0,0] if !defined($dataresults{$allVars[$i]});
		    $dataresults{$allVars[$i]}[0]= sprintf("%.2f",
		      ($dataresults{$avar}[0]-$prev_perf{$avar})/($timenow-$ptime));
		    verb("Calculating Rate of Change for $avar : ".$allVars[$i]."=".$dataresults{$allVars[$i]}[0]);
		}
	    }
	}
    }
}

sub prepare_dataresults {
    $dataresults{$_} = [undef, 0, 0] foreach(@allVars);
    $dataresults{$_} = [undef, 0, 0] foreach(@o_perfvarsL);
}

############################# END OF THE LIBRARY FUNCTIONS ##################################

# parse command line options
sub check_options {
    Getopt::Long::Configure("bundling");
    my %Options = ();
    GetOptions(\%Options, 
   	'v:s'	=> \$o_verb,		'verbose:s' => \$o_verb, "debug:s" => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'p:i'   => \$o_port,            'port:i'        => \$o_port,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
	's:s'	=> \$o_mdsopt,		'stat:s'	=> \$o_mdsopt,
	'a:s'   => \$o_variables,       'variables:s'   => \$o_variables,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
	'f:s'   => \$o_perf,            'perfparse:s'   => \$o_perf,
	'A:s'   => \$o_perfvars,        'perfvars:s'    => \$o_perfvars,
        'T:s'   => \$o_timecheck,       'response_time:s' => \$o_timecheck,
	'R:s'	=> \$o_hitrate,		'hitrate:s'	=> \$o_hitrate,
	'U:s'	=> \$o_utilsize,	'utilization:s' => \$o_utilsize,
        'P:s'   => \$o_prevperf,        'prev_perfdata:s' => \$o_prevperf,
        'E:s'   => \$o_prevtime,        'prev_checktime:s'=> \$o_prevtime,
	'rate_label:s'	=> \$o_ratelabel,
	map { ($_) } additional_options_list()
    );

    # This gets list of variables into $o_varsL and $o_perfvarsL
    options_startprocessing(\%Options);

    # Standard nagios plugin required options
    if (defined($o_help)) { help(); exit $ERRORS{"UNKNOWN"} };
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"} };

    # access/connection options
    if (!defined($o_host)) { print "Please specify hostname (-H)\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; } 
    @o_mdslist=split(/,/, lc $o_mdsopt) if defined($o_mdsopt) && $o_mdsopt ne '';
    ($o_rprefix,$o_rsuffix)=split(/,/, lc $o_ratelabel) if defined($o_ratelabel) && $o_ratelabel ne '';

    # additional variables/options calculated and added by this plugin
    if (defined($o_timecheck) && $o_timecheck ne '') {
          verb("Processing timecheck thresholds: $o_timecheck");
	  thresholds_addvar('response_time',parse_thresholds_optionsline($o_timecheck));
    }
    if (defined($o_hitrate) && $o_hitrate ne '') {
          verb("Processing hitrate thresholds: $o_hitrate");
	  thresholds_addvar('hitrate',parse_thresholds_optionsline($o_hitrate));
	  $thresholds{'hitrate'}{'ZERO'}="OK" if !exists($thresholds{'hitrate'}{'ZERO'}); # except case of hitrate=0, don't remember why I added it
    }
    if (defined($o_utilsize) && $o_utilsize ne '') {
          verb("Processing memory utilization thresholds: $o_utilsize");
          thresholds_addvar('utilization',parse_thresholds_optionsline($o_utilsize));
    }

    # finish it up
    options_processprevperf();
    options_setthresholds();

    $HOSTNAME = $o_host if defined($o_host);
    $PORT     = $o_port if defined($o_port);
    $TIMEOUT  = $o_timeout if defined($o_timeout);
}

# Get the alarm signal (just in case nagios screws up)
$SIG{'ALRM'} = sub {
     $memd->disconnect_all if defined($memd);
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $ERRORS{"UNKNOWN"};
};

########## MAIN #######

check_options();
verb("check_memcached.pl plugin version ".$Version);
prepare_dataresults();

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
$memd = new Cache::Memcached { 'servers' => [ $dsn ] };

if (!$memd) {
  print "CRITICAL ERROR - Memcache error connecting to '$HOSTNAME' on port $PORT\n"; 
  exit $ERRORS{'CRITICAL'};
}

# This returns hashref of various statistics data on memcached
# Basically results of 'stats', 'stats malloc', 'stats sizes', etc. 
verb("Requesting statistics on: ".join(',',@o_mdslist));
my $stats = $memd->stats(\@o_mdslist);

# some more variables for processing of the results
my $memdversion = "";
my $vstat;
my $vnam;
my $vval;
my $dnam;
my $avar;

# load all data into internal hash array
foreach $vstat (keys %{$stats->{'hosts'}{$dsn}}) {
  verb("Stats Data: vstat=$vstat reftype=".ref($stats->{'hosts'}{$dsn}{$vstat}));
  if (defined($stats->{'hosts'}{$dsn}{$vstat})) {
    if (ref($stats->{'hosts'}{$dsn}{$vstat}) eq 'HASH') {
      foreach $vnam (keys %{$stats->{'hosts'}{$dsn}{$vstat}}) {
        $vval = $stats->{'hosts'}{$dsn}{$vstat}{$vnam};
        if (defined($vval)) {
          verb("Stats Data: $vstat($vnam) = $vval");
          if ($vnam eq 'version') {
               $memdversion = $vval;
          }
          else {
		if ($vstat eq 'misc' || $vstat eq 'malloc') {
			$dnam = $vnam;
		}
		else {
			$dnam = $vstat.'_'.$vnam;
		}
		dataresults_addvar($dnam, $vval);
          }
        }
        else {
          verb("Stats Data: $vstat($vnam) = NULL");
        }
      }
    }
    elsif ($stats->{'hosts'}{$dsn}{$vstat} =~ /ERROR/) {
       verb("Memcached Perl Library ERROR getting stats for $vstat");
    }
    else {
       $vval = $stats->{'hosts'}{$dsn}{$vstat};
       chop($vval);
       my @lines = split("\n",$vval); 
       my $count=0;
       foreach my $ln (@lines) {
	  $count++;
	  if ($ln =~ /STAT\s+(.*)\s+(\d+)/) {
		$vval = $2;
		$dnam = $1;
		$dnam =~ s/\:/_/g;
		$dnam = $vstat.'_'.$dnam if $dnam !~ /^$vstat/;
	  }
	  else {
		$dnam = $vstat."_".$count;
		$vval = $ln;
		$vval =~ s/\s/_/g;
	  } 
          verb("Stats Data: $vstat($dnam) = $vval");
	  dataresults_addvar($dnam, $vval);
       } 
    }
  }
}
$memd->disconnect_all;

# Response Time
if (defined($o_timecheck)) {
    $dataresults{'response_time'}=[0,0,0] if !defined('response_time');
    $dataresults{'response_time'}[0]=Time::HiRes::tv_interval($start_time);;
    add_to_statusdata('response_time',sprintf(" response in %.3fs", $dataresults{'response_time'}[0]));
    if (defined($o_perf)) {
        preset_perfdata('response_time','response_time='.$dataresults{'response_time'}[0].'s');
    }
}

# calculate rate variables
calculate_ratevars();

# Memory Use Utilization
if (defined($o_utilsize) && defined($dataresults{'bytes'}) && defined($dataresults{'limit_maxbytes'})) {
    $dataresults{'utilization'}=[0,0,0];
    if (!defined($dataresults{'limit_maxbytes'}[0]) || $dataresults{'limit_maxbytes'}[0]==0) {
	$dataresults{'utilization'}[0]=0;
    }
    else {
	$dataresults{'utilization'}[0]=$dataresults{'bytes'}[0]/$dataresults{'limit_maxbytes'}[0]*100;
    }
    add_to_statusdata('utilization',sprintf(" in use %.2f%% of space", $dataresults{'utilization'}[0]));
    if (defined($o_perf)) {
	preset_perfdata('utilization',sprintf(" utilization=%.5f%%", $dataresults{'utilization'}[0]));
   }
}

# CPU Use - Converts floating seconds to integer ms
if (defined($dataresults{'rusage_user'})) {
   $dataresults{'rusage_user_ms'}=[int($dataresults{'rusage_user'}*100+0.5),0,0];
}
if (defined($dataresults{'rusage_system'})) {
   $dataresults{'rusage_system_ms'}=[int($dataresults{'rusage_system'}*100+0.5),0,0];
}

# Hitrate
my $hits_total=0;
my $hits_hits=undef;
my $hitrate_all=0;
if (defined($o_hitrate) && defined($dataresults{'get_misses'}) && defined($dataresults{'get_hits'})) {
    for $avar ('get_misses', 'get_hits') {
        if (defined($o_prevperf) && defined($o_perf)) {
		preset_perfdata($avar,$avar."=".$dataresults{$avar}[0].'c');
	}
	$hits_hits = $dataresults{'get_hits'}[0] if $avar eq 'get_hits';
	$hits_total += $dataresults{$avar}[0];
    }
    verb("Calculating Hitrate : total=".$hits_total." hits=".$hits_hits);
    if (defined($hits_hits) && defined($prev_perf{'get_hits'}) && defined($prev_perf{'get_misses'}) && $hits_hits > $prev_perf{'get_hits'}) {
	$hitrate_all = $hits_hits/$hits_total*100 if $hits_total!=0;
	$hits_hits -= $prev_perf{'get_hits'};
	$hits_total -= $prev_perf{'get_misses'};
	$hits_total -= $prev_perf{'get_hits'};
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
	my $sdata .= sprintf(" hitrate is %.2f%%", $dataresults{'hitrate'}[0]);
	$sdata .= sprintf(" (%.2f%% from launch)", $hitrate_all) if ($hitrate_all!=0);
	add_to_statusdata('hitrate',$sdata);
	if (defined($o_perf)) {
		preset_perfdata('hitrate',sprintf("hitrate=%.4f%%", $dataresults{'hitrate'}[0]));
	}
     }
}

# Check thresholds in all variables and prepare status and performance data for output
main_checkvars();
main_perfvars();

# now output the results
print $statuscode . ': '.$statusinfo;
print " - " if $statusinfo;
# print "MEMCACHED " . $memdversion . ' on ' . $HOSTNAME. ':'. $PORT ' is '. $statuscode . $statusinfo;
print "MEMCACHED " . $memdversion . ' on ' . $HOSTNAME. ':'. $PORT;
print ', up '.uptime_info($dataresults{'uptime'}[0]) if defined($dataresults{'uptime'}); 
print " - " . $statusdata if $statusdata;
print " | " . $perfdata if $perfdata;
print "\n";

# end exit
exit $ERRORS{$statuscode};
