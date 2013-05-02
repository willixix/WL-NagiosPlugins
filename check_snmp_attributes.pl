#!/usr/bin/perl -w
#
# Help : ./check_snmp_attributes.pl -h
#
# ============================== SUMMARY =====================================
#
# Program : check_snmp_attributes.pl
# Version : 0.32
# Date    : December 22,2011
#           (most of the code from 2008, I lost original repository with version history)
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
# ===================== INFORMATION ABOUT THIS LIBRARY =========================
#
# I'm afraid I do not have the time to write documention. This is basically an
# experimental library I was working on in 2008 to make it easier to write plugins
# similar to ones I've written without really writing any plugin code and just
# defining how data is retrieved. It started from the code from I believe a
# check_snmp_temperature plugin and then extended to basically build a virtual
# machine insider perl to interpret syntax for defining data values.
#
# The syntax is an expression in a reverse polish notation as with HP calculators
# with a stack used for data processing. If you scroll down to the end of this file
# (which is what I recommend instead of reading top-bottom) you will see definitions
# of these operators which are based on name and regex; note that numeric data is
# also one of the operators. Operators can be overloaded, with right one chosen
# depending on what is on stack (so one '+' is used to add two numeric values and
# another '+' operator to conctatenate strings).
#
# Its all very cool and all but I decided it got too complex for its own good and
# its easier to just write plugins in perl as I did before. However I did write
# SNMP Memory plugin using this library and had installed it in places with
# many thousands of servers so library appears to be stable and working fine
# although I'm sure it has plenty of bugs if you start extending it further
# so it should be considered EXPERIMENTAL.
#
# I've no immediate plans to develop this further right now but I decided its worth
# being released to the public. Perhaps others will find it an interesting project
# and want to either write their own plugins with this or develop this further.
#
# VERSION HISTORY:
#  0.2x - 2007 & 2008  : Original development, I lost repository with version history
#  0.31 - Mar 18, 2009 : Bug fixes, dont remember. This version is considered stable,
#			 no major issues on several different client instalations.
#  0.32 - Dec 10, 2011 : Added full support for SNMP v3, added this doc header
#			 first release to public planned around Dec 22, 20011
#
# ===============================================================================

use strict;
use Getopt::Long;

# Nagios Perl Attributes Library (Napal) is likely name for future library based on this plugin
# package Napal;

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

# Globals

my $Version='0.32';

my $o_host = 	undef; 		# hostname
my $o_help=	undef; 		# wan't some help ?
my $o_verb=	undef;		# verbose mode (base level1 verbose)
my $o_vdebug=   -1;             # same as above but specifies actual level as integer
my $o_version=	undef;		# print version
my $o_timeout=  5;             	# Default 5s Timeout

my $o_port =            161;    # SNMP port
my $o_community =       undef;  # community
my $o_version2  =       undef;  # use snmp v2c
my $o_login=            undef;  # Login for snmpv3
my $o_passwd=           undef;  # Pass for snmpv3
my $v3protocols=        undef;  # V3 protocol list.
my $o_authproto=        'md5';  # Auth protocol
my $o_privproto=        'des';  # Priv protocol
my $o_privpass=         undef;  # priv password

my $o_perf=     undef;          # Performance data option
my $o_attr=	undef;  	# What attribute(s) to check (specify more then one separated by '.')
my @o_attrL=    ();             # array for above list
my $o_perfattr= undef;		# List of attributes to only provide values in perfomance data but no checking
my @o_perfattrL=();		# array for above list
my $o_warn=     undef;          # warning level option
my @o_warnL=    ();              # array of warning values (array of hashes really)
my $o_crit=     undef;          # Critical level option
my @o_critL=    ();             # array of critical values
my $o_dispattr= undef;          # List of attributes that would be displayed but not checked
my @o_dispattrL=();             # array of display-only attributes
my $o_unkdef=	undef;		# Default value to report for unknown attributes
my $o_label=    '';             # Label used to show what is in plugin output
my $o_confexpr= undef;          # Config expression
my $o_enfwcnum= undef;          # Special check to make sure number of warning and critical parameters is same as what is at -a

# non-config global arrays
my %data_vars=  ();             # Main hash array holding variable & attribute data and expressions ready for processing;
                                # This also serves as symbols table and contains function names, operators, etc.
my @expr_order=  ();            # This array holds expressions in the order of how they are to be processed, it is filled by process_config()
my %func_table= ();             # This is an array of registered functions containing references to perl functions that deal with them
my @nets_oid_array=();          # Array that holds all SNMP data OIDs to be retrieved
my %nets_oid_hash=();           # Pointers from SNMP OIDs to data locations within data_vars array
my @debug_buffer= ();           # Used to store debugging data for verb calls done prior to check_options()

# Functions

sub p_version { print "Called as $0. Base is check_snmp_attributes version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -H <host> (-C <snmp_community> [-2]) | (-l login -x passwd [-X pass -T <authp>,<privp>)  [-p <port>] -e <config expressions> [-a <attributes to check> -w <warn level> -c <crit level> [-f]] [-A <attributes to show>] [-W <warn expressions>] [-C <crit expressions>] [-F <attributes for perfdata>] [-t <timeout>] [-V] [-u <default value>]\n";
}

# Return true if arg is a number (not true number really - it checks if arguments starts with a proper number actually)
sub isnum {
    my $num = shift;
    if ( $num =~ /^([-|+]?(\d+\.?\d*)|[-|+]?(^\.\d+))/ ) { return 1; }
    return 0;
}

sub tonum {
    my $num = shift;
    if ( $num =~ /^([-|+]?(\d+\.?\d*)|[-|+]?(^\.\d+))/ ) { return $1; }
    return undef;
}

# For verbose/debug output
sub verb {
    my ($lv,$dbg)=@_;
    $debug_buffer[$lv].= "($lv) ".$dbg."\n" if defined($dbg) && ($o_vdebug==-1 || $o_vdebug >= $lv);
    for (my $i=1;$i<=$o_vdebug;$i++) {
	    print $debug_buffer[$i] if defined($debug_buffer[$i]);
	    $debug_buffer[$i]="";
    }
}

sub help {
   print "\nAdvanced SNMP (Attributes) Plugin for Nagios version ",$Version,"\n";
   print "  by William Leibzon - william(at)leibzon.org\n\n";
   print_usage();
   print <<EOT;
-v, --verbose
	print extra debugging information
-h, --help
	print this help message
-V, --version
	prints version number
-L, --label
        Plugin output label
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
-T, --protocols=<authproto>,<privproto>
   <authproto> : Authentication protocol (md5|sha : default md5)
   <privproto> : Priv protocols (des|aes : default des)
-P, --port=PORT
	SNMPD port (Default 161)
-t, --timeout=INTEGER
	timeout for SNMP in seconds (Default : 5)
-e, --expression=STR[;STR[;STR[..]]]
   List of Configuration expression(s). They are entered as
     attrib1,attrib2,..=oper,oper,oper,...
   Where operands order is in RPN (Reverse Polish Notation) and can contain function names,
   operators (+/-*%), attribute variable names and data numbers (or data strings enclosed in '..').
   Multiple expressions can be specified separated from each other with ';'
-w, --warn=STR[,STR[,STR[..]]]
	Warning level(s) - usually numbers (same number of values specified as number of attributes)
	Warning values can have the following prefix modifiers:
	   > : warn if data is above this value (default for numeric values)
	   < : warn if data is below this value (must be followed by number)
	   = : warn if data is equal to this value (default for non-numeric values)
	   ! : warn if data is not equal to this value
	   ~ : do not check this data (must not be followed by number)
	   ^ : for numeric values this disables checks that warning is less then critical
        Note that level is considered as one-operand expression, so in fact you can specify
	name of attribute you previously specified with --expression=..
-c, --critical=STR[,STR[,STR[..]]]
	critical level(s) (if more then one name is checked, must have multiple values)
	Critical values can have the same prefix modifiers as warning (see above) except '^'
--check-warncritlist
        This causes enforced checking to make sure that number of critical and warning levels specified is exactly
	the same as number of attributes specified with -A and enforce checking that warning values are smaller
        (or larger for '>') then critical. This does not allow "attribute<level" syntax in -w or -c either.
-a, --attributes=STR[,STR[,STR[..]]]
	Which attribute(s) to check. This is used as regex to check if attribute is found in attribnames table
-D, --display_attributes=STR[,STR[,STR[..]]]
        List of attributes that would be displayed (in main screen) but not checked with
-A, --perf_attributes=STR[,STR[,STR[..]]]
	Which attribute(s) to add to as part of performance data output. These names can be different then the
	ones listed in '-a' to only output attributes in perf data but not check. Special value of '*' gets them all.
-f, --perfparse
        Used only with '-a'. Causes to output data not only in main status line but also as perfparse output
-u, --unknown_default=INT
        If attribute is not found then report the output as this number (i.e. -u 0)
EOT
}

sub check_options {
    Getopt::Long::Configure ("bundling");
    Getopt::Long::GetOptions(
   	'v+'	=> \$o_verb,		'verbose+'	=> \$o_verb,   'debug:i'       => \$o_vdebug,
        'h'     => \$o_help,    	'help'        	=> \$o_help,
        'H:s'   => \$o_host,		'hostname:s'	=> \$o_host,
        'p:i'   => \$o_port,   		'port:i'	=> \$o_port,
        'C:s'   => \$o_community,       'community:s'   => \$o_community,
         '2'    => \$o_version2,        'v2c'           => \$o_version2,
        'l:s'   => \$o_login,           'login:s'       => \$o_login,
        'x:s'   => \$o_passwd,          'passwd:s'      => \$o_passwd,
        'X:s'   => \$o_privpass,        'privpass:s'    => \$o_privpass,
        'T:s'   => \$v3protocols,       'protocols:s'   => \$v3protocols,
        't:i'   => \$o_timeout,       	'timeout:i'     => \$o_timeout,
	'V'	=> \$o_version,		'version'	=> \$o_version,
	'L:s'   => \$o_label,           'label:s'       => \$o_label,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
        'f'     => \$o_perf,            'perfparse'     => \$o_perf,
        'a:s'   => \$o_attr,         	'attributes:s' 	=> \$o_attr,
	'A:s'	=> \$o_perfattr,	'perf_attributes:s' => \$o_perfattr,
	'u:i'	=> \$o_unkdef,		'unknown_default:i' => \$o_unkdef,
	'e:s'   => \$o_confexpr,        'expression:s'  => \$o_confexpr,
	'D:s'   => \$o_dispattr,        'display_attributes:s' => \$o_dispattr,
	'check-warncritlist' => \$o_enfwcnum,
    );
    if (defined($o_help) ) { help(); plugin_exit("UNKNOWN"); };
    if (defined($o_version)) { p_version(); plugin_exit("UNKNOWN"); }
    if (defined($o_verb) && $o_vdebug==-1) { $o_vdebug=$o_verb; }
    if ($o_vdebug==-1) { $o_vdebug=0; }
    verb($o_vdebug,undef);
    if ( ! defined($o_host) ) # check host and filter
	{ print "No host defined!\n"; print_usage(); plugin_exit("UNKNOWN"); }
    # check snmp information
    if ( !defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
        { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
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

    if (!defined($o_confexpr) && scalar(@expr_order)==0) {
	print "Config expression not defined!\n";
	print_usage();
	plugin_exit("UNKNOWN");
    }
    elsif (defined($o_confexpr)) {
	my @config_expressions = split /;/, $o_confexpr;
        process_config_expressions(\@config_expressions);
    }

    if (defined($o_perfattr)) {
        @o_perfattrL=split(/,/ ,$o_perfattr) if defined($o_perfattr);
    }
    if (defined($o_dispattr)) {
        @o_dispattrL=split(/,/ ,$o_dispattr) if defined($o_dispattr);
    }
    if (defined($o_warn) || defined($o_crit) || defined($o_attr)) {
        if (defined($o_attr)) {
          @o_attrL=split(/,/, $o_attr);
        }
        else {
          print "Specifying warning and critical levels requires '-a' parameter with attribute names\n";
          print_usage();
          plugin_exit("UNKNOWN");
        }
	if (defined($o_enfwcnum)) {
	    set_warncrit_enforced();
	}
	else {
	    set_warncrit_unrestricted();
	}
    }
    if (scalar(@o_attrL)==0 && scalar(@o_perfattrL)==0 && scalar(@o_dispattrL)==0) {
        print "You must specify list of attributes with either '-a' or '-A'\n";
        print_usage();
	plugin_exit("UNKNOWN");
    }
}

sub set_alarm {
    my $timeout_in = shift;

    # Get the alarm signal (just in case snmp timout screws up)
    $SIG{'ALRM'} = sub {
       print ("ERROR: Alarm signal (Nagios time-out)\n");
       exit $ERRORS{"UNKNOWN"};
    };

    # Check gobal timeout if snmp screws up
    if (defined($TIMEOUT) || defined($timeout_in)) {
       $timeout_in = $TIMEOUT if !defined($timeout_in);
       verb(1,"Alarm at $timeout_in");
       alarm($timeout_in);
    } else {
       verb(1,"no timeout defined : $o_timeout + 10");
       alarm ($o_timeout+10);
    }
}

sub get_perfdata {
    my $i;
    my $perfdata;
    my $dt;

    # Decide which performance attributes are going to be reported back and then actually do it
    if (defined($o_perf)) {
         for ($i=0;$i<scalar(@o_attrL);$i++) {
	     $data_vars{$o_attrL[$i]}{'perf'}=1;
	 }
     }

    if (defined($o_perfattr) && $o_perfattr ne '*') {
	for ($i=0;$i<scalar(@o_perfattrL);$i++) {
	    $data_vars{$o_perfattrL[$i]}{'perf'}=1;
	}
    }
    foreach (keys %data_vars) {
	if (((defined($o_perfattr) && $o_perfattr eq '*') || defined($data_vars{$_}{'perf'}))
	     && defined($data_vars{$_}{'data'}) && $data_vars{$_}{'from'} eq 'config') {
	    $dt=$data_vars{$_}{'data'};
	    $dt=tonum($dt) if isnum($dt);
	    $perfdata .= " " . $_ . "=" . $dt;
	}
    }

    return $perfdata;
}

sub plugin_output {
    my ($label, $errorcode, $errorinfo, $statusdata, $perfdata) = @_;

    # Output everything and exit
    $label .= " " if $o_label ne '';
    print $label . $errorcode;
    print " -".$errorinfo if $errorinfo;
    print " -".$statusdata if $statusdata;
    print " |".$perfdata if $perfdata;
    print "\n";
}

# main function
sub run_plugin {
    set_alarm(); # this resets alarm even if it was set before (yes, that's on purpose)
    # This processes config and then processes functions (which does SNMP connection) and expressions
    preproc_allfunctions();
    check_options();
    globalproc_allfunctions();
    process_allexpressions();
    # Sets default for things not otherwise done - this might need to be revised
    foreach (@expr_order) {
	$data_vars{$_}{'data'}=$o_unkdef if !defined($data_vars{$_}{'data'}) && defined($o_unkdef);
    }
    postproc_allfunctions();

    # Check data with specified thresholds and output results
    my ($statuscode, $statusinfo, $statusdata) = check_warncrit_thresholds();
    my $perfdata = get_perfdata();
    plugin_output($o_label, $statuscode, $statusinfo, $statusdata, $perfdata);
    plugin_exit($statuscode);
}

############## MAIN ###########
set_alarm();
registerbasefunctions();
if (!caller(0)) {
	run_plugin();
}

1;

################### SUBROUTINES DEALING WITH PROCESSING OF EXPRESSION HANDLER FUNCTIONS  ###################

# For reference here is list of acceptable handler definition variables - 'id' is reguired, others are optional and depend on how this is used
#   'id'    - id of the function - functions are grouped based on this name
#   'uid'   - unique self-id for this function handler (actual real unique registration id '_id' is generated based on this and random number)
#   'oper'  - this is set of symbols that must match exactly
#   'name'  - function name in expression when called directly as in 'name()'
#   'regex' - this is a regex that if matched also causes use of this handler; can lead to errors, avoid this unless necessary
#  [all below should contain pointers to functions]
#   'sub_init'       - called before all processing has started, can be used as constructor-like way for delayed initialization
#   'sub_config'     - called when function is being configured for each mention in expression; full function call is a paramter
#                      should return true (1) on success and false (0) if its invaliud call for this function
#   'sub_globalproc' - called after configuration to do general processing before variables are actually evaluated; no parameters
#   'sub_eval'       - called for each case where expressions are evaluated; full function call is first parameter, reference to stack is second
#                      should return true (1) on success and false (0) if there was some error
#   'sub_postproc'   - called after evaluation of expressions
#   'sub_exit'       - called after everything has been processed right before plugin is ready to exit, can be used as destructor; no parameters
sub register_function {
    my $funcdef = shift;
    my $fn;

    if (!defined($funcdef->{'id'})) {
	print "Invalid call to register_function()\n";
	plugin_exit("UNKNOWN");
    }
    $fn=$funcdef->{'id'};
    $funcdef->{'_id'}=$funcdef->{'id'}."_";
    $funcdef->{'_id'}.=$funcdef->{'uid'}."_" if defined($funcdef->{'uid'});
    $funcdef->{'_id'}.=rand();
    $func_table{$fn}=[] if !exists($func_table{$fn});
    unshift @{$func_table{$fn}}, $funcdef;
    if (defined($funcdef->{'oper'}) && !defined($data_vars{$funcdef->{'oper'}})) {
	verb(4,"Function $fn will be called when operator '".$funcdef->{'oper'}."' is used");
	$data_vars{$funcdef->{'oper'}}={ 'type' =>'func', 'handler'=> $fn };
    }
    if (defined($funcdef->{'name'}) && !defined($data_vars{$funcdef->{'name'}})) {
	verb(4,"Function $fn will be called when expression contains '".$funcdef->{'name'}."(..)'");
	$data_vars{$funcdef->{'name'}}={ 'type' =>'func', 'handler'=> $fn }
    }
    verb(2,"Registered function $fn");
}

# Functional general processing function - iterates through all of them doing same type of call
sub process_allfunctions {
    my $call_type = shift;
    my $fname;
    my $fcall;
    my $ft;

    foreach $fname (keys %func_table) {
	foreach (@{$func_table{$fname}}) {
	    if (defined($_->{$call_type})) {
		$fcall=$_->{$call_type};
		$ft=&$fcall();
	    }
	}
    }
}

sub preproc_allfunctions {
    process_allfunctions('sub_init');
}

sub globalproc_allfunctions {
    process_allfunctions('sub_globalproc');
}

sub postproc_allfunctions {
    process_allfunctions('sub_postproc');
}

# Interates through destructors at the end right before exit
sub plugin_exit {
    my $exitcode=shift;
    process_allfunctions('sub_exit');
    exit $ERRORS{$exitcode};
}

# Function processing during processing of config string
sub config_functioncall {
    my $func_str = shift;
    my $fcall;
    my $fn=undef;
    my $fnp;
    my $reg;
    my $ret="";

    if ($func_str eq "") {
	verb(2,"Empty operand in expression, giving up");
	return "";
    }
    elsif ($func_str =~ /^(.+)\(.*\)?$/ && exists($data_vars{$1}) && $data_vars{$1}{'type'} eq 'func') {
	$fn=$data_vars{$1}{'handler'};
	verb(6,"Match found: function $fn for symbol '".$1."'");
    }
    elsif (exists($data_vars{$func_str}) && $data_vars{$func_str}{'type'} eq 'func') {
	$fn=$data_vars{$func_str}{'handler'};
	verb(6,"Match found: function $fn for symbol '$func_str'");
    }
    if (defined($fn)) {
	L1: foreach(@{$func_table{$fn}}) {
	    $ret=$fn;
	    if (defined($_->{'sub_config'})) {
		$fcall=$_->{'sub_config'};
		$ret=&$fcall($func_str);
		$ret=$fn if $ret;
	    }
	    last L1 if $ret;
	}
    }
    if (!$ret) {
    L2: foreach $fn (sort keys %func_table) {
            foreach $fnp (@{$func_table{$fn}}) {
		if (defined($fnp->{'regex'})) {
		    $reg=$fnp->{'regex'};
		    if ($func_str =~ /^$reg/) {
			verb(6,"Match found: function $fn for symbol '$func_str'");
			$ret=$fn;
			if (defined($fnp->{'sub_config'})) {
			    $fcall=$fnp->{'sub_config'};
			    $ret=&$fcall($func_str);
			    $ret=$fn if $ret;
			}
			last L2 if $ret;
		    }
		}
	    }
        }
    }
    if ($ret) {
	verb(6,"Configured function $ret for '$func_str'");
	return $ret;
    }
    return ""; # no suitable function found, error will be given out by process_config due to this
}

# Evaluate function - a lot simpler since function name is an argument here
sub eval_functioncall {
    my ($fn, $func_str, $stack) = @_;
    my $fcall;
    my $is_ok;

    if (exists($func_table{$fn})) {
	foreach(@{$func_table{$fn}}) {
	    $fcall=$_->{'sub_eval'};
	    $is_ok=&$fcall($func_str,$stack);
	    if ($is_ok) {
		verb(3,"Function '$fn' with id ".$_->{'_id'}." was used to handle $func_str");
		verb(3,"Stack data: ".join(" ",@{$stack}));
		return;
	    }
	}
    }
    if (!$func_str) {
	print "Error evaluating expression - no function/value specified (likely empty expression)\n";
    }
    else {
        print "Error evaluating function $func_str\n";
    }
    plugin_exit("UNKNOWN");
}

sub process_expressions {
    return process_config_expressions(\@_);
}

# This function processes list of configuration expressions
sub process_config_expressions {
    my $expressions_config = shift;
    my $expr;
    my $vars;
    my @var_list;
    my $tstr;
    my $elt;

    foreach (@{$expressions_config}) {
	($vars, $expr) = split /=/;
	if ($expr eq "") {
	    print "Configuration error - empty expression at $_";
	    plugin_exit("UNKNOWN");
	}
	if ($vars eq "") {
	    $vars = "_var_".rand() until !exists($data_vars{$vars});
	    $data_vars{$vars}={'type' => 'var', 'from' => '_auto_expr', 'dependencies' => [], 'data' => undef };
	    @var_list = ($vars);
	    verb(2,"Empty variable list at $_ - will create variable with random name: $vars");
	}
	else {
	    @var_list = split(/,/,$vars);
	    verb(2,"Variables '$vars' are defined by expression '$expr'");

	    foreach(@var_list) {
		if ($data_vars{$_}) {
		    print "Configuration error - trying to define variable '$_' second time at: $vars=$expr\n";
		    plugin_exit("UNKNOWN");
		}
		$data_vars{$_}={'type' => 'var', 'from' => 'config', 'dependencies' => [], 'data' => undef };
	    }
	}

	# First variable carries actual expression and list of other variables (including self) to which values are to be assigned after processing
	$data_vars{$var_list[0]}{'vars'}=[@var_list];
	$data_vars{$var_list[0]}{'expr'}=[];

	# look at the expression, this also deals with functions that take multiple arguments (for future)
	$elt="";
	foreach (split /,/,$expr) {
	    $elt.=',' if $elt;
	    $elt.=$_;
	    next if $elt =~ /\(/ && $elt !~ /\)/; # incomplete function without closing ')'
	    # main check to see what it is
	    $tstr=config_functioncall($elt);
	    if ($tstr) {
		push @{ $data_vars{$var_list[0]}{'expr'} }, [$tstr, $elt];
		verb(3,"Function '$tstr' will be used when handling $elt");
		if ($tstr eq "__var") {
		    verb(2,"Adding variable $elt to dependency list for variable(s) $vars");
		    push @{ $data_vars{$_}{'dependencies'} }, $elt foreach(@var_list);
		}
	    }
	    else {
		print("Unable to find suitable function for symbol '$elt' found in expression $expr\n");
		plugin_exit("UNKNOWN");
	    }
	    # clear it up for next loop iteration
	    $elt="";
        }
	if ($elt ne "") {
	    print "Configuration error - incomplete function $elt in configuration\n";
	    plugin_exit("UNKNOWN");
	}
	# TODO: for future may need to add algorithm that resolves dependencies and creates proper
	#       order for processing of expressions. For right now just do it in the order given in config
	push @expr_order, $_ foreach(@var_list);
    }
}


# This function processes expression [ordered list of function calls] that is in RPN (Reverse Polish Notation) form
sub evaluate_expression {
    # expressions come as a pointer to list of 2-dimensional arrays ([0] is type of function and [1] actual function call)
    my $expressions = shift;
    my $expression_string = "";
    my @stack=();

    $expression_string .= ($expression_string?',':'').$_->[1] foreach(@{$expressions});
    verb(2, "Processing expression '$expression_string'");
    foreach (@{ $expressions }) {
	eval_functioncall($_->[0], $_->[1], \@stack);
    }
    verb(2, "Results of evaluation of '$expression_string' is: ".join(",",@stack));
    return @stack;
}

sub process_allexpressions {
    my @expression_results;
    my $vname;

    foreach $vname (@expr_order) {
	if (!defined($data_vars{$vname}{'data'}) && exists($data_vars{$vname}{'expr'})) {
	    @expression_results=evaluate_expression($data_vars{$vname}{'expr'});
	    if (defined($data_vars{$vname}{'vars'}) && scalar(@expression_results)!=scalar(@{ $data_vars{$vname}{'vars'} })) {
		verb(2,"Warning - number of results from expression (".scalar(@expression_results).") is not equal to number of variables (".scalar(@{$data_vars{$vname}{'vars'}}).") in assignment");
	    }
	    if (defined($data_vars{$vname}{'vars'})) {
	        foreach (@{ $data_vars{$vname}{'vars'} }) {
		    if (scalar(@expression_results)>0) {
			$data_vars{$_}{'data'}=shift @expression_results;
			verb(1,"Var '$_' evaluated with result: ".$data_vars{$_}{'data'});
		    }
		    else {
			verb(1,"Warning - not enough results in expression to set variable $_");
		    }
		}
	    }
	}
    }
}

################## SUBROUTINES DEALING WITH CHECKING OF CRITICAL & WARNING VALUES ############

# This code for parsing warn/crit parameters imported from in check_snmp_table
# In this system for every attributed listed in '-a' there should be corresponding data in -w and -c
# This would get used only if '--check-warncritlist' option is used
sub set_warncrit_enforced {
        my ($isnw,$isnc,$nw,$nc,$opw,$opc); # these are just for optimization and to shorten the code
        my @o_warnLv=();
	my @o_critLv=();
        @o_warnLv=split(/,/ ,$o_warn) if defined($o_warn);
        @o_critLv=split(/,/ ,$o_crit) if defined($o_crit);

        if ((scalar(@o_warnLv)!=scalar(@o_attrL) && (scalar(@o_warnLv)-scalar(@o_attrL)>1 || $o_warn !~ /.*,$/)) ||
	    (scalar(@o_critLv)!=scalar(@o_attrL) && (scalar(@o_critLv)-scalar(@o_attrL)>1 || $o_crit !~ /.*,$/))) {
	        printf "Number of specified warning levels (%d) and critical levels (%d) must be equal to the number of attributes specified at '-a' (%d). If you need to ignore some attribute specify it as '~'\n", scalar(@o_warnLv), scalar(@o_critLv), scalar(@o_attrL);
	        print_usage();
	        plugin_exit("UNKNOWN");
	}
        for (my $i=0; $i<scalar(@o_attrL); $i++) {
		if ($o_warnLv[$i]) {
			$o_warnLv[$i] =~ s/^(\^?[>|<|=|!|~]?)//;
			$opw=$1;
		}
		else {
			$opw="";
			$o_warnLv[$i]="";
		}
		if ($o_critLv[$i]) {
			$o_critLv[$i] =~ s/^([>|<|=|!|~]?)//;
			$opc=$1;
		}
		else {
			$opc="";
			$o_critLv[$i]="";
		}
		$isnw=isnum($o_warnLv[$i]);
		$isnc=isnum($o_critLv[$i]);
		$nw=tonum($o_warnLv[$i]) if $isnw;
		$nc=tonum($o_critLv[$i]) if $isnc;
		if (($opw =~ /^[>|<]/ && !$isnw) ||
		    ($opc =~ /^[>|<]/ && !$isnc)) {
			print "Numeric value required when '>' or '<' are used !\n";
			print_usage();
			plugin_exit("UNKNOWN");
          	}
		if ($isnw && $isnc && $opw eq $opc && (($nw>=$nc && $opw !~ /</) || ($nc<=$nc && $opc =~ /</))) {
			print "Problem with warning value $o_warnLv[$i] and critical value $o_critLv[$i] :\n";
                        print "All numeric warning values must be less then critical (or greater then when '<' is used)\n";
			print "Note: to override this check prefix warning value with ^\n";
                        print_usage();
			plugin_exit("UNKNOWN");
		}
		$opw =~ s/\^//;
		$opw = '=' if !$opw && !$isnw;
		$opw = '>' if !$opw && $isnw;
		$opc = '=' if !$opc && !$isnc;
		$opc = '>' if !$opc && $isnc;

		# Finally set the main warning & critical arrays - as part of that process passed value as one-operand in expression
		#   note: in the future will need to call modified version of process_config_expressions
		#         when support for regular (rather then just RPN) expressions would become available
		$o_warnL[$i] = { 'var' => $o_attrL[$i], 'comp' => $opw, 'configstr'=> $o_warnLv[$i] };
		if ($o_warnLv[$i]) {
		    $nw=config_functioncall($o_warnLv[$i]);
		    if ($nw) {
			$o_warnL[$i]{'expr'} = [ [$nw, $o_warnLv[$i]] ];
		    }
		    else {
			verb(2, "Problem finding function to process warning expression '".$o_warnLv[$i]."', will treat it as data");
			$o_warnL[$i]{'data'} = $o_warnLv[$i];
		    }

		}
	        $o_critL[$i] = { 'var' => $o_attrL[$i], 'comp' => $opc, 'configstr'=> $o_critLv[$i] };
		if ($o_critLv[$i]) {
		    $nc=config_functioncall($o_critLv[$i]);
		    if ($nc) {
			$o_critL[$i]{'expr'} = [ [$nc, $o_critLv[$i]] ];
		    }
		    else {
			verb(2, "Problem finding function to process crtical expression '".$o_critLv[$i]."', will treat it as data") if !$nc;
			$o_critL[$i]{'data'} = $o_critLv[$i];
		    }
		}
        }
}

# This is code for parsing warn/crit parameters imported from in check_snmp_table with extended syntax for it
sub set_warncrit_unrestricted {
    set_warncrit_enforced();
}

# help function when checking data against critical and warn values
sub check_value {
    my ($attrib, $data, $level, $modifier) = @_;

    my ($d,$l)=($data,$level);
    $d=tonum($d) if isnum($d);
    $l=tonum($l) if isnum($l);
    return "" if $modifier eq '~';
    return " " . $attrib . " is " . $data . " = " . $level if $modifier eq '=' && $d eq $l;
    return " " . $attrib . " is " . $data . " != " . $level if $modifier eq '!' && $d ne $l;
    return " " . $attrib . " is " . $data . " > " . $level if $modifier eq '>' && $d > $l;
    return " " . $attrib . " is " . $data . " < " . $level if $modifier eq '<' && $d < $l;
    return "";
}

sub check_warncrit_thresholds {
    # loop to check if warning & critical attributes are ok
    my $statuscode = "OK";
    my $statusinfo = "";
    my $statusdata = "";
    my $chk;
    my $i;
    my @arv;
    my $vname;

    for ($i=0;$i<scalar(@o_critL);$i++) {
	$vname=$o_critL[$i]{'var'};
        if ($data_vars{$vname}{'type'} eq 'var' && $data_vars{$vname}{'from'} eq 'config') {
	    if (defined($data_vars{$o_attrL[$i]}{'data'})) {
		verb(2, "Processing critical expression '".$o_critL[$i]{'configstr'}."' to compare with $vname");
		if (!defined($o_critL[$i]{'data'}) && defined($o_critL[$i]{'expr'})) {
		    @arv=evaluate_expression($o_critL[$i]{'expr'});
		    if (scalar(@arv)==0) {
			print "Problem evaluating critical level expression '".$o_critL[$i]{'configstr'}."' - no data values returned\n";
			plugin_exit("UNKNOWN");
		    }
		    $o_critL[$i]{'data'}=$arv[0];
		}
	        if (defined($o_critL[$i]{'data'})) { # data can still be missing if ~ was used, in which case skip
		    if ($chk = check_value($vname,$data_vars{$vname}{'data'},$o_critL[$i]{'data'},$o_critL[$i]{'comp'})) {
		        $statuscode = "CRITICAL";
		        $statusinfo .= $chk;
		        $data_vars{$vname}{'out'}=1;
		    }
	        }
	    }
	    else {
	        $statusdata .= "," if ($statusdata);
	        $statusdata .= " $o_attrL[$i] data is missing";
		$data_vars{$vname}{'out'}=1
	    }
	}
    }

    for ($i=0;$i<scalar(@o_warnL);$i++) {
	$vname=$o_warnL[$i]{'var'};
        if ($data_vars{$vname}{'type'} eq 'var' && $data_vars{$vname}{'from'} eq 'config' && !defined($data_vars{$vname}{'out'})) {
	    if (defined($data_vars{$o_attrL[$i]}{'data'})) {
		verb(2, "Processing warning expression '".$o_warnL[$i]{'configstr'}."' to compare with $vname");
		if (!defined($o_warnL[$i]{'data'}) && defined($o_warnL[$i]{'expr'})) {
		    @arv=evaluate_expression($o_warnL[$i]{'expr'});
		    if (scalar(@arv)==0) {
			print "Problem evaluating warning level expression '".$o_warnL[$i]{'configstr'}."' - no data values returned\n";
			plugin_exit("UNKNOWN");
		    }
		    $o_warnL[$i]{'data'}=$arv[0];
		}
	        if (defined($o_warnL[$i]{'data'})) { # data can still be missing if ~ was used, in which case skip
		    if ($chk = check_value($vname,$data_vars{$vname}{'data'},$o_warnL[$i]{'data'},$o_warnL[$i]{'comp'})) {
		        $statuscode = "WARNING" if $statuscode ne "CRITICAL";
		        $statusinfo .= $chk;
		        $data_vars{$vname}{'out'}=1;
		    }
	        }
	    }
	    else {
	        $statusdata .= "," if ($statusdata);
	        $statusdata .= " $o_attrL[$i] data is missing";
		$data_vars{$vname}{'out'}=1
	    }
	}
    }

    for ($i=0;$i<scalar(@o_attrL);$i++) {
	if (defined($data_vars{$o_attrL[$i]}) && $data_vars{$o_attrL[$i]}{'type'} eq 'var' && $data_vars{$o_attrL[$i]}{'from'} eq 'config' && !defined($data_vars{$o_attrL[$i]}{'out'})) {
	    if (defined($data_vars{$o_attrL[$i]}{'data'})) {
		$statusdata .= "," if ($statusdata);
		$statusdata .= " " . $o_attrL[$i] . " is " . $data_vars{$o_attrL[$i]}{'data'} ;
	    }
	    else {
	        $statusdata .= "," if ($statusdata);
	        $statusdata .= " $o_attrL[$i] data is missing";
	    }
	    $data_vars{$o_attrL[$i]}{'out'}=1
	}
    }
    for ($i=0;$i<scalar(@o_dispattrL);$i++) {
	if (defined($data_vars{$o_dispattrL[$i]}) && $data_vars{$o_dispattrL[$i]}{'type'} eq 'var' && $data_vars{$o_dispattrL[$i]}{'from'} eq 'config' && !defined($data_vars{$o_dispattrL[$i]}{'out'})) {
	    if (defined($data_vars{$o_dispattrL[$i]}{'data'})) {
		$statusdata .= "," if ($statusdata);
		$statusdata .= " " . $o_dispattrL[$i] . " is " . $data_vars{$o_dispattrL[$i]}{'data'} ;
	    }
	    else {
	        $statusdata .= "," if ($statusdata);
	        $statusdata .= " $o_dispattrL[$i] data is missing";
	    }
	    $data_vars{$o_dispattrL[$i]}{'out'}=1
	}
    }

    return ($statuscode, $statusinfo, $statusdata);
}


################## DEFAULT SET OF BASE EXPRESSION OPERATORS ##################################

sub registerbasefunctions {
    basefunc_data_register();  # deals with numbers & other base data in expression, like '100' from expression 'a,100,*'
    basefunc_var_register();   # deals with retrieving value of another variable like. 'a' from expression 'a,100,*'
    basefunc_operatorplus_register();  # deals with '+' operator
    basefunc_operatorminus_register(); # deals with '-' operator
    basefunc_operatormult_register();  # deals with '*' operator
    basefunc_operatordiv_register();   # deals with '/' operator
    basefunc_operatorplus_stringadd_register(); # this overloads '+' operator but only works if one of the stack elements is not a number
    basefunc_operatordot_stringadd_register();  # this defined '.' operator only for strings
    basefunc_percent_register();	# deals with '%' operator
    function_round_register(); # deals with function 'round' that rounds float numbers
    function_snmp_register();  # deals with function that retrieves specified OID by SNMP
}

# Base 'data' function/operator - it copies argument into stack as is if its a number
sub basefunc_data_eval {
    my ($func_str, $stack) = @_;
    if ($func_str =~ /^'(.*)'$/ || $func_str =~ /^_data\((.*)\)$/) { unshift @{$stack}, $1; }
    else { unshift @{$stack}, $func_str; }
    return 1;
}
sub basefunc_data_register {
    my $def = {
	'id'   => '_data',
	'name' => '_data',
	'uid' => '_base_data0',
	'regex' => '[-|+]?(\d+\.?\d*)|[-|+]?(^\.\d+)|'."('.*')",
	'sub_eval' => \&basefunc_data_eval,
    };
    register_function($def);
}

# Base 'var' function/operator - it assumes argument is variable name and copies its 'data' into stack
sub basefunc_var_config {
    my $func_str = shift;
    return 1 if exists($data_vars{$func_str}) && $data_vars{$func_str}{'type'} eq 'var';
    return 1 if $func_str =~ /^__var\((.*)\)/;
    return 0;
}

sub basefunc_var_eval {
    my ($func_str, $stack) = @_;
    my $vname="";

    $vname=$1 if $func_str =~ /^__var\((.*)\)/;
    $vname=$func_str if !$vname;	
    if (exists($data_vars{$vname}) && defined($data_vars{$vname}{'data'})) {
	unshift @{$stack},$data_vars{$vname}{'data'};
	return 1;
    }
    return 0;
}
sub basefunc_var_register {
    my $def = {
	'id'   => '__var',
	'name' => '_var',
	'uid'  => '_var_data0',
	'regex' => '.*', # anything matches
	'sub_config' => \&basefunc_var_config,
	'sub_eval' => \&basefunc_var_eval,
    };
    register_function($def);
}

# Base '+' operator
sub basefunc_operatorplus_eval {
    my ($func_str, $stack) = @_;
    if ($func_str eq '+' && isnum($stack->[0]) && isnum($stack->[1])) {
	$stack->[1] = tonum($stack->[1]) + tonum($stack->[0]);
	shift @{$stack};
	return 1;
    }
    return 0;
}
sub basefunc_operatorplus_register {
    my $def = {
	'id' => '_operator_plus',
	'name' => '_plus',
	'uid' => '_base_operator_plus0',
	'oper' => '+',
	'sub_eval' => \&basefunc_operatorplus_eval,
    };
    register_function($def);
}

# Base '-' operator
sub basefunc_operatorminus_eval {
    my ($func_str, $stack) = @_;
    if ($func_str eq '-' && isnum($stack->[0]) && isnum($stack->[1])) {
	$stack->[1] = tonum($stack->[1]) - tonum($stack->[0]);
	shift @{$stack};
	return 1;
    }
    return 0;
}
sub basefunc_operatorminus_register {
    my $def = {
	'id' => '_operator_minus',
	'name' => '_minus',
	'uid' => '_base_operator_minus0',
	'oper' => '-',
	'sub_eval' => \&basefunc_operatorminus_eval,
    };
    register_function($def);
}

# Base '*' operator
sub basefunc_operatormult_eval {
    my ($func_str, $stack) = @_;
    if ($func_str eq '*' && isnum($stack->[0]) && isnum($stack->[1])) {
	$stack->[1] = tonum($stack->[1]) * tonum($stack->[0]);
	shift @{$stack};
	return 1;
    }
    return 0;
}
sub basefunc_operatormult_register {
    my $def = {
	'id' => '_operator_mult',
	'name' => '_mult',
	'uid' => '_base_operator_mult0',
	'oper' => '*',
	'sub_eval' => \&basefunc_operatormult_eval,
    };
    register_function($def);
}

# Base '/' operator
sub basefunc_operatordiv_eval {
    my ($func_str, $stack) = @_;
    if ($func_str eq '/' && isnum($stack->[0]) && isnum($stack->[1])) {
	my $n0 = tonum($stack->[0]);
	my $n1 = tonum($stack->[1]);
	$stack->[1] = $n1 / $n0 if $n0 != 0;
	$stack->[1] = 0 if $n0 == 0; # strictly speaking this is wrong
	shift @{$stack};
	return 1;
    }
    return 0;
}
sub basefunc_operatordiv_register {
    my $def = {
	'id' => '_operator_div',
	'name' => '_div',
	'uid' => '_base_operator_div',
	'oper' => '/',
	'sub_eval' => \&basefunc_operatordiv_eval,
    };
    register_function($def);
}

# Operator to add strings - this overloads '+' but only works if one of the arguments is not a number
sub basefunc_operatorplus_stringadd_eval {
    my ($func_str, $stack) = @_;
    if ($func_str eq '+' && (!isnum($stack->[0]) || !isnum($stack->[1]))) {
	$stack->[1] = "$stack->[1]"."$stack->[0]";
	shift @{$stack};
	return 1;
    }
    return 0;
}
sub basefunc_operatorplus_stringadd_register {
    my $def = {
	'id' => '_operator_plus',
	'uid' => '_base_string_add0',
	'oper' => '+',
	'sub_eval' => \&basefunc_operatorplus_stringadd_eval,
    };
    register_function($def);
}

# Operator to add strings - this is more common "." with alias 'stradd' which will work even if argumets are a number
sub basefunc_operatordot_stringadd_eval {
    my ($func_str, $stack) = @_;
    if ($func_str eq '.') {
	$stack->[1] = "$stack->[1]"."$stack->[0]";
	shift @{$stack};
	return 1;
    }
    return 0;
}
sub basefunc_operatordot_stringadd_register {
    my $def = {
	'id'   => '_operator_dot',
	'name' => 'stradd',
	'uid' => '_base_string_add2',
	'oper' => '.',
	'sub_eval' => \&basefunc_operatordot_stringadd_eval,
    };
    register_function($def);
}

# SNMP Function/Operator - retrieves data from specified OID
sub func_snmp_config {
    my $in = shift;
    if ($in =~ /snmp\((.*)\)/) {
        if ($no_snmp) {
            print "Can't locate Net/SNMP.pm\n"; print_usage(); exit $ERRORS{"UNKNOWN"};
        }
	push @nets_oid_array, $1;
	$nets_oid_hash{$1}=undef;
	verb(2,"snmp oid $1 added to list of OIDs to be retrieved");
	return 1;
    }
    return 0;
}

sub func_snmp_eval {
    my ($func_str, $stack) = @_;
    if ($func_str =~ /snmp\((.*)\)/) {
	if (defined($nets_oid_hash{$1})) {
	    unshift @{ $stack }, ${$nets_oid_hash{$1}};
	    return 1;
        }
        else {
	    print "No data argument found for function $func_str\n";
        }
    }
    return 0;
}

sub func_snmp_proc {
    my ($session,$error,$resultat);

    # Connect to host
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
    }
    elsif (defined ($o_version2)) {
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

    if (!defined($session)) {
	printf("ERROR opening session: %s.\n", $error);
	plugin_exit("UNKNOWN");
    }

     # Get NetSNMP memory values
     $resultat = (Net::SNMP->VERSION < 4) ?
		$session->get_request(@nets_oid_array)
		:$session->get_request(-varbindlist => \@nets_oid_array);

     # Exit with error if SNMP get_request failed
     if (!defined($resultat)) {
	 printf("ERROR: snmp get_request failed - %s.\n", $session->error);
	 $session->close;
	 plugin_exit("UNKNOWN");
     }
	
     # Put SNMP data into %data_vars{'varname'}{'data'} - all done one line :)
     verb(1,"SNMP $_ = ".( ${$nets_oid_hash{$_}} = $$resultat{$_} )) foreach (@nets_oid_array);

     $session->close;
}

sub function_snmp_register {
    my $def = {
	'id'  => 'func_snmp',
	'name'=> 'snmp',
	'uid' => 'snmp0',
	'sub_config' => \&func_snmp_config,
	'sub_globalproc' => \&func_snmp_proc,
	'sub_eval' => \&func_snmp_eval,
    };
    register_function($def);
}

# Round function - assumes data is float number and rounds it to set number of digits before and after the '.'
sub func_round_eval {
    my ($func_str, $stack) = @_;
    if ($func_str =~ /round\((.*)\)/ && isnum($stack->[0])) {
	$stack->[0] = sprintf("%.$1f", tonum($stack->[0]));
	return 1;
    }
    return 0;
}

sub function_round_register {
    my $def = {
	'id'  => "func_round",
	'name' => 'round',
	'uid' => 'round0',
	'sub_eval' => \&func_round_eval,
    };
    register_function($def);
}

# Percent calculation function - this is optimization and is equivalent to doing "arg1,arg2,/,100,*,round(2),'%',+"
sub basefunc_percent_eval {
    my ($func_str, $stack) = @_;
    if ($func_str eq '%') {
	my $n0 = tonum($stack->[0]);
	my $n1 = tonum($stack->[1]);
	$stack->[1] = sprintf("%.2f%%", $n1*100/$n0) if $n0 != 0;
	$stack->[1] = '0%' if $n0 == 0;
	shift @{$stack};
	return 1;
    }
    return 0;
}

sub basefunc_percent_register {
    my $def = {
	'id' => '_operator_percent',
	'name' => 'percent',
	'uid' => 'percent0',
	'oper' => '%',
	'sub_eval' => \&basefunc_percent_eval,
    };
    register_function($def);
}
