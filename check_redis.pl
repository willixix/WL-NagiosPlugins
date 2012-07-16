#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_redis.pl
# Version : 0.6
# Date    : July 16, 2012
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
# This is Redis Server Check plugin. It gets stats variables and allows to set
# thresholds on their value or their rate of change. It can measure response time,
# hitrate, memory utilization, check replication sync and more. It can also test
# data in a specified key (if necessary doing average or sum on range).
#
# Plugin returns stats variables as perfomance data for further nagios 2.0
# post-processing, you can find graph templates for PNP4Nagios at:
#   http://william.leibzon.org/nagios/
#
# This program is written and maintained by:
#   William Leibzon - william(at)leibzon.org
#
# ============================= SETUP NOTES ====================================
#
# Make sure to install Redis perl library from CPAN first.
#
# Next for help and to see what parameters this plugin accepts do:
#  ./check_redis.pl --help
#
# This plugin checks Redis NoSQL database status varialbes, measures its response
# time and if specified allows to set thresholds on one or more key data. You can
# set thresholds for data in stats varialbles and some of them are also conviently
# available as long options with special threshold syntax. Plugin also calculates
# statistics such as Hitrate (calculated as rate of change of hits/misses) and
# memory use and can check replication delay.
#
# All variables can be returned as performance data for graphing and pnp4nagios
# template should be available with this plugin on the site you downloaded it from.

# 1. Connection Parameters
#
#   The connection parameters are "-H hostname", "-p port", "-D database" and
#   "-C password_file" or "-x password". Specifying hostname is required, if you
#   run locally specify it as -H 127.0.0.1. Everything else is optional and rarely
#   needed. Default port is 6337. Database name (usually a numeric id) is probably
#   only needed if you use --query option. Password can be passed on a command
#   line with -x but its safer to read read it from a file or change in the code
#   itself if you do use authentication.
#
# 2. Response Time, HitRate, Memory Utilization, Replication Delay
#
#   To get response time you use "-T" or "--response_time=" option. By itself
#   it will cause output of respose time at the status line. You can also use
#   it as "-T warn,crit" to specify warning and critical thresholds.
#
#   To get hitrate the option is "-R" or "--hitrate=". If previous performance
#   data is not feed to plugin (-P option, see below) the plugin calculates
#   it as total hitrate over life of redis process. If -P is specified and
#   previous performance data is feed back, the data is based on real hitrate
#   (which can show spikes and downs) with lifelong info also given in paramphesis
#   The data is based on keyspace_hits and keyspace_misses stats variables.
#   As with -T you can specify -R by itself or with thresholds as -R warn,crit
# 
#   Memory utilization is percent of real memory used by Redis out of total
#   memory on the system. To be able to calculate it plugin needs to known
#   amount of memory your system has which you specify with "-M" or "--memory="
#   option. Memory utilization option itself is lower "-m" or "--memory_utilization="
#   and you can specify threshold for it as "-m warn,crit"
#
#   Replication delay threshold option "-R" or "--replication_delay=" is used
#   to check replication with data from "master_last_io_seconds_ago" stats and
#   valid only on slave servers. Other variables maybe checked for this later
#   with more complex funcationality, so it was chosen to do this as separate
#   option rather than drecting people to check that variable.
#
# 3. Checks on Redis Status Variables
#
#   All status variables from redis can be checked with the plugin. For some
#   status variables separate long option is provided to specify threshold.
#       i.e. --connected_clients=<thresholds>
#
#   This is a new alternative to specifying all variables together with -a
#   (--variables) option. For example:
#       -a connected_clients,blocked_clients
#   When you do above results are included in status output line and you
#   are required to specify thresholds with -w or --warn and -c or --crit
#   with exactly number of thresholds as a number of variables specified
#   in -a. If you simply want variable values on status line without specifying
#   any threshold, use ~ in place of threshold value or skip value but specify
#   all apropriate commas. For example:
#           -a connected_clients,blocked_clients -w ~,~ -c ~,~
#      OR   -a connected_clients,blocked_clients -w , -c ,
#
#   If you use new syntax with a long option for specific stats variables, you
#   can specify list of one or more trhreshold specifiers which can be any of:
#      WARN:threshold
#      CRIT:threshold
#      ABSENT:OK|WARNING|CRITICAL|UNKNOWN  - what to do if data is not available
#      ZERO:OK|WARNING|CRIICAL|UNKNOWN	   - what do do if data is 0 (rarely needed)
#      DISPLAY:YES|NO			   - display on status line or not (default YES)
#      PERF:YES|NO	 		   - output in perf data or not
#					     (default YES if -f option is used, otherwise NO)
#   These can be specified in any order separated by ",". For example:
#      --connected_clients=CRIT:>100,WARN:>50,ABSENT:CRITICAL,ZERO:OK,DISPLAY:YES,PERF:YES
#
# 4. Calculating and using Rate of Change for Variables
#
#   If you want to check rate of change rather than actual value you can do this
#   by specifying it as '&variable' such as "&total_connections_received" or
#   as "variable_rate" which is "total_connections_received_rate" and is similar
#   to 'connected_clients' variable. By default it would be reported in the output
#   as 'variable_rate' though '&variable' is a format used internally by plugin.
#
#   As an alternative you can specify how to label these with --rate_label
#   option where you can specify prefix and/or suffix. For example '--rate_label=dt_'
#   would have the output being "dt_total_connections_received' where as
#   '--rate_label=,_rate' is plugin default giving 'total_connections_received_rate'. 
#   You can use these names with -a and -A such as:
#       --rate_label=,_rate -a total_connections_received_rate -w 1000 -c ~
#   Note that --rate_label will not work with new variable-named options, the
#   only way to change default if you use that is to modify code and change
#   $o_rprefix and $o_rsuffix variables default values.
#
#   Now in order to be able to calculate rate of change, the plugin needs to
#   know values of the variables from when it was run the last time. This
#   is done by feeding it previous performance data with a -P option.
#   In commands.cfg this would be specified as:
#     -P "$SERVICEPERFDATA$"
#   And don't forget the quotes, in this case they are not just for documentation.
# 
# 5. Threshold Specification
#
#   The plugin fully supports Nagios plug-in specification for specifying thresholds:
#     http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT
#
#   And it supports an easier format with the following one-letter prefix modifiers:
#     >value : issue alert if data is above this value (default for numeric value)
#     <value : issue alert if data is below this value (must be followed by number)
#     =value : issue alert if data is equal to this value (default for non-numeric)
#     !value : issue alert if data is NOT equal to this value
#   (because > and < are interpreted by shell you may need to specify this in quotes)
#   There are also two specifications of range formats as with other nagios plugins:
#     number1:number2   issue alert if data is OUTSIDE of range [number1..number2]
#	                i.e. alert if data<$number1 or data>$number2
#     @number1:number2  issue alert if data is WITHIN range [number1..number2] 
#		        i.e. alert if data>=$number and $data<=$number2
#
#   The plugin will attempt to check that WARNING value is less than CRITICAL
#   (or greater for <). A special prefix modifier '^' can be used to disable these
#   checks. A quick example of such special use is '--warn=^<100 --crit=>200' which
#   means warning alert if value is < 100 and critical alert if its greater than 200.
#
# 6. Performance Data
#
#   Using '-f' option causes values of all variables you specified in -a as
#   well as response time from -T (response time), from -R (hitrate), from -m
#   and other checks to go out as performance data for Nagios graphing programs.
#
#   You may also directly specify which variables are to be return as performance data
#   with '-A' option. If you use '-A' by itself and not specify any variables or use
#   special special value of '*' (as in '-A *') the plugin will output all variables
#   which is very useful for finding what data you can chck with this plugin.
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
# 7. Query Option and setting thresholds for data in Redis Database
#
#   With -q (--query) option the plugin can retrieve data from Redis database
#   which become new variables you can then check thresholds on. Currently it
#   supports getting single key values with GET and getting range or values (or
#   everything in list) with LRANGE and finding their Average or Min or Max or Sum.
#   The option maybe repeated more than once. The format for this option is:
#
#      -q, --query=query_type,key[:varname]<,list of threshold specifiers>
#
#  query_type is one of:
#	GET - get one value
#	LRANGE:AVG:start:end - retrieve list and average results
#	LRANGE:SUM:start:end - retrieve list and sum results
#	LRANGE:MIN:start:end - retrieve list and return minimum
#	LRANGE:MAX:start:end - retrieve list and return maximum
#   For LRANGE if you do not specify start and end, then start will be  0 and end
#   is last value in the list pointed to by this key (found by using llen).
#
#   Key is the Redis key name to be retrieved and optionally you can add ":varname"
#   after it which spcecifies what to name plugin variable based on this data -
#   based on what you specify here is how it will be displayed in the status
#   line and perormance data, default is same as Redis key name.
#
#   After these key name you specify list of thresholds in the same format as
#   variable-based long options described in section 3. Again the list of the
#   possible specifiers are:
#      WARN:threshold
#      CRIT:threshold
#      ABSENT:OK|WARNING|CRITICAL|UNKNOWN  - what to do if data is not available
#      ZERO:OK|WARNING|CRIICAL|UNKNOWN	   - what do do if data is 0 (rarely needed)
#      DISPLAY:YES|NO			   - display on status line or not (default YES)
#      PERF:YES|NO	 		   - output in perf data or not
#
#   You can also optionally use -a, -w and -c to theck data from the query instead
#   of specifying thresholds as part of query option itself And remember that you if
#   you need to check multiple keys you just repeat --query option more than once.
#
# 8. Example of Nagios Config Definitions
#
# Sample command and service definitions are below:
#
# define command {
#    command_name        check_redis_new
#    command_line        $USER1$/check_redis.pl -H $HOSTADDRESS$ -p $ARG1$ -T $ARG2$ -R -A -M $_HOSTSYSTEM_MEMORY$ -m $ARG3$ -a $ARG4$ -w $ARG5$ -c $ARG6$ -f -P "$SERVICEPERFDATA$"
# }
#
# Arguments and thresholds are:
#  $ARG1 : Port
#  $ARG2 : response time thresholds
#  $ARG3 : memory utilization thresholds
#  $ARG4 : additional variables to be checked
#  $ARG5 : warning thresholds for those variables
#  $ARG6 : critical thresholds for those variables
#
# define service {
#        use                     prod-service
#        hostgroups              redishosts
#        service_description     Redis
#        check_command           check_redis_new!6379!"1,2"!"80,90"!blocked_clients,connected_clients!50,~!100,~
# }
#
# define host {
#         use             prod-server
#         host_name       redis.mynetwork
#         address         redis.mynetwork
#         alias           Redis Stat Server
#         hostgroups      linux,redishosts
#        _SYSTEM_MEMORY  '8G'
# }
#
# Example of command-line use:
#   /usr/lib/nagios/plugins/check_redis.pl -H localhost -a 'connected_clients,blocked_clients' -w ~,~ -c ~,~ -m -M 4G -A -R -T -f -v
#
# In above the -v option means "verbose" and with it plugin will output some debugging information
# about what it is doing. The option is not intended to be used when plugin is called from nagios itself. 
#
# Example of using query and varialbe-based long options with debug enabled as well (-v):
#
# ./check_redis.pl -H localhost -p 6379 -D 1 --query LRANGE:AVG:0:,MyColumn1:Q1,ABSENT:WARNING,WARN:300,CRIT:500,DISPLAY:YES,PERF:NO
#   --query GET,MyKey:K1,ABSENT:CRITICAL "--connected_clients=WARN:<2,CRIT:>100,ZERO:OK,ABSENT:WARNING,DISPLAY:YES,PERF:YES"
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
#  [0.42 - Apr 28, 2012] Added total_keys, total_expires, nice uptime_info 
#			 and memory utilization
#  [0.43 - May 31, 2012] Release candidate. More documentation added 
#			 replacing check_memcached examples. Bugs fixed.
#			 Made "_rate" as default rate variables suffix in
#		         place of &delta. Changed -D option to -r.
#
#  [0.5  - Jun 01, 2012] First official release will start with version 0.5
#			 Documentation changes, but no code updates.
#  [0.51 - Jun 16, 2012] Added support to specify filename to '-v' option
#			 for debug output and '--debug' as alias to '--verbose'
#  [0.52 - Jul 10, 2012] Patch by Jon Schulz to support credentials with -C
#			 (credentials file) and addition by me to support
#			 password as command argument.
#  [0.53 - Jul 15, 2012] Adding special option to do query on one redis key and
#                        and do threshold checking of results if its numeric
#
#  [0.6  - Jul 16, 2012] Rewrote parts of thresholds checking code and moved code
#			 that checks and parses thresholds from main into separate
#			 functions that are to become part of plugin library.
#			 Added support for variable thresholds specified as:
#			   option=WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL,ZERO:..
#			 which are to be used for stats-variable based long options such as
#			   --connected_clients=WARN:threshold,CRIT:threshold
#			 and added DISPLAY:YES|NO and PERF specifiers for above too.
#			 Added -D option to specify database needed for --query
#
# TODO or consider for future:
#
#  0. Add '--extra-opts' to allow to read options from a file as specified
#     at http://nagiosplugins.org/extra-opts. This is TODO for all my plugins
#
#  1. [DONE] In plans are to allow long options to specify thresholds for known variables.
#     These would mean you specify '--connected_clients' in similar way to '--hitrate'
#     Internally these would be convered into -A, -w, -c as appropriate an used
#     together with these options. So in practice it will now allow to get any data
#     just a different way to specify options for this plugin. 
# 
#  2. REDIS Specific:
#     - Add option to check from master that slave is connected and working.
#     - Look into replication delay from master and how it can be done. Look
#       for into on replication_delay from slave as well
#     - How to better calculate memory utilization and get max memory available
#       without directly specifying it
#     - Maybe special options to measure cpu use and set thresholds
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
use Getopt::Long qw(:config no_ignore_case);
use Redis;

# default hostname, port, database, user and password, see NOTES above
my $HOSTNAME= 'localhost';
my $PORT=     6379;
my $PASSWORD= undef;
my $DATABASE= undef;

# Add path to additional libraries if necessary
use lib '/usr/lib/nagios/plugins';
our $TIMEOUT;
our %ERRORS;
eval 'use utils qw(%ERRORS $TIMEOUT)';
if ($@) {
 $TIMEOUT = 20;
 %ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
}

my $Version='0.6';

# This is a list of known stat and info variables including variables added by plugin,
# used in order to designate COUNTER variables with 'c' in perfout for graphing programs
# The format is:
#        VAR_NAME => [ TYPE, PerfSuffix, DESCRIPTION] 
# If option has description, the variable will also become available as a long option so for example
# you can specify "--connected_clients=WARN,CRIT" instead of specifying "-a connected_clients -w WARN -c CRIT'
my %KNOWN_STATUS_VARS = ( 
	 'memory_utilization' => [ 'GAUGE', '%' ],      				# calculated by plugin
	 'redis_version' => [ 'VERSION', '' ],						# version string variable
	 'response_time' => [ 'GAUGE', 's' ],						# measured by plugin
	 'total_keys' => [ 'GAUGE', '', 'Total Number of Keys on the Server' ],
	 'total_expires' => ['GAUGE', '', 'Number of Expired Keys for All DBs' ],
	 'last_save_time' => [ 'GAUGE', 's' ],
	 'bgsave_in_progress' => [ 'BOOLEAN', '' ],
	 'vm_enabled' => [ 'BOOLEAN', '' ],
	 'uptime_in_seconds' => [ 'COUNTER', 'c' ],
	 'total_connections_received' => [ 'COUNTER', 'c', 'Total Connections Received' ],
	 'used_memory_rss' => [ 'GAUGE', 'B', 'Resident Set Size, Used Memory in Bytes' ],  # RSS - Resident Set Size
	 'used_cpu_sys' => [ 'GAUGE', '', 'Main Process Used System CPU' ],
	 'redis_git_dirty' => [ 'BOOLEAN', '', 'Git Dirty Set Bit' ],
	 'loading' => [ 'BOOLEAN', '' ],
	 'latest_fork_usec' => [ 'GAUGE', '' ],
	 'connected_clients' => [ 'GAUGE', '', 'Total Number of Connected Clients' ],
	 'used_memory_peak_human' => [ 'GAUGE', '' ],
	 'mem_allocator' => [ 'TEXTINFO', '' ],
	 'uptime_in_days' => [ 'COUNTER', 'c', 'Total Uptime in Days' ],
	 'keyspace_hits' => [ 'COUNTER', 'c', 'Total Keyspace Hits' ],
	 'client_biggest_input_buf' => [ 'GAUGE', '' ],
	 'gcc_version' => [ 'TEXTINFO', '' ],
	 'changes_since_last_save' => [ 'COUNTER', 'c' ],
	 'arch_bits' => [ 'GAUGE', '' ],
	 'lru_clock' => [ 'GAUGE', '' ], 	# LRU is page replacement algorithm (least recently used), I'm unsure what this represents though
	 'role' => [ 'SETTING', '' ],
	 'multiplexing_api' => [ 'SETTING' , '' ],
	 'slave' => [ 'TEXTDATA', '' ],
	 'pubsub_channels' => [ 'GAUGE', '', 'Number of Pubsub Channels' ],
	 'redis_git_sha1' => [ 'TEXTDATA', '' ],
	 'used_cpu_user_children' => [ 'GAUGE', '', 'Child Processes Used User CPU' ],
	 'process_id' => [ 'GAUGE', '' ],
	 'used_memory_human' => [ 'GAUGE', '' ],
	 'keyspace_misses' => [ 'COUNTER', 'c', 'Keyspace Misses' ],
	 'used_cpu_user' => [ 'GAUGE', '', 'Main Process Used User CPU' ],
	 'total_commands_processed' => [ 'COUNTER', '', 'Total Number of Commands Processed from Start' ],
	 'mem_fragmentation_ratio' => [ 'GAUGE', '', 'Memory Fragmentation Ratio' ],
	 'client_longest_output_list' => [ 'GAUGE', '' ],
	 'blocked_clients' => [ 'GAUGE', '', 'Number of Currently Blocked Clients' ],
	 'aof_enabled' => [ 'BOOLEAN', '' ],
	 'evicted_keys' => [ 'COUNTER', 'c', 'Total Number of Evicted Keys' ],
	 'bgrewriteaof_in_progress' => [ 'BOOLEAN', '' ],
	 'expired_keys' => [ 'COUNTER', 'c', 'Total Number of Expired Keys' ],
	 'used_memory_peak' => [ 'GAUGE', 'B' ],
	 'connected_slaves' => [ 'GAUGE', '', 'Number of Connected Slaves' ],
	 'used_cpu_sys_children' => [ 'GAUGE', '', 'Child Processed Used System CPU' ],
	 'master_host' => [ 'TEXTINFO', '' ],
	 'slave0' => [ 'TEXTINFO', '' ],
	 'slave1' => [ 'TEXTINFO', '' ],
	 'slave2' => [ 'TEXTINFO', '' ],
	 'slave3' => [ 'TEXTINFO', '' ],
	);

# Here you can also specify which variables should go into perf data, 
# For right now it is 'GAUGE', 'COUNTER', 'DATA' (but not 'TEXTDATA'), and 'BOOLEAN'
# you may want to remove BOOLEAN if you don't want too much data
my $PERF_OK_STATUS_REGEX = 'GAUGE|COUNTER|^DATA$|BOOLEAN';

# ============= MAIN PROGRAM CODE - DO NOT MODIFY BELOW THIS LINE ==============

my $o_host=     undef;		# hostname
my $o_port=     undef;		# port
my $o_pwfile=   undef;          # password file
my $o_password= undef;		# password as parameter
my $o_database= undef;		# database name (usually a number)
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
my $o_timeout=  undef;          # Timeout to use - note that normally timeout is from nagios
my $o_timecheck=undef;          # threshold spec for connection time
my $o_memutilization=undef;     # threshold spec for memory utilization%
my $o_totalmemory=undef;	# total memory on a system
my $o_hitrate=  undef;          # threshold spec for hitrate%
my $o_repdelay=undef;           # replication delay time
my @o_querykey=();		# query this key, this option maybe repeated so its an array

# previous performance data and ratio calculation related options
my $o_prevperf= undef;		# performance data given with $SERVICEPERFDATA$ macro
my $o_prevtime= undef;		# previous time plugin was run $LASTSERVICECHECK$ macro
my $o_ratelabel=undef;		# prefix and suffix for creating rate variables
my $o_rsuffix='_rate';		# default suffix	
my $o_rprefix='';

## Additional global variables
my @allVars = ();		# all variables after options processing
my @ar_warnLv = ();		# used in options processing
my @ar_critLv = ();		# used in options processing
my @query=();			# array of queries with each entry being keyed hash of processedoption data on howto query
my %thresholds=();		# this replaces @o_warnL and @o_critL with a hash array of all threshold data
my $redis= undef;               # DB connection object
my %prev_perf=  ();		# array that is populated with previous performance data
my @prev_time=  ();     	# timestamps if more then one set of previois performance data
my $perfcheck_time=undef;	# time when data was last checked 
my %dataresults= ();		# this is where data is loaded into
my $statuscode = "OK";		# final status code
my $statusinfo = "";		# if there is an error, this has human info about what it is
my $statusdata = "";		# if there is no error but we want some data in status line, this var gets it
my $perfdata = "";		# this variable collects performance data line

sub p_version { print "check_redis.pl version : $Version\n"; }

sub print_usage_line {
   print "Usage: $0 [-v [debugfilename]] -H <host> [-p <port>] [-x password | -C credentials_file] [-D <database>] [-a <statistics variables> -w <variables warning thresholds> -c <variables critical thresholds>] [-A <performance output variables>] [-T [conntime_warn,conntime_crit]] [-R [hitrate_warn,hitrate_crit]] [-m [mem_utilization_warn,mem_utilization_crit] [-M <maxmemory>[B|K|M|G]]] [-r replication_delay_time_warn,replication_delay_time_crit]  [-f] [-T <timeout>] [-V] [-P <previous performance data in quoted string>] [-q (GET|LRANGE:(AVG|SUM|MIN|MAX):start:end),query_type,query_key_name[:data_name][,ABSENT:WARNING|CRITICAL][,WARN:threshold,CRIT:threshold]] \n";
}

sub print_usage {
   print_usage_line();
   print "For more details on options do: $0 --help\n";
}

sub help {
   print "Redis Check for Nagios version ",$Version,"\n";
   print " by William Leibzon - william(at)leibzon.org\n\n";
   print "This is redis monitoring plugin to check its stats variables, replication, response time\n";
   print "hitrate, memory utilization and other info. The plugin can also query and test key data\n";
   print "against specified thresholds. All data is available as performance output for graphing.\n\n";
   print_usage_line();
   print "\n";
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
 -D, --database=NAME
   optional database name (usually a number), needed for --query but otherwise not needed
 -x, --password=STRING
    Password for Redis authentication. Safer alternative is to put them in a file and use -C
 -C, --credentials=FILENAME
    Credentials file to read for Redis authentication
 -t, --timeout=NUMBER
   Allows to set timeout for execution of this plugin. This overrides nagios default.
 -V, --version
   Prints version number

Variables and Thresholds Set as List:
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
   if not specified is suffix '_rate' i.e. --rate_label=,_rate

Key Data Query Option (maybe repeated more than once):
 -q, --query=query_type,key[:varname][,ABSENT:OK|WARNING|CRITICAL,WARN:threshold,CRIT:threshold]
   query_type is one of:
	GET - get one value
	LRANGE:AVG:start:end - retrieve list and average results
	LRANGE:SUM:start:end - retrieve list and sum results
	LRANGE:MIN:start:end - retrieve list and return minimum
	LRANGE:MAX:start:end - retrieve list and return maximum
   Option specifies key to query and optional variable name to assign the results to after :
   (if not specified it would be same as key). If key is not available the plugin can issue
   either warning or critical alert depending on what you specified after ABSENT.
   Numeric results are calculated for ranges and can be checked with specified thresholds
   or you can do it together with standard with redis stats variables and -a option.

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
 -m, --memory_utilization=[WARN,CRIT]
   This calculates percent of total memory on system used by redis, which is
      utilization=redis_memory_rss/total_memory*100.
   Total_memory on server must be specified with -M since Redis does not report
   it and can use maximum memory unless you enabled virtual memory and set a limit
   (I plan to test this case and see if it gets reported then).
   If you specify -m by itself, the plugin will just output this info,
   with '-f' it will also include this in performance data. You can also specify
   parameter values which are interpreted as WARNING and CRITICAL thresholds.
 -M, --memory=NUM[B|K|M|G]
   Amount of memory on a system for memory utilization calculations above.
   If it does not end with K,M,G then its assumed to be B (bytes)
 -r, --replication_delay=WARN,CRIT
   Allows to set threshold on replication delay info. Only valid if this is a slave!
   The threshold value is in seconds and fractions are acceptable.

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

sub div_mod { return int( $_[0]/$_[1]) , ($_[0] % $_[1]); }

# this converts uptime in seconds to nice & short output format
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

############################ START OF THE LIBRARY FUNCTIONS #################################

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
    # which are specifies as long options
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
		$statusinfo .= " $avar is zero" if $statuscode ne 'OK';
	    }
	    else {
		$chk=undef;
		if (exists($thresholds{$avar}{'CRIT'})) {
		    $chk = check_threshold($avar,lc $dataresults{$avar}[0], $thresholds{$avar}{'CRIT'});
		    if ($chk) {
		    	$dataresults{$avar}[1]++;
		    	$statuscode = "CRITICAL";
		    	$statusinfo .= $chk;
		    }
		}
		if (exists($thresholds{$avar}{'WARN'}) && (!defined($chk) || !$chk)) {
		    $chk = check_threshold($avar,lc $dataresults{$avar}[0], $thresholds{$avar}{'WARN'});
		    if ($chk) {
		    	$dataresults{$avar}[1]++;
		   	 $statuscode="WARNING" if $statuscode eq "OK";
		    	$statusinfo .= $chk;
		    }
		}
	    }
	    # if we did not output to status line yet, do so
	    if ($dataresults{$avar}[1]==0) {
		$dataresults{$avar}[1]++;
		if (!exists($thresholds{$avar}{'DISPLAY'}) || $thresholds{$avar}{'DISPLAY'} eq 'YES') {
		    $statusdata .= ", " if $statusdata;
		    $statusdata .= $avar_out . " is " . $dataresults{$avar}[0];
		}
	    }
	    # if we were asked to output performance, prepare it but do not output until later loop
	    if ($dataresults{$avar}[2]==0 && exists($dataresults{$avar}[3]) && $dataresults{$avar}[3] eq '' && 
		((defined($o_perf) && !exists($thresholds{$avar}{'PERF'})) || 
		 (exists($thresholds{$avar}{'PERF'}) && $thresholds{$avar}{'PERF'} eq 'YES'))) {
		$dataresults{$avar}[3]=$avar_out."=".$dataresults{$avar}[0];
		if (defined($KNOWN_STATUS_VARS{$avar})) {
		    $dataresults{$avar}[3] .= $KNOWN_STATUS_VARS{$avar}[1];
		}
		if (exists($thresholds{$avar}{'WARN'}[5]) || exists($thresholds{$avar}{'CRIT'}[5])) {
		    $dataresults{$avar}[3] .= ';' if (exists($thresholds{$avar}{'WARN'}[5]) && $thresholds{$avar}{'WARN'}[5] ne '') ||
					     (exists($thresholds{$avar}{'CRIT'}[5]) && $thresholds{$avar}{'CRIT'}[5] ne '');
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
	    $statusinfo .= ", " if $statusinfo;
	    $statusinfo .= "$avar data is missing";
	}
    }
}

# adds performance variables data to performance data line
sub main_perfvars {
    my $avar;
    for (my $i=0;$i<scalar(@o_perfvarsL);$i++) {
	$avar=$o_perfvarsL[$i];
	if (defined($dataresults{$avar}[0]) && $dataresults{$avar}[2]==0 &&
	    (!defined($KNOWN_STATUS_VARS{$avar}) || $KNOWN_STATUS_VARS{$avar}[0] =~ /$PERF_OK_STATUS_REGEX/ )) {
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
	$perfdata .= " _ptime=".time();
    }
    foreach $avar (keys %dataresults) {
	if (defined($dataresults{$avar}[3]) && $dataresults{$avar}[2]==0) {
	    $perfdata .= " " . $dataresults{$avar}[3];
	    $dataresults{$avar}[2]++;
	}
    }
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
		if (defined($dataresults{$avar}) && $dataresults{$avar}[2]==0) {
		    $dataresults{$avar}[3]= $avar."=".$dataresults{$avar}[0];
		    if (defined($KNOWN_STATUS_VARS{$avar})) {
                	$dataresults{$avar}[3].= $KNOWN_STATUS_VARS{$avar}[1];
		    }
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

# process --query options (which maybe repeated, that's why loop)
sub option_query {
   for(my $i=0;$i<scalar(@o_querykey);$i++) {
	  verb("Processing query key option: $o_querykey[$i]");
	  my @ar=split(/,/, $o_querykey[$i]);
	  # how to query
	  my @key_querytype = split(':', uc shift @ar);
	  verb("- processing query type specification: ".join(':',@key_querytype));
	  if ($key_querytype[0] eq 'GET') {}
	  elsif ($key_querytype[0] eq 'LRANGE') {
		if (scalar(@key_querytype)<2 || scalar(@key_querytype)>4) {
                	print "Incorrect specification of LRANGE. Must include type and start and end range.\n";
			print_usage();
			exit $ERRORS{"UNKNOWN"};
		}
		elsif ($key_querytype[1] ne 'MAX' && $key_querytype[1] ne 'MIN' &&
		    $key_querytype[1] ne 'AVG' && $key_querytype[1] ne 'SUM') {
			print "Invalid LRANGE type $key_querytype[1]. This must be either MAX or MIN or AVG or SUM\n";
			print_usage();
			exit $ERRORS{"UNKNOWN"};
		}
	  }
	  else {
		print "Invalid key query $key_querytype[0]. Currently supported are GET and LRANGE.\n";
		print_usage();
		exit $ERRORS{"UNKNOWN"};
	  }
	  # key to query and how to name it
          my ($key_query,$key_name) = split(':', shift @ar);
	  $key_name = $key_query if !defined($key_name) || ! $key_name;
	  verb("- variable $key_name will receive data from $key_query");
	  # parse thresholds and finish processing assigning values to arrays
	  my $th = parse_thresholds_optionsline(join(',',@ar));
	  $query[$i] = { 'key_query' => $key_query, 'key_name' => $key_name, 'query_type' => $key_querytype[0] };
	  $query[$i]{'query_subtype'} = $key_querytype[1] if defined($key_querytype[1]);
          $query[$i]{'query_range_start'} = $key_querytype[2] if defined($key_querytype[2]);
	  $query[$i]{'query_range_end'} = $key_querytype[3] if defined($key_querytype[3]);
	  if (exists($th->{'ABSENT'})) {
	      verb("- ".$th->{'ABSENT'}." alert will be issued if $key_query is not present");
	      $query[$i]{'alert'} = $th->{'ABSENT'};
	  }
	  if (exists($th->{'WARN'})) {
	      verb("- warning threshold ".$th->{'WARN'}." set");
	      $query[$i]{'warn'} = $th->{'WARN'};
	  }
	  if (exists($th->{'CRIT'})) {
	      verb("- critical threshold ".$th->{'CRIT'}." set");
	      $query[$i]{'crit'} = $th->{'CRIT'};
	  }
	  thresholds_addvar($key_name,$th);
     }
}

# sets password, host, port and other data based on options entered
sub options_setaccess {
    if (!defined($o_host)) { print "Please specify hostname (-H)\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; } 
    if (defined($o_pwfile) && $o_pwfile) {
        if ($o_password) {
	    print "use either -x or -C to enter credentials\n"; print_usage(); exit $ERRORS{"UNKNOWN"};
	}
        open my $file, '<', $o_pwfile or die $!;
        while (<$file>) {
            # Match first non-blank line that doesn't start with a comment
            if (!($_ =~ /^\s*#/) && $_ =~ /\S+/) {
                chomp($PASSWORD = $_);
                last;
            }
        }
        close $file;
        print 'Password file is empty' and exit $ERRORS{"UNKNOWN"} if !$PASSWORD;
    }
    if (defined($o_password) && $o_password) {
	$PASSWORD = $o_password;
    }
    $HOSTNAME = $o_host if defined($o_host);
    $PORT     = $o_port if defined($o_port);
    $TIMEOUT  = $o_timeout if defined($o_timeout);
    $DATABASE = $o_database if defined($o_database);
}

# parse command line options
sub check_options {
    Getopt::Long::Configure("bundling");
    my %Options = ();
    GetOptions(\%Options, 
   	'v:s'	=> \$o_verb,		'verbose:s' => \$o_verb, "debug:s" => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'p:i'   => \$o_port,            'port:i'        => \$o_port,
        'C:s'   => \$o_pwfile,          'credentials:s' => \$o_pwfile,
        'x:s'   => \$o_password,	'password:s'	=> \$o_password,
	'D:s'	=> \$o_database,	'database:s'	=> \$o_database,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
	'a:s'   => \$o_variables,       'variables:s'   => \$o_variables,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
	'f:s'   => \$o_perf,            'perfparse:s'   => \$o_perf,
	'A:s'   => \$o_perfvars,        'perfvars:s'    => \$o_perfvars,
        'T:s'   => \$o_timecheck,       'response_time:s' => \$o_timecheck,
        'R:s'   => \$o_hitrate,         'hitrate:s'     => \$o_hitrate,
        'r:s'   => \$o_repdelay,        'replication_delay:s' => \$o_repdelay,
        'P:s'   => \$o_prevperf,        'prev_perfdata:s' => \$o_prevperf,
        'E:s'   => \$o_prevtime,        'prev_checktime:s'=> \$o_prevtime,
        'm:s'   => \$o_memutilization,  'memory_utilization:s' => \$o_memutilization,
	'M:s'	=> \$o_totalmemory,	'total_memory:s' => \$o_totalmemory,
	'q=s'	=> \@o_querykey,	'query=s'	 => \@o_querykey,
	'rate_label:s'	=> \$o_ratelabel,
	map { ($_) } additional_options_list()
    );

    # below code is common for number of my plugins, including check_snmp_?, netstat, etc
    # it is mostly compliant with nagios threshold specification (except use of '~')
    # and adds number of additional format options using '>','<','!','=' prefixes

    # This gets list of variables into $o_varsL and $o_perfvarsL
    options_startprocessing(\%Options);

    # Standard nagios plugin required options
    if (defined($o_help)) { help(); exit $ERRORS{"UNKNOWN"} };
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"} };

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
    if (defined($o_repdelay) && $o_repdelay ne '') {
          verb("Processing replication delay thresholds: $o_repdelay");
	  thresholds_addvar('replication_delay',parse_thresholds_optionsline($o_repdelay));
    }
    if (defined($o_memutilization) && $o_memutilization ne '') {
          verb("Processing memory utilization thresholds: $o_memutilization");
	  thresholds_addvar('memory_utilization',parse_thresholds_optionsline($o_memutilization));
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

    # query option processing
    option_query();

    # if (scalar(@o_varsL)==0 && scalar(@o_perfvarsL)==0) {
    #	print "You must specify list of attributes with either '-a' or '-A'\n";
    #	print_usage();
    #	exit $ERRORS{"UNKNOWN"};
    #    }

    # finish it up
    options_processprevperf();
    options_setthresholds();
    options_setaccess();
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

# some more variables for processing of the results
my $dbversion = "";
my $vnam;
my $vval;
my %dbs=();	# database-specific info, this is almost unused right now
my %slaves=();
my $avar;

prepare_dataresults();

# connect using tcp and verify the port is working
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

# now do connection using Redis library
my $start_time;
my $dsn = $HOSTNAME.":".$PORT;
verb("connecting to $dsn"); 
$start_time = [ Time::HiRes::gettimeofday() ] if defined($o_timecheck);

$redis = Redis-> new ( server => $dsn );

if ($PASSWORD) {
    $redis->auth($PASSWORD);
}
if ($DATABASE) {
    $redis->select($DATABASE);
}

if (!$redis) {
  print "CRITICAL ERROR - Redis Library - can not connect to '$HOSTNAME' on port $PORT\n"; 
  exit $ERRORS{'CRITICAL'};
}

if (!$redis->ping) {
  print "CRITICAL ERROR - Redis Library - can not ping '$HOSTNAME' on port $PORT\n";
  exit $ERRORS{'CRITICAL'};
}

# This returns hashref of various statistics/info data
my $stats = $redis->info();

# Check specified key if option -q was used
for (my $i=0; $i<scalar(@query);$i++) {
  my $result=undef;
  if ($query[$i]{'query_type'} eq 'GET') {
	verb("Getting redis key: ".$query[$i]{'key_query'});
  	$result  = $redis->get($query[$i]{'key_query'});
  }
  elsif ($query[$i]{'query_type'} eq 'LRANGE') {
	my $range_start;
	my $range_end;
	if (defined($query[$i]{'query_range_start'}) && $query[$i]{'query_range_start'} ne '') {
	    $range_start=$query[$i]{'query_range_start'};
	}
        else {
	    $range_start=0;
	}
	if (defined($query[$i]{'query_range_end'}) && $query[$i]{'query_range_end'} ne '') {
	    $range_end= $query[$i]{'query_range_end'} if defined
	}
	else {
	    verb("Getting (lrange) redis key: ".$query[$i]{'key_query'});
	    $range_end = $redis->llen($query[$i]{'key_query'})-1;
	}
	my @list = $redis->lrange($query[$i]{'key_query'}, $range_start, $range_end);
	   if (scalar(@list)>0) {
		$result=shift @list;
		foreach(@list) {
		    $result+=$_ if $query[$i]{'query_subtype'} eq 'SUM' || $query[$i]{'query_subtype'} eq 'AVG';
		    $result=$_ if ($query[$i]{'query_subtype'} eq 'MIN' && $_ < $result) ||
				  ($query[$i]{'query_subtype'} eq 'MAX' && $_ > $result);
		}
		$result = $result / (scalar(@list)+1) if $query[$i]{'query_subtype'} eq 'AVG';
	}
  }
  if (defined($result) && $result) {
      $query[$i]{'result'} = $result;
      dataresults_addvar($query[$i]{'key_name'}, $result);
      verb("Result of querying ".$query[$i]{'key_query'}." is: $result");
  }
  # else {
  #    if (exists($query[$i]{'alert'}) && $query[$i]{'alert'} ne 'OK') {
  #	$statuscode=$query[$i]{'alert'} if $statuscode ne 'CRITICAL';
  #	$statusinfo.=", " if $statusinfo;
  #	$statusinfo.= "Query on ".$query[$i]{'key_query'}." did not succeed";
  #    }
  # }
}

# end redis session
$redis->quit;

# load stats data into internal hash array
my $total_keys=0;
my $total_expires=0;
foreach $vnam (keys %{$stats}) {
     $vval = $stats->{$vnam};
     if (defined($vval)) {
    	verb("Stats Line: $vnam = $vval");
	if (exists($KNOWN_STATUS_VARS{$vnam}) && $KNOWN_STATUS_VARS{$vnam}[0] eq 'VERSION') {
		$dbversion .= $vval;
	}
	elsif ($vnam =~ /^db/) {
		$dbs{$vnam}= {'name'=>$vnam};
		foreach (split(/,/,$vval)) {
			my ($k,$d) = split(/=/,$_);
			dataresults_addvar($vnam.'_'.$k,$d); 
			$dbs{$vnam}{$k}=$d;
			verb(" - stats data added: ".$vnam.'_'.$k.' = '.$d);
			$total_keys+=$d if $k eq 'keys' && isnum($d);
			$total_expires+=$d if $k eq 'expires' && isnum($d);
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
verb("Calculated Data: total_keys=".$total_keys);
verb("Calculated Data: total_expires=".$total_expires);
dataresults_addvar('total_keys',$total_keys);
dataresults_addvar('total_expires',$total_expires);

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

# calculate rate variables
calculate_ratevars();

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
	$dataresults{'replication_delay'}[0]=$repl_delay if $repl_delay!=0;
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

# Check thresholds in all variables and prepare status and performance data for output
main_checkvars();
main_perfvars();

# now output the results
print $statuscode . ': '.$statusinfo;
print " - " if $statusinfo;
print "REDIS " . $dbversion . ' on ' . $HOSTNAME. ':'. $PORT;
print ' has '.scalar(keys %dbs).' databases ('.join(',',keys(%dbs)).')';
print " with ".$dataresults{'total_keys'}[0]." keys" if $dataresults{'total_keys'}[0] > 0;
print ', up '.uptime_info($dataresults{'uptime_in_seconds'}[0]) if defined($dataresults{'uptime_in_seconds'}); 
print "- " . $statusdata if $statusdata;
print " |" . $perfdata if $perfdata;
print "\n";

# exit
exit $ERRORS{$statuscode};