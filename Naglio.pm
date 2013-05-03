package Naglio;

use strict;
use fields qw();
use Text::ParseWords;
use base Exporter;

our $NAME       = 'naglio';
our $VERSION    = '0.3_01';
our $LICENSE    = 'GNU Lesser General Public License (LGPL)';
our $URL        = 'http://william.leibzon.org/nagios/';
our $AUTHOR     = "William Leibzon";

# ====================================== SUMMARY ================================================
#
# Name    : Naglio Perl Library For Developing Nagios Plugins
# Version : 0.3
# Date    : Apr ??, 2013
# Author  : William Leibzon - william@leibzon.org
# Licence : LGPL - full text at http://www.fsf.org/licenses/lgpl.txt
#
#   THIS IS WORK IN PROGRESS, THE LIBRARY HAS NOT BEEN RELEASED YET AND INTERFACES MAY CHANGE
#
# ============================= LIBRARY HISTORY AND VERSIONS ====================================
#
# Note: you may safely skip this section if you're looking at documentation about this library or plugin
#
# [2006-2008]  The history of this library goes back to plugins such as check_snmp_temperature.pl,
#	       check_mysqld,pl and others released as early as 2006 with common functions to
#	       support prefixes "<,>,=,!" for specifying thresholds and checking data against
#	       these thresholds. Several of my plugins had common architecture supporting multiple
#	       variables or attributes to be checked using -a/--attributes/--variables option and
#	       --warn and --crit options with list of thresholds for these attributes and --perfvars
#	       specifying variables whose data would only go as PERFOUT for graphing.
#
# [2008-2011]  Threshold parsing and check code had been rewritten and support added for specifying
#	       range per plugin guidelines: http://nagiosplug.sourceforge.net/developer-guidelines.html
#	       Internal structures had been changing and becoming more complex to various cases.
#	       In 2010-2012 plugins started to get support for ;warn;crit output of thresholds in perf,
#	       as specified in the guidelines.
#
# [Early 2012] Code from check_memcached had been used as a base for check_memcached and then
#	       check_redis plugins with some of the latest threshold code from check_netstat
#	       with more updates. Starting with check_redis the code from check_options() and
#	       from main part of plugin that was very similar across my plugins were separated
#	       into their own functions. KNOWN_STATS_VARS array was introduced as well to be
#	       able to properly add UOM symbol ('c', '%', 's', 'ms', 'B', 'KB') to perfout.
#	       check_memcached and check_redis also included support for calculating rate of
#	       variables in a similar way to how its been done in check_snmp_netint
#
# [0.1 - July 17, 2012] In 0.6 release of check_redis.pl support had been added for long options
#	       with special threshold line syntax:
#                --option=WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL|UNKNOWN,DISPLAY:YES|NO,PERF:YES|NO
#	       This was extension from just doing --option=WARN,CRIT to have a more universal
#	       and extendable way to specify and alike parameters for checking. check_redis 0.6
#	       also introduced support automatically adding long options with above syntax based
#	       on description in KNOWN_STATS_VARS. The functions for the library were all separated
#	       into their own section of the code. When inported to check_memcached global variables
#	       were added to that section and accessor functions written for some of them.
#	       This is considered 0.1 version of the library
#
# [0.2 - Aug 28, 2012] In August the library code in check_memcached had been re-written from
#	       just functions to object-oriented perl interface. All variables were hidden from
#	       direct access with accessor functions written. Documentation header had been added
#	       to each library function and the header for the library itself. This was major work
#	       taking over a week to do although functions and mainly sllllame as in 0.1. They are
#	       not stabilized and so library is only to be included within plugins. Support was
#	       also added for regex matching with PATTERN option spec. Also added NAME spec.
#	       License changed to LGPL from GPL for this code.
# [0.21 - Sep 3, 2012] Fix bug in handling absent data
# [0.22 - Mar 23, 2013] Fixed bug in parse_threshold function (reported by Charlie Langrall)
#
# ================================== LIBRARY TODO =================================================
#
# (a) Add library function to support '--extra-opts' to read plugin options from a file
#     This is to be compatible with http://nagiosplugins.org/extra-opts
# (b) Support regex matching and allowing multiple data for same threshold definition.
#     [DONE]
# (c) Support for expressions in places of numeric values for thresholds. The idea is to allow
#     to refer to another variable or to special macro. I know at least one person has extended
#     my check_mysqld to support using mysql variables (not same as status data) for thresholds.
#     I also previouslyh had planned such support with experimental check_snmp_attributes plugin
#     library/base. The idea was also floated around on nagios-devel list.
# (d) Support specifying variables as expressions. This is straight out of check_snmp_atributes
#     and maybe part of it can be reused for this
# (e) Add common SNMP functions into library as so many of my plugins use it#
# (f) Add more functions to make this library easier to use and stabilize its interfaces.
#     Port my plugins to this library.
# (f) Add support for functions in Nagios-Plugins perl library. While its interfaces are
#     different, I believe, it'd be possible to add "shim" code to support them too.
# (h) Write proper Perl-style documentation as well as web documentation (much of above maybe
#     moved to web documentation) and move library to separate GITHUB project. Release it.
# (i) Port this library to Python and write one or two example plugins
#
# ================================================================================================

$0 = $NAME;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(%ERRORS %STATUS_TEXT verb readable_time trim isnum);
our @EXPORT = qw()

our %ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
our %STATUS_TEXT = (0=>'OK',1=>'WARNING',2=>'CRITICAL',3=>'UNKNOWN',4=>'DEPENDENT');

my $DEFAULT_PERF_OK_STATUS_REGEX = 'GAUGE|COUNTER|^DATA$|BOOLEAN';

############################ START OF THE LIBRARY FUNCTIONS #####################################

#  @DESCRIPTION   : Library object constructor
#  @LAST CHANGED  : 08-27-12 by WL
#  @INPUT         : Hash array of named config settings. All parameters are optiona. Currently supported are:
#		       plugin_name => string               - short name of the plugin
#		       plugin_description => string        - plugin longer description
#		       plugin_authors => string 	   - list of plugin authors
#                      knownStatsVars => reference to hash - hash array defining known variables, what type they are, their description
#		       usage_text => string,		   - text string to display when calling default usage function
#		       usage_function => &ref  		   - OR function that would display helpful text in case of error with options for this plugin
#		       verbose => 1 or "" or "filename"    - set to 1 or "" if verbose/debug or to filename to send data to (may not be called "0" or "1")
#                      output_comparison_symbols => 0 or 1 - 1 means library output in case threshold is met can use "<", ">", "="
#						             0 means output is something like "less than or equal", "more than", etc.
#		       all_variables_perf => 0 or 1        - 1 means data for all variables would go to PERF. This is what '-A *' or just -A do
#		       enable_long_options => 0 or 1       - 1 enables long options generated based on knownStatsVars. This is automatically enabled (from 0
#							     to 1) when plugin references additional_options_list() unless this is set to -1 at library init
#		       enable_rate_of_change => 0 or 1     - enables support for calculating rate of change based on previously saved data, default is 1
#		       enable_regex_match => 0 or 1	   - when set to 1 each threshold-specified var name is treated as regex and can match
#							     to multiple collected data. this can also be enabled per-variable with PATTERN spec
#  @RETURNS       : Reference representing object instance of this library
#  @PRIVACY & USE : PUBLIC, To be used when initializing the library
sub lib_init {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my %other_args = @_;

    # These used to be global variables, now these are object local variables in self with accessor
    my @allVars = ();		# all variables after options processing
    my @perfVars = ();		# performance variables list [renamed from @o_perfVarsL in earlier code]
    my %thresholds=();		# hash array of thresholds for above variables, [this replaced @o_warnL and @o_critL in earlier code]
    my %dataresults= ();	# This is where data is loaded. It is a hash with variable names as keys and array for value:
				#   $dataresults{$var}[0] - undef of value of this variable
				#   $dataresults{$var}[1] - 0 if variable not printed out to status line yet, 1 or more otherwise
			        #   $dataresults{$var}[2] - 0 if variable data not yet put into PERF output, -1 if PERF output is preset, 1 after output
			        #   $dataresults{$var}[3] - string, '' to start with, holds ready performance data output for this variable
				#   $dataresults{$var}[4] - only for regex matches. name of match var (which should be key in thresholds), otherwise undef
    my %dataVars = ();		# keys are variables from allVars and perfVars, values is array of data that matched i.e. keys in dataresults
    my @ar_warnLv = ();		# used during options processing
    my @ar_critLv = ();		# used during options processing
    my @ar_varsL=   ();        # used during options processing
    my @prev_time=  ();     	# timestamps if more then one set of previois performance data

    my $self = {  # library and nagios versions
		_NaglioLibraryVersion => 0.2,	# this library's version
		_NagiosVersion => 3, 		# assume nagios core 3.x unless known otherwise
                # library internal data structures
		_allVars => \@allVars,
		_perfVars => \@perfVars,
	        _thresholds => \%thresholds,
		_dataresults => \%dataresults,
		_datavars => \%dataVars,
		_ar_warnLv => \@ar_warnLv,
		_ar_critLv => \@ar_critLv,
		_ar_varsL => \@ar_varsL,
		_prevTime => \@prev_time,
		_prevPerf => {},		# array that is populated with previous performance data
		_checkTime => undef,		# time when data was last checked
		_statuscode => "OK",		# final status code
		_statusinfo => "",		# if there is an error, this has human info about what it is
		_statusdata => "",		# if there is no error but we want some data in status line, this var gets it
		_perfdata => "",		# this variable collects performance data line
		_saveddata => "",		# collects saved data (for next plugin re-run, not implimented yet)
		_init_args => \%other_args,
                # copy of data from plugin option variables
		o_variables => undef,		# List of variables for warn and critical checks
		o_crit => undef,		# Comma-separated list of critical thresholds for each checked variable
		o_warn => undef,		# Comma-separated list of warning thresholds for each checked variable
		o_perf => undef,		# defined or undef. perf option means all data from variables also goes as PERFDATA
		o_perfvars => undef,		# List of variables only for PERFDATA
                o_prevperf => undef, 		# previously saved performance data coming from $SERVICEPERFDATA$ macro
	        # library special input variables (similar to options)
		o_rprefix => '',		# prefix used to distinguish rate variables
		o_rsuffix => '_rate',		# suffix used to distinguish rate variables
		knownStatusVars => {},		# Special HASH ARRAY with names and description of known variables
		perfOKStatusRegex => $DEFAULT_PERF_OK_STATUS_REGEX,
		verbose => 0,			# verbose, same as debug, same as o_verb
		plugin_name => '',		# this and next 3 parameters are currently not used
		plugin_description => '',	# but its still better if these are provided
		plugin_authors => '',		# in the future these maybe used for help & usage functions
		usage_text => ''		# usage text, this is alternative to usage_function()
		# library setting variables
		debug_file => "",		# instead of setting file name in verbose, can also set it here
		output_comparison_symbols => 1, # should plugin output >,<.=,! for threshold match
						# if 0, it will say it in human form, i.e. "less"
		all_variables_perf => 0,	# should we all variables go to PERF (even those not listed in o_variables and o_perfvars)
						# this is the option set to 1 when --perfvars '*' is used
		enable_long_options => 0,	# enable support for long options generated based on knownStatusVars description
		enable_rate_of_change => 1,	# enables support for calculating rate of change and for rate of change long options
		enable_regex_match => 0,	# 0 is not enabled, 1 means variables in o_variables and o_perfvars are considered regex to match actual data
						# a value of 2 means its enabled, but for options with PATTERN specifier (this is not configurable value)
	      };

    # bless to create an object
    bless $self, $class;

    # deal with arguments that maybe passed to library when initalizing
    if (exists($other_args{'KNOWN_STATUS_VARS'})) {
        $self->{'knownStatusVars'} = $other_args{'KNOWN_STATUS_VARS'};
    }
    $self->{'plugin_name'} = $other_args{'plugin_name'} if exists($other_args{'plugin_name'});
    $self->{'plugin_description'} = $other_args{'plugin_description'} if exists($other_args{'plugin_description'});
    $self->{'plugin_authors'} = $other_args{'plugin_authors'} if exists($other_args{'plugin_authors'});
    $self->{'_usage_function'} = $other_args{'usage_function'} if exists($other_args{'usage_function'});
    $self->{'usage_text'} = $other_args{'usage'} if exists($other_args{'usage'});
    $self->configure(%other_args);

    # return self object
    return $self;
}

# This is just an alias for object constructor lib_init function
sub new {
    return lib_init(@_);
}

#  @DESCRIPTION   : Allows to confiure some settings after initialization (all these can also be done as part of lib_init)
#  @LAST CHANGED  : 08-27-12 by WL
#  @INPUT         : Hash array of named config settings. All parameters are optiona. Currently supported are:
#		       verbose => 1 or "" or "filename"    - set to 1 or "" if verbose/debug or to filename to send data to (may not be called "0" or "1")
#                      output_comparison_symbols => 0 or 1 - 1 means library output in case threshold is met can use "<", ">", "="
#						             0 means output is something like "less than or equal", "more than", etc.
#		       all_variables_perf => 0 or 1        - 1 means data for all variables would go to PERF. This is what '-A *' or just -A do
#		       enable_long_options => 0 or 1       - 1 enables long options generated based on knownStatsVars. This is automatically enabled (from 0
#							     to 1) when plugin references additional_options_list() unless this is set to -1 at library init
#		       enable_rate_of_change => 0 or 1     - enables support for calculating rate of change based on previously saved data, default is 1
#		       enable_regex_match => 0 or 1	   - when set to 1 each threshold-specified var name is treated as regex and can match
#							     to multiple collected data. this can also be enabled per-variable with PATTERN spec
#  @RETURNS       :  nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, Must be used as an object instance function.
sub configure {
    my $self = shift;
    my %args = @_;

    if (exists($args{'verbose'}) || exists($args{'debug'})) {
        $self->{'verbose'} = 1;
        if (exists($args{'verbose'}) && $args{'verbose'}) {
	    $self->{'debug_file'} = $args{'verbose'};
        }
        if (exists($args{'debug_log_filename'})) {
	    $self->{'debug_file'} = $args{'debug_log_filename'};
        }
    }
    $self->{'all_variables_perf'} = $args{'all_variables_perf'} if exists($args{'all_variables_perf'});
    $self->{'enable_long_options'} = $args{'enable_long_options'} if exists($args{'enable_long_options'});
    $self->{'enable_rate_of_change'} = $args{'enable_rate_of_change'} if exists($args{'enable_rate_of_change'});
    $self->{'enable_regex_match'} = 1 if exists($args{'enable_regex_match'}) && $args{'enable_regex_match'}!=0;
    $self->{'output_comparison_symbols'} = $args{'output_comparison_symbols'} if exists($args{'output_comparison_symbols'});
}

#  @DESCRIPTION   : Allows functions to be used both directly and as an object referenced functions
#                   In the 2nd case they get $self as 1st argument, in 1st they don't. So this just adds
#		    $self if its if its not there so their argument list is known.
#		    Functions that allow both should still check if $self is defined.
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : arbitrary list of arguments
#  @RETURNS       : arbitrary list of arguments with 1st being object hash or undef
#  @PRIVACY & USE : PRIVATE
sub _self_args {
    return @_ if ref($_[0]) && exists($_[0]->{'_NaglioLibraryVersion'});
    unshift @_,undef;
    return @_;
}

#  @DESCRIPTION   : Sets function to be called to display help text on using plugin in case of error
#  @LAST CHANGED  : 08-22-12 by WL
#  @INPUT         : reference to usage function
#  @RETURNS       : nothing
#  @PRIVACY & USE : PUBLIC, Must be used as an object instance function :
sub set_usage_function {
    my ($self, $usage_function) = @_;
    $self->{'_usage_function'} = $usage_function;
}

#  @DESCRIPTION   : Usage function. For right now it just calls usage function given as a parameter
#		    In the future if it is not available, it'll print something standard.
#  @LAST CHANGED  : 08-22-12 by WL
#  @INPUT         : none
#  @RETURNS       : nothing
#  @PRIVACY & USE : PUBLIC, But primary for internal use. Must be used as an object instance function.
sub usage {
  my $self = shift;
  if (defined($self) && defined($self->{'_usage_function'})) { &{$self->{'_usage_function'}}(); }
  else if (defined($self) && defined($self->{'usage_text'})) { print $self->{'usage_text'}; print "\n"; }
}

#  @DESCRIPTION   : This function converts time in seconds to nice & short output format
#  @LAST_CHANGED  : 02-10-13 by WL
#  @INPUT         : ARG1 - time in seconds
#  @RETURNS       : string of time for human consumption
#  @PRIVACY & USE : PUBLIC, Maybe used directly or as an object instance function :
sub readable_time {
  my ($self,$total_sec) = _self_args(@_);
  my ($sec,$mins,$hrs,$days);
  my $txtout="";

  sub div_mod { return int( $_[0]/$_[1]) , ($_[0] % $_[1]); }

  ($mins,$sec) = div_mod($total_sec,60);
  ($hrs,$mins) = div_mod($mins,60);
  ($days,$hrs) = div_mod($hrs,24);
  $txtout .= "$days days " if $days>0;
  $txtout .= (($txtout ne '')?' ':'').$hrs." hours" if $hrs>0;
  $txtout .= (($txtout ne '')?' ':'').$mins." minutes" if $mins>0 && ($days==0 || $hrs==0);
  $txtout .= (($txtout ne '')?' ':'').$secs." seconds" if ($sec>0 || $mins==0) && ($hrs==0 && $days==0);
  return $txtout;
}

#  @DESCRIPTION   : If debug / verbose option is set, function prints its input out or to debug file
#  @LAST_CHANGED  : 08-20-12 by WL
#  @INPUT         : ARG1 - string of debug text
#  @RETURNS       : nothing
#  @PRIVACY & USE : PUBLIC, Maybe used directly or as object instance function
sub verb {
    my ($self,$in) = _self_args(@_);
    my $debug_file_name = "";

    if (defined($o_verb) || (defined($self) && defined($self->{'verbose'}) && $self->{'verbose'} ne 0)) {
        $debug_file_name = $self->{'debug_file'} if defined($self) && $self->{'debug_file'} ne "";
        $debug_file_name = $self->{'verbose'} if $debug_file_name ne "" && defined($self) &&
					         ($self->{'verbose'} ne 0 && $self->{'verbose'} ne 1 && $self->{'verbose'} ne '');
        $debug_file_name = $o_verb if $debug_file_name ne "" && defined($o_verb) && $o_verb ne "";
        if ($debug_file_name ne "") {
	    if (!open (DEBUGFILE, ">>$debug_file_name")) {
		print $in, "\n";
	    }
	    else {
		print DEBUGFILE $in,"\n";
		close DEBUGFILE;
	    }
        }
        else {
	    print $in, "\n";
        }
    }
}

#  @DESCRIPTION   : Check of string is a a number supporting integers, negative, decimal floats
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : ARG1 - string of text to be checked
#  @RETURNS       : 1 if its a number, 0 if its not a number
#  @PRIVACY & USE : PUBLIC, To be used statically and not as an object instance reference
sub isnum {
    my $num = shift;
    if (defined($num) && $num =~ /^[-|+]?((\d+\.?\d*)|(^\.\d+))$/ ) { return 1 ;}
    return 0;
}

#  @DESCRIPTION   : Check of string is a a number supporting integers, negative, decimal floats
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : ARG1 - string of text to be checked
#  @RETURNS       : 1 if its a number, 0 if its not a number
#  @PRIVACY & USE : PUBLIC, To be used statically and not as an object instance function
sub trim {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

#  @DESCRIPTION   : Takes as input string from PERF or SAVED data from previous plugin invocation
#                   which should contain space-separated list of var=data pairs. The string is
#                   parsed and it returns back hash array of var=>data pairs.
#		      - Function written in 2007 for check_snmp_netint, first release 06/01/07
# 		      - Modified to use quotewords as suggested by Nicholas Scott, release of 05/20/12
#  @LAST CHANGED  : 08-27-12 by WL
#  @INPUT         : ARG1 - string of text passed from SERVICEPERFDATA OR SERVICESAVEDDATA MACRO
#  @RETURNS       : hash array (see description)
#  @PRIVACY & USE : PUBLIC, Maybe used directly or as object instance function
# TODO: double-check this works when there are no single quotes as check_snmp_netint always did quotes
sub process_perf {
   my ($self,$in) = _self_args(@_);
   my %pdh;
   my ($nm,$dt);
   use Text::ParseWords;
   foreach (quotewords('\s+',1,$in)) {
       if (/(.*)=(.*)/) {
           ($nm,$dt)=($1,$2);
	   if (defined($self)) { $self->verb("prev_perf: $nm = $dt"); }
	   else { verb("prev_perf: $nm = $dt"); }
           # in some of my plugins time_ is to profile execution time for part of plugin
           # $pdh{$nm}=$dt if $nm !~ /^time_/;
           $pdh{$nm}=$dt;
           $pdh{$nm}=$1 if $dt =~ /(\d+)[csB%]/; # 'c' or 's' or B or % maybe have been added
	   # support for more than one set of previously cached performance data
           # push @prev_time,$1 if $nm =~ /.*\.(\d+)/ && (!defined($prev_time[0]) || $prev_time[0] ne $1);
       }
   }
   return %pdh;
}

#  @DESCRIPTION   : Converts variables with white-spaces with per-name enclosed with ''
#  @LAST CHANGED  : 08-24-12 by WL
#  @INPUT         : ARG1 - varible name
#  @RETURNS       : name for perf-out output
#  @PRIVACY & USE : PUBLIC, but its use should be limited. To be used statically and not as an object instance function
sub perf_name {
    my $in = shift;
    my $out = $in;
    $out =~ s/'\/\(\)/_/g; #' get rid of special characters in performance description name
    if ($in !~ /\s/ && $in eq $out) {
        return $in;
    }
    return "'".$out."'";
}

#  @DESCRIPTION   : Determines appropriate output name (for STATUS and PERF) taking into account
#		    rate variales prefix/suffix and 'NAME' override in long thresholds line specification
#  @LAST CHANGED  : 08-26-12 by WL
#  @INPUT         : ARG1 - variable name (variable as found in dataresults)
#  @RETURNS       : name for output
#  @PRIVACY & USE : PUBLIC, but its use should be limited. To be as an object instance function,
sub out_name {
    my ($self,$dname) = @_;
    my $thresholds = $self->{'_thresholds'};
    my $dataresults = $self-> {'_dataresults'};
    my $vr = $self->data2varname($dname,1);
    my $name_out;

    if (defined($vr) && exists($thresholds->{$vr}{'NAME'})) {
	if (exists($thresholds->{$vr}{'PATTERN'}) || $self->{'enable_regex_match'} == 1) {
	    $thresholds->{$vr}{'NAMES_INDEX'} = {} if !exists($thresholds->{$vr}{'NAMES_INDEX'});
	    if (!exists($thresholds->{$vr}{'NAMES_INDEX'}{$dname})) {
		my $ncount = scalar(keys %{$thresholds->{$vr}{'NAMES_INDEX'}});
		$ncount++;
		$thresholds->{$vr}{'NAMES_INDEX'}{$dname} = $ncount;
	    }
	    $name_out = $thresholds->{$vr}{'NAME'} .'_'. $thresholds->{$vr}{'NAMES_INDEX'}{$dname};
	}
	else {
	    $name_out = $thresholds->{$vr}{'NAME'};
	}
    }
    else {
	# this is for output of rate variables which name internally start with &
	if ($dname =~ /^&(.*)/) {
	    $name_out = $self->{'o_rprefix'}.$1.$self->{'o_rsuffix'};
	}
	else {
	    $name_out = $dname;
	}
    }
    return $name_out;
}

#  @DESCRIPTION   : Builds statusline. Adds info on error conditions that would preceed status data.
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : ARG1 - variable name
#		    ARG2 - string argument for status info
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, but its direct use is discouraged. Must be used as an object instance function
sub addto_statusinfo_output {
    my ($self, $var, $sline) = @_;
    $self->{'_statusinfo'} .= ", " if $self->{'_statusinfo'};
    $self->{'_statusinfo'} .= trim($sline);
    $self->{'_dataresults'}{$var}[1]++;
}

#  @DESCRIPTION   : Accessor function for statusinfo
#  @LAST CHANGED  : 08-22-12 by WL
#  @INPUT         : none
#  @RETURNS       : statusinfo (error conditions and messages) string
#  @PRIVACY & USE : PUBLIC. Must be used as an object instance function
sub statusinfo {
    my $self = shift;
    if (defined($self) && defined($self->{'_statusinfo'})) {
	return $self->{'_statusinfo'};
    }
    return undef;
}

#  @DESCRIPTION   : Builds Statuline. Adds variable data for status line output in non-error condition.
#  @LAST CHANGED  : 08-26-12 by WL
#  @INPUT         : ARG1 - variable name
#		    ARG2 - formatted for human consumption text of collected data for this variable
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, but its direct use is discouraged. Must be used as an object instance function
sub addto_statusdata_output {
    my ($self,$dvar,$data) = @_;
    my $thresholds = $self->{'_thresholds'};
    my $dataresults = $self -> {'_dataresults'};
    my $avar = $self->data2varname($dvar,1);

    # $self->verb("debug: addto_statusdata_output - dvar is $dvar and avar is $avar");
    if ((!exists($thresholds->{$avar}{'DISPLAY'}) || $thresholds->{$avar}{'DISPLAY'} eq 'YES') &&
        (!exists($dataresults->{$dvar}[1]) || $dataresults->{$dvar}[1] == 0)) {
           $self->{'_statusdata'} .= ", " if $self->{'_statusdata'};
           if (defined($data)) {
              $self->{'_statusdata'} .= trim($data);
           }
           elsif (exists($dataresults->{$dvar}[0])) {
              $self->{'_statusdata'} .= $self->out_name($dvar) ." is ".$dataresults->{$dvar}[0];
           }
           $dataresults->{$dvar}[1]++;
    }
}

#  @DESCRIPTION   : Accessor function for statusdata
#  @LAST CHANGED  : 08-22-12 by WL
#  @INPUT         : none
#  @RETURNS       : statusdata string (non-error data from some variables)
#  @PRIVACY & USE : PUBLIC. Must be used as an object instance function
sub statusdata {
    my $self = shift;
    if (defined($self) && defined($self->{'_statusdata'})) {
	return $self->{'_statusdata'};
    }
    return undef;
}

#  @DESCRIPTION   : This function sets text or data for data variable PERFORMANCE output
#		    (;warn;crit would be added to it later if thresholds were set for this variable)
#  @LAST CHANGED  : 08-26-12 by WL
#  @INPUT         : ARG1 - variable name
#		    ARG2 - either "var=data" text or just "data" (in which case var= is prepended to it)
#		    ARG3 - UOM symol ('c' for continous, '%' for percent, 's' for seconds) to added after data
#			   if undef then it is looked up in known variables and if one is present there, its used
#		    ARG4 - one of: "REPLACE" - if existing preset perfdata is present, it would be replaced with ARG2
#		                   "ADD"     - if existing preset perfdata is there, ARG2 string would be added to it (DEFAULT)
#				   "IFNOTSET - only set perfdata to ARG2 if it is empty, otherwise keep existing
#  @RETURNS       : nothing (future: 0 on success, -1 on error)
#  @PRIVACY & USE : PUBLIC, but its use should be limited to custom variables added by plugins to data
#                   Must be used as an object instance function
sub set_perfdata {
    my ($self,$avar,$adata,$unit,$opt) = @_;
    my $dataresults = $self->{'_dataresults'};
    my $thresholds = $self->{'_thresholds'};
    my $known_vars = $self->{'knownStatusVars'};
    my $bdata = $adata;
    my $vr = undef;

    # default operation is ADD
    if (!defined($opt)) {
	$opt = "ADD";
    }
    else {
	$opt = uc $opt;
    }
    if (defined($adata)) {
	# if only data wthout "var=" create proper perf line
	$bdata = perf_name($self->out_name($avar)).'='.$adata if $adata !~ /=/;
	if (defined($unit)) {
	    $bdata .= $unit;
	}
	else {
	    # appending UOM is done here
	    $vr = $self->data2varname($avar,1);
	    if (defined($vr)) {
		if (exists($thresholds->{$vr}{'UOM'})) {
		    $bdata .= $thresholds->{$vr}{'UOM'};
		}
	        elsif (exists($known_vars->{$vr}[2])) {
		     $bdata .= $known_vars->{$vr}[2];
		}
	    }
	}
	# preset perfdata in dataresults array
	$dataresults->{$avar}=[undef,0,0,''] if !defined($dataresults->{$avar});
	$dataresults->{$avar}[2]=-1;
	if ($opt eq "REPLACE" || !exists($dataresults->{$avar}[3]) || $dataresults->{$avar}[3] eq '') {
	    $dataresults->{$avar}[3]=$bdata;
	}
	elsif (exists($dataresults->{$avar}[3]) && $dataresults->{$avar}[3] ne '' && $opt eq "ADD") {
	    $dataresults->{$avar}[3].=$adata;
	}
    }
}

#  @DESCRIPTION   : This function is used when building performance output
#  @LAST CHANGED  : 08-26-12 by WL
#  @INPUT         : ARG1 - variable name
#		    ARG2 - optional data argument, if not present variable's dataresults are used
#		    ARG3 - one of: "REPLACE" - if existing preset perfdata is present, it would be replaced with ARG2
#		                   "ADD"    - if existing preset perfdata is there, ARG2 string would be added to it
#				   "IFNOTSET - only set perfdata to ARG2 if it is empty, otherwise keep existing (DEFAULT)
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, but its direct use is discouraged. Must be used as an object instance function
sub addto_perfdata_output {
    my ($self,$avar,$adata, $opt) = @_;
    my $thresholds = $self->{'_thresholds'};
    my $dataresults = $self-> {'_dataresults'};
    my $vr = undef;

    if (!defined($opt)) {
	$opt = "IFNOTSET";
    }
    else {
	$opt = uc $opt;
    }
    $vr = $self->data2varname($avar,1);
    if (defined($avar) && defined($vr) &&
        (!exists($thresholds->{$vr}{'PERF'}) || $thresholds->{$vr}{'PERF'} eq 'YES') &&
        (!defined($dataresults->{$avar}[2]) || $dataresults->{$avar}[2] < 1)) {
           my $bdata = '';
	   if (defined($adata)) {
              $bdata .= trim($adata);
           }
	   # this is how most perfdata gets added
           elsif (defined($dataresults->{$avar}[0])) {
	      $bdata .= perf_name($self->out_name($avar)) .'='. $dataresults->{$avar}[0];
           }
	   # this would use existing preset data now if it was present due to default
	   # setting UOM from KNOWN_STATUS_VARS array is now in set_perfdata if 3rd arg is undef
	   $self->set_perfdata($avar,$bdata,undef,$opt);
	   # now we actually add to perfdata from [3] of dataresults
	   if (exists($dataresults->{$avar}[3]) && $dataresults->{$avar}[3] ne '') {
		$bdata = trim($dataresults->{$avar}[3]);
		$self->{'_perfdata'} .= " " if $self->{'_perfdata'};
		$self->{'_perfdata'} .= $bdata;
		$dataresults->{$avar}[2]=0 if $dataresults->{$avar}[2] < 0;
		$dataresults->{$avar}[2]++;
	   }
    }
}

#  @DESCRIPTION   : Accessor function for map from data collected to variable names specified in options and thresholds
#  @LAST CHANGED  : 08-22-13 by WL
#  @INPUT         : ARG1 - data variable name
#		    ARG2 - if undef or 0 return undef if no match for ARG1 found, if 1 return ARG1
#  @RETURNS       : string of variable name as was specified with --variables or --thresholds
#  @PRIVACY & USE : PUBLIC. Must be used as an object instance function
sub data2varname {
    my ($self,$dname,$ropt) = @_;
    my $dataresults = $self->{'_dataresults'};

    return $dataresults->{$dname}[4] if defined($self) && defined($dataresults->{$dname}[4]);
    return $dname if defined($ropt) && $ropt eq 1;
    return undef;
}

#  @DESCRIPTION   : Sets list and info on known variables and regex for acceptable data types.
#		    This function maybe called more than once. If called again, new vars in subsequent
#		    calls are added to existing ones and existing vars are replaced if they are there again.
#  @LAST CHANGED  : 08-22-12 by WL
#  @INPUT         : ARG1 - ref to hash array of known vars. Keys are variable names. Data is an array. Example is:
#  	 			'version' =>  [ 'misc', 'VERSION', '' ],
#			        'utilization' => [ 'misc', 'GAUGE', '%' ],
#	 			'cmd_get' => [ 'misc', 'COUNTER', 'c', "Total Number of Get Commands from Start" ],
#			   The array elements are:
#			    1st - string of source for this variable. not used by the library at all, but maybe used by code getting the data
#			    2nd - type of data in a variable. May be "GAUGE", "VERSION", "COUNTER", "BOOLEAN", "TEXTINFO", "TEXTDATA", "SETTING"
#			    3rd - either empty or one-character UOM to be added to perforance data - 'c' for continous, '%' percent, 's' seconds
#			    4th - either empty or a description of this variable. If not empty, the variable becomes long-option and this is help text
#		    ARG2 - regex of acceptable types of data for performance output. Anything else is ignored (i.e. no no output to perf), but
#			   is still available for threshold checks. if this is undef, then default of 'GAUGE|COUNTER|^DATA$|BOOLEAN' is used
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, Must be used as object instance function
sub set_knownvars {
  my ($self, $known_vars_in, $vartypes_regex_in) = @_;
  my $known_vars = $self->{'knownStatusVars'};

  if (defined($known_vars_in)) {
    foreach (keys %{$known_vars_in}) {
      $known_vars->{$_} = $known_vars_in->{$_};
    }
  }
  if (defined($vartypes_regex_in)) {
      $self->{'perfOKStatusRegex'} = $vartypes_regex_in;
  }
  else {
      $self->{'perfOKStatusRegex'} = $DEFAULT_PERF_OK_STATUS_REGEX;
  }
}

#  @DESCRIPTION   : Adds known variables definition one at a time
#  @LAST CHANGED  : 08-22-12 by WL
#  @INPUT         : ARG1 - variable name
#	            ARG2 - string of source for this variable. not used by the library at all, but maybe used by code getting the data
#	            ARG3 - type of data in a variable. May be "GAUGE", "VERSION", "COUNTER", "BOOLEAN", "TEXTINFO", "TEXTDATA", "SETTING"
#	            ARG4 - either empty or one-character UOM symbol to be added to perforance data - 'c' for continous, '%' percent, 's' seconds
#		    ARG5 - either empty or a description of this variable. If not empty, the variable becomes long-option and this is help text
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, Must be used as object instance function
sub add_knownvar {
  my ($self, $varname, $source, $type, $unit, $description) = @_;
  my $temp = { $varname => [ $source, $type, $unit, $description] };
  $self->set_knownvars($temp,undef);
}

#  @DESCRIPTION   : This function is used for checking data values against critical and warning thresholds
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : ARG1 - variable name (used for text output in case it falls within threshold)
#		    ARG2 - data to be checked
#                   ARG3 - threshold to be checked, internal structure returned by parse_threshold()
#  @RETURNS       : Returns "" (empty string) if data is not within threshold range
#                   and text message for status line out about how data is within range otherwise
#  @PRIVACY & USE : PUBLIC. Maybe used directly or as an object instance function
sub check_threshold {
    my ($self,$attrib,$data,$th_array) = _self_args(@_);
    my $mod = $th_array->[0];
    my $lv1 = $th_array->[1];
    my $lv2 = $th_array->[2];
    my $issymb = 1;
    $issymb = 0 if defined($self) && $self->{'output_comparison_symbols'} eq 0;

    # verb("debug check_threshold: $mod : ".(defined($lv1)?$lv1:'')." : ".(defined($lv2)?$lv2:''));
    return "" if !defined($lv1) || ($mod eq '' && $lv1 eq '');
    return " " . $attrib . " is " . $data . ( ($issymb==1)?' = ':' equal to ' ). $lv1 if $mod eq '=' && $data eq $lv1;
    return " " . $attrib . " is " . $data . ( ($issymb==1)?' != ':' not equal to ' ). $lv1 if $mod eq '!' && $data ne $lv1;
    return " " . $attrib . " is " . $data . ( ($issymb==1)?' > ':' more than ' ) . $lv1 if $mod eq '>' && $data>$lv1;
    return " " . $attrib . " is " . $data . ( ($issymb==1)?' > ':' more than ' ) . $lv2 if $mod eq ':' && $data>$lv2;
    return " " . $attrib . " is " . $data . ( ($issymb==1)?' >= ':' more than or equal to ' ) . $lv1 if $mod eq '>=' && $data>=$lv1;
    return " " . $attrib . " is " . $data . ( ($issymb==1)?' < ':' less than ' ). $lv1 if ($mod eq '<' || $mod eq ':') && $data<$lv1;
    return " " . $attrib . " is " . $data . ( ($issymb==1)?' <= ':' less than or equal to ' ) . $lv1 if $mod eq '<=' && $data<=$lv1;
    return " " . $attrib . " is " . $data . " in range $lv1..$lv2" if $mod eq '@' && $data>=$lv1 && $data<=$lv2;
    return "";
}

#  @DESCRIPTION   : This function is called to parse threshold string
#  @LAST CHANGED  : 08-20-12 by WL
#		    (the code in this function can be traced back to late 2006. It has not much changed from 2008)
#  @INPUT         : ARG1 - String for one variable WARN or CRIT threshold which can be as follows:
#			 data  - warn if data is above this value if numeric data, or equal for non-numeric
#        		 >data - warn if data is above this value (default for numeric values)
#        		 <data - warn if data is below this value (must be followed by number)
#        		 =data - warn if data is equal to this value (default for non-numeric values)
#                        !data - warn if data is not equal to this value
#      		    Threshold can also be specified as range in two forms:
#        		 num1:num2  - warn if data is outside range i.e. if data<num1 or data>num2
#                       \@num1:num2 - warn if data is in range i.e. data>=num1 && data<=num2
#  @RETURNS       : Returns reference to a hash array, this library's structure for holding processed threshold spec
#  @PRIVACY & USE : PUBLIC. Maybe used directly or as an object instance function
sub parse_threshold {
    my ($self,$thin) = _self_args(@_);

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
                if (defined($self)) { $self->usage(); }
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
        if (defined($self)) { $self->usage(); }
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

#  @DESCRIPTION   : this function checks that for numeric data warn threshold is within range of critical
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : ARG1 - warhing threshold structure (reference to hash array)
#                   ARG2 - critical threshold structure (reference to hash array)
#  @RETURNS       : Returns 1 if warning does not fall within critical (there is an error)
#                   Returns 0 if everything is ok and warning is within critical
#  @PRIVACY & USE : PUBLIC, but its use is discouraged. Maybe used directly or as an object instance function.
sub threshold_specok {
    my ($self, $warn_thar,$crit_thar) = _self_args(@_);

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

#  @DESCRIPTION   : this compares var names from data to names given as plugin options treating them regex
#  @LAST CHANGED  : 08-26-12 by WL
#  @INPUT         : ARG1 - the name to search for
#  @RETURNS       : Keyname for what first one that matched from _thresholds
#                   Undef if nothing matched
#  @PRIVACY & USE : PUBLIC, but its direct use should be rare. Must be used as an object instance function.
sub var_pattern_match {
    my ($self, $name) = @_;
    my $thresholds = $self->{'_thresholds'};
    my $allvars = $self->{'_allVars'};
    my $is_regex_match = $self->{'enable_regex_match'};
    my $v;
    my $pattern;

    foreach $v (@{$allvars}) {
	$pattern='';
	if ($is_regex_match eq 1 && !defined($thresholds->{$v}{'PATTERN'})) {
	    $pattern=$v;
	}
	elsif ($is_regex_match ne 0 && defined($thresholds->{$v}{'PATTERN'})) {
	    $pattern = $thresholds->{$v}{'PATTERN'};
	}
	if ($pattern ne '' && $name =~ /$pattern/) {
	    $self->verb("Data name '".$name."' matches pattern '".$pattern."'");
	    return $v;
	}
    }
    return undef;
}

#  @DESCRIPTION   : This function adds data results
#  @LAST CHANGED  : 08-27-12 by WL
#  @INPUT         : ARG1 - name of data variable
#                   ARG2 - data for this variable
#		    ARG3 - name of checked variable/parameter corresponding to this data variable
#			   default undef, assumed to be same as ARG1
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, Must be used as an object instance function
sub add_data {
    my ($self, $dnam, $dval, $anam) = @_;
    my $thresholds = $self->{'_thresholds'};
    my $dataresults = $self-> {'_dataresults'};
    my $datavars = $self -> {'_datavars'};
    my $perfVars = $self->{'_perfVars'};

    # determine what plugin options-specified var & threshold this data corresponds to
    if (!defined($anam)) {
	if ($self->{'enable_regex_match'} == 0) {
	    $anam = $dnam;
	}
	else {
	    $anam = $self->var_pattern_match($dnam);
	    $anam = $dnam if !defined($anam);
	}
    }
    # set dataresults
    if (exists($dataresults->{$dnam})) {
        $dataresults->{$dnam}[0] = $dval;
        $dataresults->{$dnam}[4] = $anam if defined($anam);
    }
    else {
        $dataresults->{$dnam} = [$dval, 0, 0, '', $anam];
    }
    # reverse map array
    $datavars->{$anam} = [] if !exists($datavars->{$anam});
    push @{$datavars->{$anam}}, $dnam;
    # setperf if all variables go to perf
    if ($self->{'all_variables_perf'} == 1) {
        $thresholds->{$anam}={} if !exists($thresholds->{$anam});
	$thresholds->{$anam}{'PERF_DATALIST'} = [] if !exists($thresholds->{$anam}{'PERF_DATALIST'});
	push @{$thresholds->{$anam}{'PERF_DATALIST'}}, $dnam;
	if (!defined($thresholds->{$anam}{'PERF'})) {
	    push @{$perfVars}, $anam;
	    $thresholds->{$anam}{'PERF'} = 'YES';
	}
    }
}

#  @DESCRIPTION   : Accessor function that gets variable data
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : ARG1 - name of data variable
#  @RETURNS       : undef if variable does not exist and data otherwise
#  @PRIVACY & USE : PUBLIC, Must be used as an object instance function
sub vardata {
    my ($self,$dnam) = @_;
    my $dataresults = $self->{'_dataresults'};
    return undef if !exists($dataresults->{$dnam});
    return $dataresults->{$dnam}[0];
}

#  @DESCRIPTION   : This function parses "WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL|UNKNOWN" combined threshold string
#		    Parsing of actual threshold i.e. what is after WARN, CRIT is done by parse_threshold() function
#  @LAST CHANGED  : 08-27-12 by WL
#  @INPUT         : ARG1 - String containing threshold line like "WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL|UNKNOWN"
#		    Acceptable comma-separated parts threshold specifiers are:
#		       WARN:<threshold> - warning threshold
#		       CRIT:<treshold>  - critical threshold
#		       ABSENT:OK|WARNING|CRITICAL|UNKNOWN - nagios exit code if data for this variable is not found
#		       ZERO:OK|WARNING|CRITICAL|UNKNOWN - nagios exit code if data is 0
#		       DISPLAY:YES|NO - output data in plugin status line
#		       PERF:YES|NO    - output data as plugin performance data
#		       SAVED:YES|NO   - put results in saved data (this really should not be set manually)
#		       PATTERN:<regex> - enables regex match allowing more than one real data name to match this threshold
#		       NAME:<string> - overrides output status and perf name for this variable
#		       UOM:<string>  - unit of measurement symbol to add to perf
#  @RETURNS       : Returns reference to a hash array, a library's structure for holding processed MULTI-THRESHOLD spec
#		    Note that this is MULTI-THRESHOLD hash structure, it itself contains threshold hashes returned by parse_threshold()
#  @PRIVACY & USE : PUBLIC, but its use is discouraged. Maybe used directly or as an object instance function.
sub parse_thresholds_list {
   my ($self,$in) = _self_args(@_);
   my $thres = {};
   my @tin = undef;
   my $t = undef;
   my $t2 = undef;

   @tin = split(',', $in);
   $t = uc $tin[0] if exists($tin[0]);
   # old format with =warn,crit thresolds without specifying which one
   if (defined($t) && $t !~ /^WARN/ && $t !~ /^CRIT/ && $t !~ /^ABSENT/ && $t !~ /^ZERO/ &&
	  $t !~ /^DISPLAY/ && $t !~ /^PERF/ && $t !~ /^SAVED/ &&
          $t !~ /^PATTERN/ && $t !~ /^NAME/ && $t !~ /^UOM/) {
	if (scalar(@tin)==2) {
	     if (defined($self)) {
		  $thres->{'WARN'} = $self->parse_threshold($tin[0]);
		  $thres->{'CRIT'} = $self->parse_threshold($tin[1]);
	     }
	     else {
		  $thres->{'WARN'} = parse_threshold($tin[0]);
		  $thres->{'CRIT'} = parse_threshold($tin[1]);
	     }
	}
	else {
	     print "Can not parse. Unknown threshold specification: $in\n";
	     print "Threshold line should be either both warning and critical thresholds separated by ',' or \n";
	     print "new format of: WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL|UNKNOWN\n";
	     print "which allows to specify all 3 (CRIT,WARN,ABSENT) or any one of them in any order\n";
             if (defined($self)) { $self->usage(); }
             exit $ERRORS{"UNKNOWN"};
	}
   }
   # new format with prefix specifying if its WARN or CRIT and support of ABSENT
   else {
	foreach $t (@tin) {
	     $t2 = uc $t;
	     if ($t2 =~ /^WARN\:(.*)/) {
		    if (defined($self)) {
			$thres->{'WARN'} = $self->parse_threshold($1);
		    }
		    else {
			$thres->{'WARN'} = parse_threshold($1);
		    }
	     }
	     elsif ($t2 =~ /^CRIT\:(.*)/) {
		    if (defined($self)) {
			$thres->{'CRIT'} = $self->parse_threshold($1);
		    }
		    else {
			$thres->{'CRIT'} = parse_threshold($1);
		    }
	     }
	     elsif ($t2 =~ /^ABSENT\:(.*)/) {
		    my $val = $1;
		    if (defined($ERRORS{$val})) {
			$thres->{'ABSENT'} = $val;
		    }
		    else {
			print "Invalid value $val after ABSENT. Acceptable values are: OK, WARNING, CRITICAL, UNKNOWN\n";
			if (defined($self)) { $self->usage(); }
			exit $ERRORS{"UNKNOWN"};
		    }
	     }
	     elsif ($t2 =~ /^ZERO\:(.*)/) {
		    my $val = $1;
		    if (exists($ERRORS{$val})) {
			$thres->{'ZERO'} = $val;
		    }
		    else {
			print "Invalid value $val after ZERO. Acceptable values are: OK, WARNING, CRITICAL, UNKNOWN\n";
			if (defined($self)) { $self->usage(); }
			exit $ERRORS{"UNKNOWN"};
		    }
	     }
	     elsif ($t2 =~ /^DISPLAY\:(.*)/) {
		   if ($1 eq 'YES' || $1 eq 'NO') {
			$thres->{'DISPLAY'} = $1;
		   }
		   else {
			print "Invalid value $1 after DISPLAY. Specify this as YES or NO.\n";
			if (defined($self)) { $self->usage(); }
			exit $ERRORS{"UNKNOWN"};
		   }
	     }
	     elsif ($t2 =~ /^PERF\:(.*)/) {
                  if ($1 eq 'YES' || $1 eq 'NO') {
                        $thres->{'PERF'} = $1;
                   }
                   else {
                        print "Invalid value $1 after PERF. Specify this as YES or NO.\n";
                        if (defined($self)) { $self->usage(); }
                        exit $ERRORS{"UNKNOWN"};
                   }
             }
	     elsif ($t =~ /^PATTERN\:(.*)/i) {
		   $thres->{'PATTERN'} = $1;
		   $self->{'enable_regex_match'} = 2 if defined($self) && $self->{'enable_regex_match'} eq 0;
	     }
	     elsif ($t =~ /^NAME\:(.*)/i) {
		   $thres->{'NAME'} = $1;
	     }
	     elsif ($t =~ /^UOM\:(.*)/i) {
		   $thres->{'UOM'} = $1;
	     }
	     else {
		    print "Can not parse. Unknown threshold specification: $_\n";
		    print "Threshold line should be WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL|UNKNOWN,ZERO:OK|WARNING|CRITICAL|UNKNOWN\n";
		    if (defined($self)) { $self->usage(); }
		    exit $ERRORS{"UNKNOWN"};
	     }
	}
   }
   if (exists($thres->{'WARN'}) && exists($thres->{'CRIT'})) {
	  my $check_warncrit = 0;
	  if (defined($self)) {
	      $check_warncrit = $self->threshold_specok($thres->{'WARN'},$thres->{'CRIT'});
	  }
	  else {
	      $check_warncrit = threshold_specok($thres->{'WARN'},$thres->{'CRIT'});
	  }
	  if ($check_warncrit) {
                 print "All numeric warning values must be less then critical (or greater then when '<' is used)\n";
                 print "Note: to override this check prefix warning value with ^\n";
                 if (defined($self)) { $self->usage(); }
                 exit $ERRORS{"UNKNOWN"};
          }
   }
   return $thres;
}

#  @DESCRIPTION   : Adds variable to those whose thresholds would be checked
#  @LAST CHANGED  : 08-27-12 by WL
#  @INPUT         :  ARG1 - name of the data variable
#  		     ARG2 - either:
#			 1) ref to combined thresholds hash array i.e. { 'WARN' => threshold array, 'CRIT' => threshold array, ABSENT => ... }
#                           such hash array is returned by by parse_thresholds_list function
#			 -- OR --
#			 2) a string with a list of thresholds in the format
#			     WARN:threshold,CRIT:thresholod,ABSENT:OK|WARNING|CRITICAL|UNKNOWN,ZERO:WARNING|CRITICAL|UNKNOWN,PATTERN:pattern,NAME:name
# 			    which would get parsed y parse_thresholds_list function into ref array
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, Recommend function for adding thresholds. Must be used as an object instance function
sub add_thresholds {
    my ($self,$var,$th_in) = @_;
    my $th;
    if (ref($th_in) && (exists($th_in->{'WARN'}) || exists($th_in->{'CRIT'}) || exists($th_in->{'DISPLAY'}) ||
		         exists($th_in->{'PERF'}) || exists($th_in->{'SAVED'}) || exists($th_in->{'ABSENT'}) ||
			 exists($th_in->{'ZERO'}) || exists($th_in->{'PATTERN'}))) {
	$th = $th_in;
    }
    else {
	$th = $self->parse_thresholds_list($th_in);
    }
    if (!defined($var)) {
	if (defined($th->{'NAME'})) {
	    $var = $th->{'NAME'};
	}
	elsif (defined($th->{'PATTERN'})) {
	    $var = $th->{'PATTERN'};
	}
	else {
	    print "Can not parse. No name or pattern in threshold: $th_in\n";
	    print "Specify threshold line as:  NAME:name,PATTERN:regex,WARN:threshold,CRIT:threshold,ABSENT:OK|WARNING|CRITICAL|UNKNOWN,ZERO:OK|WARNING|CRITICAL|UNKNOWN\n";
	    $self->usage();
	    exit $ERRORS{"UNKNOWN"};
	}
    }
    push @{$self->{'_allVars'}}, $var if !exists($self->{'_thresholds'}{$var});
    $self->{'_thresholds'}{$var}=$th;
}

#  @DESCRIPTION   : Accessor function for thresholds and related variable settings on what and how to check
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : ARG1 - name of data variable
#                   ARG2 - name of the threshold or related data setting to return
#		           This can be: "WARN", "CRIT", "ABSENT", "ZERO", "DISPLAY", "PERF"
#  @RETURNS       : undef if variable does not exist
#  		    if variable exists and "WARN" or "CRIT" thresholds are requested, it returns asociated
#  		    threshold hash array structure for named threshold of the type returned by parse_threshold()
#                   for ABSENT, ZERO, DISPLAY, PERF and other, it returns a string for this check setting
#  @PRIVACY & USE : PUBLIC, Must be used as an object instance function
sub get_threshold {
    my ($self,$var,$thname) = @_;
    return undef if !exists($self->{'_thresholds'}{$var}) || !exists($self->{'_thresholds'}{$var}{$thname});
    return $self->{'_thresholds'}{$var}{$thname};
}

#  @DESCRIPTION   : Modifier function for thresholds and related variable settings on how to check and display results
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : ARG1 - name of data variable
#                   ARG2 - type of the threshold or related data setting
#		           This can be: "WARN", "CRIT", "ABSENT", "ZERO", "DISPLAY", "PERF"
#                   ARG3 - what to set this to, for "WARN" and "CRIT" this must be hash array returned by parse_threshold()
#  @RETURNS       : 0 if type you want to set is not one of "WARN", "CRIT", "ZERO" or other acceptable settings
#  		    1 on success
#  @PRIVACY & USE : PUBLIC, Must be used as an object instance function
sub set_threshold {
    my ($self,$var,$thname,$thdata) = @_;
    if ($thname ne 'WARN' && $thname ne 'CRIT' && $thname ne 'ZERO' && $thname ne 'PATTERN' && $thname ne 'NAME' &&
        $thname ne 'ABSENT' && $thname ne 'PERF' && $thname ne 'DISPLAY' && $thname ne 'SAVED' && $thname ne 'UOM') {
       return 0;
    }
    $self->{'_thresholds'}{$var}={} if !exists($self->{'_thresholds'}{$var});
    $self->{'_thresholds'}{$var}{$thname}=$thdata;
    return 1;
}

#  @DESCRIPTION   : Returns list variables for GetOptions(..) that are long-options based on known/defined variable
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : none
#  @RETURNS       : Array of additional options based on KNOWN_STATS_VARS
#  @PRIVACY & USE : PUBLIC, Special use case with GetOpt::Long. Must be used as an object instance function
sub additional_options_list {
    my $self = shift;

    my $known_vars = $self->{'knownStatusVars'};
    my ($o_rprefix, $o_rsuffix, $v, $v2) = ('','','','');
    $o_rprefix = $self->{'o_rprefix'} if defined($self->{'o_rprefix'});
    $o_rsuffix = $self->{'o_rsuffix'} if defined($self->{'o_rsuffix'});
    my @VarOptions = ();

    if ($self->{'enable_long_options'} != -1) {
      if (defined($self) && defined($known_vars)) {
	foreach $v (keys %{$known_vars}) {
	  if (exists($known_vars->{$v}[3]) && $known_vars->{$v}[3] ne '') {
              push @VarOptions,$v."=s";
	      if ($self->{'enable_rate_of_change'} eq 1 && $known_vars->{$v}[1] eq 'COUNTER' && ($o_rprefix ne '' || $o_rsuffix ne '')) {
		   $v2 = $o_rprefix.$v.$o_rsuffix;
		   push @VarOptions,$v2."=s"
	      }
	  }
	}
      }
    }
    if (scalar(@VarOptions)>0) {
      $self->{'enable_long_options'} = 1;
    }
    return @VarOptions;
}

#  @DESCRIPTION   : Prints out help for generated long options
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : none
#  @RETURNS       : a string of text for help output
#  @PRIVACY & USE : PUBLIC, Special use case with GetOpt::Long. Must be used as an object instance function
sub additional_options_help {
  my $self = shift;
  my $vname;
  my $vname2;
  my $counter = 0;
  my $known_vars = $self->{'knownStatusVars'};

  if ($self->{'enable_long_options'} != 1) { return ''; }

  my $out="   These options are all --long_name=<list of specifiers separated by ,>
   where specifiers are one or more of:
     WARN:threshold  - warning alert threshold
     CRIT:threshold  - critical alert threshold
       Threshold is a value (usually numeric) which may have the following prefix:
         > - warn if data is above this value (default for numeric values)
         < - warn if data is below this value (must be followed by number)
         = - warn if data is equal to this value (default for non-numeric values)
         ! - warn if data is not equal to this value
       Threshold can also be specified as a range in two forms:
         num1:num2  - warn if data is outside range i.e. if data<num1 or data>num2
         \@num1:num2 - warn if data is in range i.e. data>=num1 && data<=num2
     ABSENT:OK|WARNING|CRITICAL|UNKNOWN - Nagios alert (or lock of thereof) if data is absent
     ZERO:OK|WARNING|CRITICAL|UNKNOWN   - Nagios alert (or lock of thereof) if result is 0
     DISPLAY:YES|NO - Specifies if data should be included in nagios status line output
     PERF:YES|NO    - Output results as performance data or not (always YES if asked for rate)
     NAME:<string>  - Change the name to <string> in status and PERF output\n\n";

  # add more options based on KNOWN_STATUS_VARS array
  foreach $vname (keys(%{$known_vars})) {
     if (exists($known_vars->{$vname}[3])) {
	$counter++;
	$out .= ' --'.$vname."=WARN:threshold,CRIT:threshold,<other specifiers>\n";
	$out .= "   ".$known_vars->{$vname}[3]."\n";
	if ($known_vars->{$vname}[1] eq 'COUNTER' && $self->{'enable_rate_of_change'} eq 1) {
	    $vname2=$o_rprefix.$vname.$o_rsuffix;
	    $out .= ' --'.$vname2."=WARN:threshold,CRIT:threshold,<other specifiers>\n";
	    $out .= "   Rate of Change of ".$known_vars->{$vname}[3]."\n";
	}
     }
  }
  if ($counter>0) { return $out; }
  return "";
}

#  @DESCRIPTION   : Processes standard options parsing out of them variables to be checked
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : ARG1 - Options data hash from GetOpt::Long
#		    ARG2 - option --verbose or -v or --debug : undef normally and "" or filename if debug enabled
#		    ARG3 - option --variables or -a in WL's plugins : comma-separated list of variables to check
#		    ARG4 - option --warn or -w : comma-separated warning thresholds for variables in ARG3
#		    ARG5 - option --crit or -c : comma-separated critical thresholds for variables in ARG3
#		    ARG6 - option --perf or -f in WL's plugin: all regular variables should also go to perf data
#		    ARG7 - option --perfvars or -A in WL's plugins: command-separated list of variables whose data goes to PERF output
#		    ARG8 - prefix to distinguish rate variables, maybe "" but usually this is "rate_"
#		    ARG9 - suffix to distinguish rate variables, only if ARG7 is "", otherwise optional and absent
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, To be used shortly after GetOptions. Must be used as an object instance function
sub options_startprocessing {
    my ($self, $Options, $o_verb, $o_variables, $o_warn, $o_crit, $o_perf, $o_perfvars, $o_rprefix, $o_rsuffix) = @_;

    # Copy input parameters to object hash array, set them if not present
    $o_rprefix="" if !defined($o_rprefix);
    $o_rsuffix="" if !defined($o_rsuffix);
    $o_crit="" if !defined($o_crit);
    $o_warn="" if !defined($o_warn);
    $o_variables="" if !defined($o_variables);
    $self->{'o_variables'} = $o_variables;
    $self->{'o_perfvars'} = $o_perfvars;
    $self->{'o_crit'} = $o_crit;
    $self->{'o_warn'} = $o_warn;
    $self->{'o_perf'} = $o_perf;
    $self->{'o_rprefix'} = $o_rprefix;
    $self->{'o_rsuffix'} = $o_rsuffix;
    $self->{'verbose'} = $o_verb if defined($o_verb);
    # start processing
    my $perfVars = $self->{'_perfVars'};
    my $ar_varsL = $self->{'_ar_varsL'};
    my $ar_critLv = $self->{'_ar_critLv'};
    my $ar_warnLv = $self->{'_ar_warnLv'};
    my $known_vars = $self->{'knownStatusVars'};
    $o_rprefix = lc $o_rprefix;
    $o_rsuffix = lc $o_rsuffix;
    # process o_perfvars option
    if (defined($o_perfvars)) {
	@{$perfVars} = split( /,/ , lc $o_perfvars );
 	if (scalar(@{$perfVars})==0) {
		$o_perfvars='*';
		$self->{'o_perfvars'}='*';
	}
	if ($o_perfvars eq '*') {
		$self->{'all_variables_perf'} = 1;
	}
	else {
		# below loop converts rate variables to internal representation
		for (my $i=0; $i<scalar(@{$perfVars}); $i++) {
			$perfVars->[$i] = '&'.$1 if $perfVars->[$i] =~ /^$o_rprefix(.*)$o_rsuffix$/;
		}
	}
    }
    if (defined($o_warn) || defined($o_crit) || defined($o_variables)) {
	if (defined($o_variables)) {
	  @{$ar_varsL}=split( /,/ , lc $o_variables );
	  if (defined($o_warn)) {
	     $o_warn.="~" if $o_warn =~ /,$/;
	     @{$ar_warnLv}=split( /,/ , lc $o_warn );
	  }
	  if (defined($o_crit)) {
	     $o_crit.="~" if $o_crit =~ /,$/;
    	     @{$ar_critLv}=split( /,/ , lc $o_crit );
	  }
	}
	else {
	  print "Specifying warning or critical thresholds requires specifying list of variables to be checked\n";
	  if (defined($self)) { $self->usage(); }
	  exit $ERRORS{"UNKNOWN"};
	}
    }
    # this is a special loop to check stats-variables options such as "connected_clients=WARN:warning,CRIT:critical"
    # which are specified as long options (new extended threshold line spec introduced in check_redis and check_memcached)
    my ($vname,$vname2) = (undef,undef);
    foreach $vname (keys(%{$known_vars})) {
	$vname2=$o_rprefix.$vname.$o_rsuffix;
	if (exists($known_vars->{$vname}[3])) {
	    if (exists($Options->{$vname})) {
		 $self->verb("Option $vname found with spec parameter: ".$Options->{$vname});
		 $self->add_thresholds($vname,$Options->{$vname});
	    }
	    if (exists($Options->{$vname2})) {
		 $self->verb("Rate option $vname2 found with spec parameter: ".$Options->{$vname2});
		 $self->add_thresholds('&'.$vname,$Options->{$vname2});
	    }
	}
    }
    $self->{'_called_options_startprocessing'}=1;
}

#  @DESCRIPTION   : Internal function. Parses and sets thresholds for given list of variables after all options have been processed
#  @LAST CHANGED  : 08-20-12 by WL
#  @INPUT         : none
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PRIVATE, Must be used as an object instance function
sub _options_setthresholds {
    my $self = shift;

    my $perfVars = $self->{'_perfVars'};
    my $ar_varsL = $self->{'_ar_varsL'};
    my $ar_critLv = $self->{'_ar_critLv'};
    my $ar_warnLv = $self->{'_ar_warnLv'};
    my $known_vars = $self->{'knownStatusVars'};
    my $thresholds = $self->{'_thresholds'};
    my ($o_rprefix, $o_rsuffix) = ("", "");
    $o_rprefix = $self->{'o_rprefix'} if exists($self->{'o_rprefix'});
    $o_rsuffix = $self->{'o_rsuffix'} if exists($self->{'o_rsuffix'});

    if (scalar(@{$ar_warnLv})!=scalar(@{$ar_varsL}) || scalar(@{$ar_critLv})!=scalar(@{$ar_varsL})) {
	  printf "Number of specified warning levels (%d) and critical levels (%d) must be equal to the number of attributes specified at '-a' (%d). If you need to ignore some attribute do it as ',,'\n", scalar(@{$ar_warnLv}), scalar(@{$ar_critLv}), scalar(@{$ar_varsL});
	  $self->verb("Warning Levels: ".join(",",@{$ar_warnLv}));
	  $self->verb("Critical Levels: ".join(",",@{$ar_critLv}));
	  if (defined($self)) { $self->usage(); }
	  exit $ERRORS{"UNKNOWN"};
    }
    for (my $i=0; $i<scalar(@{$ar_varsL}); $i++) {
	  $ar_varsL->[$i] = '&'.$1 if $ar_varsL->[$i] =~ /^$o_rprefix(.*)$o_rsuffix$/;
	  if ($ar_varsL->[$i] =~ /^&(.*)/) {
		if (!defined($self->{'o_prevperf'})) {
			print "Calculating rate variable such as ".$ar_varsL->[$i]." requires previous performance data. Please add '-P \$SERVICEPERFDATA\$' to your nagios command line.\n";
			if (defined($self)) { $self->usage(); }
			exit $ERRORS{"UNKNOWN"};
		}
		if (defined($known_vars->{$1}) && $known_vars->{$1}[0] ne 'COUNTER') {
                	print "$1 is not a COUNTER variable for which rate of change should be calculated\n";
			if (defined($self)) { $self->usage(); }
                	exit $ERRORS{"UNKNOWN"};
		}
	  }
	  if (!exists($thresholds->{$ar_varsL->[$i]})) {
	      my $warn = $self->parse_threshold($ar_warnLv->[$i]);
	      my $crit = $self->parse_threshold($ar_critLv->[$i]);
	      if ($self->threshold_specok($warn,$crit)) {
                 print "All numeric warning values must be less then critical (or greater then when '<' is used)\n";
                 print "Note: to override this check prefix warning value with ^\n";
                 if (defined($self)) { $self->usage(); }
                 exit $ERRORS{"UNKNOWN"};
	      }
	      $self->add_thresholds($ar_varsL->[$i], {'WARN'=>$warn,'CRIT'=>$crit} );
	  }
    }
}

#  @DESCRIPTION   : Internal helper function. Finds time when previous performance data was calculated/saved at
#  @DEVNOTE	  : Right now this library and function only supports one previous performance data set,
#		    but check_snmp_netint plugin supports multiple sets and its code is more complex,
#		    As this function originated there, that code is commented out right now.
#  @LAST CHANGED  : 08-21-12 by WL
#  @INPUT         :  ARG1 - reference to previous performance data hash array. It looks for _ptime variable there.
#		     ARG2 - string with previous performance time in unix seconds. This may come from separate plugin option.
#  @RETURNS       : Time in unix seconds frm 1970 or undef if it was not located
#  @PRIVACY & USE : PRIVATE, Maybe used directly or as an object instance function.
sub _set_prevtime {
    my ($self,$prevperf,$o_prevtime) = _self_args(@_);
    my $perfcheck_time;

    if (defined($o_prevtime)) {
         # push @prev_time, $o_prevtime;
         # $prev_perf{ptime}=$o_prevtime;
	 $perfcheck_time=$o_prevtime;
    }
    elsif (defined($prevperf) && defined($prevperf->{'_ptime'})) {
	 # push @prev_time, $prev_perf{ptime};
	 $perfcheck_time=$prevperf->{'_ptime'};
    }
    else {
         # @prev_time=();
	 $perfcheck_time=undef;
    }
    # numeric sort for timestamp array (this is from lowest time to highiest, i.e. to latest)
    # my %ptimes=();
    # $ptimes{$_}=$_ foreach @prev_time;
    # @prev_time = sort { $a <=> $b } keys(%ptimes);
    return $perfcheck_time;
}

#  @DESCRIPTION   : Processes standard options, setting up thresholds based on options that are to be checked
#  @LAST CHANGED  : 08-22-12 by WL
#  @INPUT         : none
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, To be called after plugin finished processing its own custom options. Must be used as an object instance function
sub options_finishprocessing {
    my $self = shift;

    if (!exists($self->{'_called_options_finishprocessing'})) {
	# process previous performance data
	my $prevperf = $self->{'_prevPerf'};
	if (defined($self->{'o_prevperf'})) {
	      if (defined($self->{'o_perf'}) || defined($self->{'o_perfvars'})) {
		    %{$prevperf}=$self->process_perf($self->{'o_prevperf'});
		    $self->{'_perfcheck_time'} = $self->_set_prevtime($prevperf,$self->{'o_prevtime'});
	      }
	      else {
		    print "--prevperf can only be used with --perf or --perfvars options\n";
		    if (defined($self)) { $self->usage(); }
		    exit $ERRORS{"UNKNOWN"};
	      }
	}
	# set thresholds
	$self->_options_setthresholds();
        # prepare data results arrays
	my $dataresults = $self->{'_dataresults'};
	my $thresholds = $self->{'_thresholds'};
	$dataresults->{$_} = [undef, 0, 0] foreach(@{$self->{'_allVars'}});
	if (defined($self->{'_perfVars'})) {
	    foreach(@{$self->{'_perfVars'}}) {
		$dataresults->{$_} = [undef, 0, 0] if !exists($dataresults->{$_});
		$thresholds->{$_} = {} if !exists($thresholds->{$_});
		$thresholds->{$_}{'PERF'} = 'YES';
	    }
	}
	# mark as having finished
	$self->{'_called_options_finishprocessing'}=1;
    }
}

#  @DESCRIPTION   : Accessor function for previously saved perfdata
#  @LAST CHANGED  : 08-22-12 by WL
#  @INPUT         : ARG1 - varname
#  @RETURNS       : value of that variable on previous plugin run, undef if not known
#  @PRIVACY & USE : PUBLIC, Must be used as an object instance function
sub prev_perf {
    my ($self,$var) = @_;
    if (defined($self) && defined($self->{'_prevPerf'}{$var})) {
        return $self->{'_prevPerf'}{$var};
    }
    return undef;
}

#  @DESCRIPTION   : Accessor function for exit status code
#  @LAST CHANGED  : 08-21-12 by WL
#  @INPUT         : none
#  @RETURNS       : current expected exit status code
#  @PRIVACY & USE : PUBLIC, Must be used as an object instance function
sub statuscode {
    my $self = shift;
    return $self->{'_statuscode'};
}

#  @DESCRIPTION   : Sets plugin exist status
#  @LAST CHANGED  : 08-21-12 by WL
#  @INPUT         : status code string - one of "WARNING", "CRITICAL", "UNKNOWN".
#  @RETURNS       : 0 on success, 1 if this status code is below level that plugin would exit with and as such it was not set
#  @PRIVACY & USE : PUBLIC, Must be used as an object instance function
sub set_statuscode {
    my ($self,$newcode) = @_;

    if ($newcode eq 'UNKNOWN') {
        $self->{'_statuscode'} = 'UNKNOWN';
        return 0;
    }
    if ($self->{'_statuscode'} eq 'UNKNOWN') { return 1; }
    elsif ($self->{'_statuscode'} eq 'CRITICAL') {
        if ($newcode eq 'CRITICAL') { return 0;}
        else { return 1; }
    }
    elsif ($self->{'_statuscode'} eq 'WARNING') {
        if ($newcode eq 'CRITICAL') {
	    $self->{'_statuscode'} ='CRITICAL';
	    return 0;
        }
        elsif ($newcode eq 'WARNING') { return 0; }
        else { return 1; }
    }
    elsif ($self->{'_statuscode'} eq 'OK') {
        if ($newcode eq 'CRITICAL' || $newcode eq 'WARNING') {
	    $self->{'_statuscode'} = $newcode;
	    return 0;
        }
        else { return 1; }
    }
    else {
        printf "SYSTEM ERROR: status code $newcode not supported";
        exit $ERRORS{'UNKNOWN'};
    }
    return 1; # should never get here
}

#  @DESCRIPTION   : This function is called closer to end of the code after plugin retrieved data and
#		    assigned values to variables. This function checks variables against all thresholds.
#		    It prepares statusdata and statusinfo and exitcode.
#  @LAST CHANGED  : 09-03-12 by WL
#  @INPUT         : none
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, To be called after variables have values. Must be used as an object instance function
sub main_checkvars {
    my $self = shift;

    $self->options_finishprocessing() if !exists($self->{'_called_options_finshprocessing'});
    if (exists($self->{'_called_main_checkvars'})) { return; }

    my $thresholds = $self->{'_thresholds'};
    my $dataresults = $self->{'_dataresults'};
    my $allVars = $self->{'_allVars'};
    my $datavars = $self->{'_datavars'};

    my ($dvar,$avar,$aname,$perf_str,$chk)=(undef,undef,undef,undef,undef);

    # main loop to check for warning & critical thresholds
    for (my $i=0;$i<scalar(@{$allVars});$i++) {
	$avar = $allVars->[$i];
	if (!defined($datavars->{$avar}) || scalar(@{$datavars->{$avar}})==0) {
	    if (defined($thresholds->{$avar}{'ABSENT'})) {
                $self->set_statuscode($thresholds->{$avar}{'ABSENT'});
            }
            else {
                $self->set_statuscode("CRITICAL");
            }
	    $aname = $self->out_name($avar);
            $self->addto_statusinfo_output($avar, "$aname data is missing");
        }
	foreach $dvar (@{$datavars->{$avar}}) {
	    $aname = $self->out_name($dvar);
	    if (defined($dataresults->{$dvar}[0])) {
		# main check
		if (defined($avar)) {
		    if ($dataresults->{$dvar}[0] eq 0 && exists($thresholds->{$avar}{'ZERO'})) {
			$self->set_statuscode($thresholds->{$avar}{'ZERO'});
			$self->addto_statusinfo_output($dvar, "$aname is zero") if $self->statuscode() ne 'OK';
		    }
		    else {
			$chk=undef;
			if (exists($thresholds->{$avar}{'CRIT'})) {
			    $chk = $self->check_threshold($aname,lc $dataresults->{$dvar}[0], $thresholds->{$avar}{'CRIT'});
			    if ($chk) {
				$self->set_statuscode("CRITICAL");
				$self->addto_statusinfo_output($dvar,$chk);
			    }
			}
			if (exists($thresholds->{$avar}{'WARN'}) && (!defined($chk) || !$chk)) {
			    $chk = $self->check_threshold($aname,lc $dataresults->{$dvar}[0], $thresholds->{$avar}{'WARN'});
			    if ($chk) {
				$self->set_statuscode("WARNING");
				$self->addto_statusinfo_output($dvar,$chk);
			    }
			}
		    }
		}
		# if we did not output to status line yet, do so
		$self->addto_statusdata_output($dvar,$aname." is ".$dataresults->{$dvar}[0]);

		# if we were asked to output performance, prepare it but do not output until later
		if ((defined($self->{'o_perf'}) && defined($avar) && !exists($thresholds->{$avar}{'PERF'})) ||
		    (exists($thresholds->{$avar}{'PERF'}) && $thresholds->{$avar}{'PERF'} eq 'YES')) {
			$perf_str = perf_name($aname).'='.$dataresults->{$dvar}[0];
			$self->set_perfdata($dvar, $perf_str, undef, "IFNOTSET"); # with undef UOM would get added
			$dataresults->{$dvar}[2]=0; # this would clear -1 from preset perf data, making it ready for output
			# below is where threshold info gets added to perfdata
			if ((exists($thresholds->{$avar}{'WARN'}[5]) && $thresholds->{$avar}{'WARN'}[5] ne '') ||
			    (exists($thresholds->{$avar}{'CRIT'}[5]) && $thresholds->{$avar}{'CRIT'}[5] ne '')) {
				$perf_str = ';';
				$perf_str .= $thresholds->{$avar}{'WARN'}[5] if exists($thresholds->{$avar}{'WARN'}[5]) && $thresholds->{$avar}{'WARN'}[5] ne '';
				$perf_str .= ';'.$thresholds->{$avar}{'CRIT'}[5] if exists($thresholds->{$avar}{'CRIT'}[5]) && $thresholds->{$avar}{'CRIT'}[5] ne '';
				$self->set_perfdata($dvar, $perf_str, '', "ADD");
			}
		}
	    }
	}
    }
    $self->{'_called_main_checkvars'}=1;
    # $statusinfo=trim($statusinfo);
    # $statusdata=trim($statusdata);
}

#  @DESCRIPTION   : This function is at the end. It prepares PERFOUT for output collecting all perf variables data
#  @LAST CHANGED  : 08-26-12 by WL
#  @INPUT         : none
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, To be called after variables have values. Must be used as an object instance function
#		    Calling this function direcly is optional, its automatically called on 1st call to perfdata()
sub main_perfvars {
    my $self = shift;

    my $dataresults = $self->{'_dataresults'};
    my $PERF_OK_STATUS_REGEX = $self->{'perfOKStatusRegex'};
    my $perfVars = $self->{'_perfVars'};
    my $known_vars = $self->{'knownStatusVars'};
    my $datavars = $self->{'_datavars'};
    my $avar;
    my $dvar;

    $self->main_checkvars() if !exists($self->{'_called_main_checkvars'});
    if (exists($self->{'_called_main_perfvars'})) { return; }

    for (my $i=0;$i<scalar(@{$perfVars});$i++) {
	$avar=$perfVars->[$i];
	if (!defined($datavars->{$avar}) || scalar(@{$datavars->{$avar}})==0) {
		$self->verb("Perfvar: $avar selected for PERFOUT but data not available");
	}
	else {
	    foreach $dvar (@{$datavars->{$avar}}) {
	    	if (defined($dataresults->{$dvar}[0])) {
		    $self->verb("Perfvar: $dvar ($avar) = ".$dataresults->{$dvar}[0]);
	            if (!defined($known_vars->{$avar}[1]) || $known_vars->{$avar}[1] =~ /$PERF_OK_STATUS_REGEX/ ) {
			$self->addto_perfdata_output($dvar);
		    }
		    else {
			$self->verb(" -- not adding to perfdata because of it is '".$known_vars->{$avar}[1]."' type variable --");
		    }
	        }
	        else {
		    $self->verb("Perfvar: $avar selected for PERFOUT but data not defined");
	        }
	    }
	}
    }
    if (defined($self->{'o_prevperf'})) {
        $self->addto_perfdata_output('_ptime', "_ptime=".time(), "REPLACE");
    }
    foreach $dvar (keys %{$dataresults}) {
        if (defined($dataresults->{$dvar}[3]) && $dataresults->{$dvar}[3] ne '') {
	    $self->verb("Perfvar (Dataresults Loop): $dvar => ".$dataresults->{$dvar}[3]);
            $self->addto_perfdata_output($dvar);
        }
    }

    $self->{'_called_main_perfvars'}=1;
    # $perfdata = trim($perfdata);
}

#  @DESCRIPTION   : This function should be called at the very very end, it returns perf data output
#  @LAST CHANGED  : 08-22-12 by WL
#  @INPUT         : none
#  @RETURNS       : string of perfdata starting with "|"
#  @PRIVACY & USE : PUBLIC, To be called during plugin output. Must be used as an object instance function
sub perfdata {
    my $self=shift;

    $self->main_perfvars() if !exists($self->{'_called_main_perfvars'});
    my $perfdata = trim($self->{'_perfdata'});
    if ($perfdata ne '') {
	return " | " . $perfdata;
    }
    return "";
}

#  @DESCRIPTION   : This function is called after data is available and calculates rate variables
#		    based on current and previous (saved in perfdata) values.
#  @LAST CHANGED  : 08-27-12 by WL
#  @INPUT         : none
#  @RETURNS       : nothing (future: 1 on success, 0 on error)
#  @PRIVACY & USE : PUBLIC, To be called after variables have values. Must be used as an object instance function
sub calculate_ratevars {
    my $self = shift;

    my $prev_perf = $self->{'_prevPerf'};
    my $ptime = $self->{'_perfcheck_time'};
    my $thresholds = $self->{'_thresholds'};
    my $dataresults = $self->{'_dataresults'};
    my $datavars = $self->{'_datavars'};
    my $allVars = $self->{'_allVars'};

    my ($avar,$dvar,$nvar) = (undef,undef,undef);
    my $timenow=time();
    if (defined($self->{'o_prevperf'}) && (defined($self->{'o_perf'}) || defined($self->{'o_perfvars'}))) {
	for (my $i=0;$i<scalar(@{$allVars});$i++) {
	    if ($allVars->[$i] =~ /^&(.*)/) {
		$avar = $1;
		if (defined($datavars->{$avar}) && scalar(@{$datavars->{$avar}})>0) {
		    foreach $dvar (@{$datavars->{$avar}}) {
			$nvar = '&'.$dvar;
			# this forces perfdata output if it was not already
			if (defined($dataresults->{$dvar}) && $dataresults->{$dvar}[2]<1 &&
			    (!defined($dataresults->{$dvar}[3]) || $dataresults->{$dvar}[3] eq '')) {
				$self->set_perfdata($dvar, perf_name($self->out_name($dvar)).'='.$dataresults->{$dvar}[0], undef, "IFNOTSET");
				$self->set_threshold($dvar,'PERF','YES');
				$self->set_threshold($dvar,'SAVED','YES');  # will replace PERF in the future
			}
			if (defined($prev_perf->{$dvar}) && defined($ptime)) {
			    $self->add_data($nvar,
			      sprintf("%.2f",($dataresults->{$dvar}[0]-$prev_perf->{$dvar})/($timenow-$ptime)));
			    $self->verb("Calculating Rate of Change for $dvar ($avar) : ".$nvar."=". $self->vardata($nvar));
			}
		    }
		}
	    }
	}
    }
}

#  @DESCRIPTION   : Function provides plugin name for output. Similar/Same as Nagios::Plugins get_shortname
#  @LAST CHANGED  : 09-05-12 by WL
#  @INPUT         : none
#  @RETURNS       : returns string with a name
#  @PRIVACY & USE : PUBLIC, Maybe used directly or as an object instance function
sub get_shortname {
    my ($self) = _self_args(@_);
    my $name = "";

    if (defined($self) && defined($self->{'plugin_name'})) {
        $name = $self->{'plugin_name'};
    }
    else {
        $name = uc basename( $ENV{NAGIOS_PLUGIN} || $0 );
    }
    $name=$1 if $name =~ /^check(.*)/;
    $name=$1 if $name =~ /(.*)\.(.*)$/;
    return $name;
}

#  @DESCRIPTION   : Functions for those who don't need complex functionality. Similar to Nagios::Plugins nagios_exit and nagios_die functions.
#		    It is by itself and not used by any other library functions.
#  @LAST CHANGED  : 09-05-12 by WL
#  @INPUT         : --- nagios_exit ---
#		  : ARG1 - "OK", "WARNING", "CRITICAL" or "UNKNOWN"
#		  : ARG2 - string to exit with
#		  ; --- nagios_die ----
#		  : ARG1 - string to exit with
#		  : ARG2 - "OK", "WARNING", "CRITICAL" or "UNKNOWN"
#  @RETURNS       : these functions exists/terminate execution
#  @PRIVACY & USE : PUBLIC, Maybe used directly or as an object instance function
sub nagios_exit {
    my ($self, $code, $line) = _self_args(@_);
    my $name = "";
    if (defined($self)) {
        $name = $self->get_shortname();
    }
    else {
        $name = get_shortname();
    }
    $code = "UNKNOWN" if !defined($ERRORS{$code});
    print $name ." ".$code;
    print " - ".$line if defined($line);
    exit $ERRORS{$code};
}

sub nagios_die {
    my ($self, $line, $code) = _self_args(@_);
    nagios_exit($code, $line);
}

#  @DESCRIPTION   : Function replicates functionality of same named Nagios::Plugins. See:
#		    http://search.cpan.org/~tonvoon/Nagios-Plugin/lib/Nagios/Plugin/Functions.pm
#		    It is by itself and not used by any other library functions.
#  @LAST CHANGED  : 09-05-12 by WL
#  @INPUT         : The following possible hash input keys:
#			'critical' => ARRAYREF   - list of critical status messages
#			'warning'  => ARRAYREF  - list of warning status messages
#			'ok => ARRAYREF 	- array of ok  info
#			'join' => str 	- does join on relevant type of message using str
#			'join_all'str   - join on all types
#  @RETURNS       : returns array of 2 arguments, first is an error code (OK, WARNING, CRITICAL) and 2nd is message
#  @PRIVACY & USE : PUBLIC, Maybe used directly or as an object instance function
sub check_messages {
    my @all_args = _self_ars(@_);
    my $self = shift @all_args
    my %args = @all_args;
    my $ar_warn = [];
    my $ar_crit = [];
    my $ar_ok = [];
    my $ret_code = "OK";
    my $ret_msg_warn = "";
    my $ret_msg_crit = "";
    my $ret_msg_ok = "";
    my $ret_msg = "";
    my $join = " ";

    $join = $args{'join'} if exists($args{'join'};
    $join = $args{'join_all'} if exists($args{'join_all'};
    if (exists($args{'warning'})) {
	$ar_warn = $args{'warning'};
	$ret_msg_warn = join($join,@{$ar_warn});
    }
    if (exists($args{'critical'})) {
	$ar_crit = $args{'critical'};
	$ret_msg_crit = join($join,@{$ar_warn});
    }
    if (exists($args{'ok'})) {
	if (ref($args{'ok'}) {
	    $ar_ok = $args{'ok'};
	}
	else {
	    $ar_ok->[0] = $args{'ok'};
	}
	$ret_msg_ok = join($join,@{$ar_ok});
    }
    if (scalar(@{$ar_crit})>0) {
	$ret_code = "CRITICAL";
	$ret_msg = $ret_msg_crit;
    }
    elsif (scalar(@{ar_warn})>0) {
	$ret_code = "WARNING";
	$ret_msg = $ret_msg_warn;
    }
    else {
	$ret_code = "OK"
	$ret_msg = $ret_msg_ok;
    }
    if (exists($args{'join_all'})) {
	$ret_msg = join($join,($ret_msg_crit,$ret_msg_warn,$ret_msg_ok));
    }
    return ($ret_code,$ret_msg);
}

##################################### END OF THE LIBRARY FUNCTIONS #########################################
