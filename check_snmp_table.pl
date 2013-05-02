#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_snmp_table.pl
# Version : 0.31
# Date    : Oct 06, 2006
#           (May 23 2006 is 0.3, modified in October to add label)
# Author  : William Leibzon - william@leibzon.org
# Summary : This is a nagios plugin to check SNMP sensors where sensor
#           names are specified in one SNMP table and values in related
#           another table.
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
# This is a general nagios plugin to check values of SNMP attributes where
# names of the attributes are available at one "names" SNMP table and data
# in related "nearby" data SNMP table, i.e.:
#  Names table:
#    .9.9.9.9.9.9.1 "attrib1"
#    .9.9.9.9.9.9.2 "attrib2"
#  Data table:
#    .9.9.9.9.9.8.1 25		- data value for "attrib1"
#    .9.9.9.9.9.8.2 50		- data value for "attrib2"
# Performance data is also optionally returned for nagios 2.0 post-processing
#
# This program is written and maintained by:
#   William Leibzon - william(at)leibzon.org
# It is partially based on check_snmp_* plugins by:
#   Patrick Proy (patrick at proy.org)
#
# =============================== SETUP NOTES ================================
#
# 1. Make sure to check and if necessary adjust the the path to utils.pm
# 2. Make sure you have Net::SNMP perl module installed
# 3. You need to know base OIDs for your attributes:
#    a. first needs to be base table of names - specify it with '-N'
#    b. second one is base of values - specify it with '-D'
#
# The way plugin works is to walk the snmp tree from base names OID and find
# all the attribute names. Then it compares partial names given with '-a'
# (those are separated by ',') to those found in the snmp tree and uses OID
# ending (i.e. part of OID below the base) and adds it to base value OID to
# create OID to be retrieved. Many of SNMP parameters are like that so this
# is good general plugin to get values from SNMP tables. Note also that in
# some cases not all the listed names are actually available as OIDs in data
# table, in that case use '-R' option which causes plugin to retrieve data
# table by walking the tree as well.
#
# While you may know your base names and data tables, you may not know what
# values to check. You can find all attribute names by doing:
#     check_snmp_table.pl -C community -N oid-base-table -D oid-data-table -a '*' -H HOSTNAME
# if there are problems with above try adding '-R -v' and see debug output
#
# The values retrieved are compared to specified warning and critical levels.
# Warning and critical levels are specified with '-w' and '-c' and each one
# must have exact same number of values (separated by ',') as number of
# attribute names specified with '-a'. Any values you dont want to compare
# you specify as ~. There are also number of other one-letter modifiers that
# can be used before actual data value to direct how data is to be checked.
# These are as follows:
#    > : issue alert if data is above this value (default for numeric value)
#    < : issue alert if data is below this value (must be followed by number)
#    = : issue alert if data is equal to this value (default for non-numeric)
#    ! : issue alert if data is NOT equal to this value
# A special modifier '^' can also be used to disable checking that warn values
# are less then (or greater then) critical values (it is rarely needed).
# A quick example of specialized use is '--warn=^<100 --crit=>200'
# which will cause warning alert if SNMP retrieved value is < 100 (this
# type of checking is usefull for fan speed checking for example) and
# critical alert if its greater then 200.
#
# In some cases you also may not get data for specific attribute and want to
# substitute default value - use '-u' option to specify that (do note that
# default value is in fact compared against -w and -c), but be carefull that
# you know what you're doing and know for sure you need this functionality.
#
# Additionally if you want performance output then use '-f' option to get all
# the attributes specified in '-a' or specify particular list of attributes for
# performance data with '-A' (this list can include names not found in '-a').
# A special option of -A '*' will allow to get data from all attrbutes found
# when browsing the names table.
#
# ============================= SETUP EXAMPLES ===============================
#
# define command {
#        command_name check_snmp_dell_fanspeed
#        command_line $USER1$/check_snmp_table.pl -N .1.3.6.1.4.1.674.10892.1.700.12.1.8 -D .1.3.6.1.4.1.674.10892.1.700.12.1.6 -f -H $HOSTADDRESS$ -C $ARG1$ -a $ARG2$ --warn=$ARG3$ --crit=$ARG4$
# }
#
# define command {
#        command_name check_snmp_dell_voltage
#        command_line $USER1$/check_snmp_table.pl -N .1.3.6.1.4.1.674.10892.1.600.20.1.8 -D .1.3.6.1.4.1.674.10892.1.600.20.1.6 -f -H $HOSTADDRESS$ -C $ARG1$ --attributes=$ARG2$ --warn=$ARG3$ --crit=$ARG4$
#}
#
# define service{
#        use                             std-service
#        servicegroups                   snmp,envresources
#        hostgroup_name                  dell_1750
#        contact_groups                  admins
#        service_description             Dell 1750 System Fans
#        check_command                   check_snmp_dell_fanspeed!public!'Fan 1,Fan 2,Fan 3,Fan 4,Fan 5,Fan 6'!'^7500,^7500,^7500,^7500,^7500,^7500'!'<2500,<2500,<2500,<2500,<2500,<2500'
# }
#
# define service{
#        use                             std-service
#        servicegroups                   snmp,envresources
#        hostgroup_name                  dell_1750
#        service_description             Dell 1750 Voltage
#        check_command                   check_snmp_dell_voltage!public!"1.5,1.8,2.5,3.3,5,12,BP 3.3V,BP 5V,BP 12V,Battery,CPU"!'<1341,<1612,<2257,<2958,<4428,<11058,<2924,<4519,<10810,~,<1310'!'>1689,>2012,>2786,>3732,>5748,>13696,>3625,>5511,>13166,~,>1818'
# }
#
# =================================== TODO ===================================
#
# 1. The biggest current limitation is that you can not specify both '<' and '>'
#    for the same type of check, i.e. for CRITICAL or for WARNING and as with
#    above example either smaller or highier endup as CRITICAL alert and the
#    other as WARNING - this should really be done so that you can choose
#    either one easily, i.e, there should be way to specify multiple
#    thresholds for the same value type.
#     Note: I have tentatively decided to do this as ",<100|>200," and with #2
#           below started on v0.4 version of this code (April 2006) - but its
#           ending up being rather complex code to support both manual values
#           and threshold tables. Current plan is for now to rework it all
#           and redo existing code to support "|" and later do general library
#           that is more extensive and can be reused by multiple plugins.
#    Note2 [Oct 2006]: check_netstat is using almost same algorithm for
#          checking but allows to specify value more then once when its
#          needed to be checked  both for low and high numbers, maybe
#          that is better alternative then "|"...
# 2. Number of sensors have related table that specify the thresholds already
#    so its of interest to add -W and -C options to specify such base tables.
#    This is however most useful if those threshold numbers can be cached
#    in a file rather then being checked every time.
# 3. For certain types of sensors it maybe of interest to check rate of
#    change rather then compare to exact value. This requires temperary file
#    be used for storing data (as does #2 above).
# 4. More examples and better documentation (including website) is needed for
#    how to use this plugin...
#
# Note: I don't know when I'd get to doing above, my schedule is very busy and
#       if something satisfies current needs additions are getting delayed...
#       If you want #1 - #3 done faster contact me to explain your situation
#       but be warned that I'll most likely ask your help with at least #4
#       (i.e. help with website & documentation for my nagios related work)
#
# ========================== START OF PROGRAM CODE ============================

use strict;

use Net::SNMP;
use Getopt::Long;

use lib "/usr/lib/nagios/plugins";
use utils qw(%ERRORS $TIMEOUT);
# uncomment two lines below and comment out two above lines if you do not have nagios' utils.pm
# my $TIMEOUT = 20;
# my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

my $Version='0.3';

my $o_host=     undef;          # hostname
my $o_community= undef;         # community
my $o_port=     161;            # SNMP port
my $o_help=     undef;          # help option
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # version info option
my $o_timeout=  5;              # Default 5s Timeout
my $o_version2= undef;          # use snmp v2c
# SNMPv3 specific
my $o_login=    undef;          # Login for snmpv3
my $o_passwd=   undef;          # Pass for snmpv3

my $o_perf=     undef;          # Performance data option
my $o_attr=	undef;  	# What attribute(s) to check (specify more then one separated by '.')
my @o_attrL=    ();             # array for above list
my $o_perfattr= undef;		# List of attributes to only provide values in perfomance data but no checking
my @o_perfattrL=();		# array for above list
my $o_warn=     undef;          # warning level option
my @o_warnLv=   ();             # array of warn values
my @o_warnLp=	();		# array of warn data processing modifiers
my $o_crit=     undef;          # Critical level option
my @o_critLv=   ();             # array of critical values
my @o_critLp=	();		# array of critical data processing modifiers	
my $oid_names=	undef;		# OID for base table of attribute names
my $oid_data=	undef;		# OID for table of actual data for those attributes found when walking name base
my $o_unkdef=	undef;		# Default value to report for unknown attributes
my $o_datatblretr= undef;	# Retrieve data together as one table instead if individual attribute OIDs
my $o_label=    '';             # Label used to show what is in plugin output

sub print_version { print "$0: $Version\n" };

sub print_usage {
	print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd)  [-P <port>] -N <oid_namestable> -D <oid_datatable> [-R] [-a <attributes to check> -w <warn levels> -c <crit levels> [-f]] [-A <attributes for perfdata>] [-t <timeout>] [-V] [-u <unknown_default>]\n";
}

# Return true if arg is a number
sub isnum {
	my $num = shift;
	if ( $num =~ /^([-|+]?(\d+\.?\d*)|[-|+]?(^\.\d+))$/ ) { return 1 ;}
	return 0;
}

sub help {
	print "\nGeneral SNMP Table Attributes Monitor for Nagios version ",$Version,"\n";
	print " by William Leibzon - william(at)leibzon.org\n\n";
	print_usage();
	print <<EOD;
-v, --verbose
	print extra debugging information
-h, --help
	print this help message
-L, --label
        Plugin output label
-H, --hostname=HOST
	name or IP address of host to check
-C, --community=COMMUNITY NAME
	community name for the host's SNMP agent (implies v 1 protocol)
-P, --port=PORT
	SNMPD port (Default 161)
-2, --v2c
        use SNMP v2 (instead of SNMP v1)
-w, --warn=STR[,STR[,STR[..]]]
	Warning level(s) - usually numbers (same number of values specified as number of attributes)
	Warning values can have the following prefix modifiers:
	   > : warn if data is above this value (default for numeric values)
	   < : warn if data is below this value (must be followed by number)
	   = : warn if data is equal to this value (default for non-numeric values)
	   ! : warn if data is not equal to this value
	   ~ : do not check this data (must not be followed by number)
	   ^ : for numeric values this disables checks that warning is less then critical
-c, --crit=STR[,STR[,STR[..]]]
	critical level(s) (if more then one name is checked, must have multiple values)
	Critical values can have the same prefix modifiers as warning (see above) except '^'
-t, --timeout=INTEGER
	timeout for SNMP in seconds (Default : 5)
-V, --version
	prints version number
-N, --oid_attribnames=OID_STRING
	Base OID to walk through to find names of those attributes supported and from that corresponding data OIDs
-D, --oid_attribdata=OID_STRING
	BASE OID for sensor attribute data, attrib names unique number is added to that to make up full attribute OID
-R, --retreive_tablewalk
	If used forces retrieval of data by walking the tree in the same way name of attributes parameters is found
-a, --attributes=STR[,STR[,STR[..]]]
	Which attribute(s) to check. This is used as regex to check if attribute is found in attribnames table
-A, --perf_attributes=STR[,STR[,STR[..]]]
	Which attribute(s) to add to as part of performance data output. These names can be different then the
	ones listed in '-a' to only output attributes in perf data but not check. Special value of '*' gets them all.
-f, --perfparse
        Used only with '-a'. Causes to output data not only in main status line but also as perfparse output
-u, --unknown_default=INT
        If attribute is not found then report the output as this number (i.e. -u 0)
EOD
}

# For verbose output - don't use it right now
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
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'P:i'   => \$o_port,            'port:i'        => \$o_port,
        'C:s'   => \$o_community,       'community:s'   => \$o_community,
        'l:s'   => \$o_login,           'login:s'       => \$o_login,
        'x:s'   => \$o_passwd,          'passwd:s'      => \$o_passwd,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
        '2'     => \$o_version2,        'v2c'           => \$o_version2,
	'L:s'   => \$o_label,           'label:s'       => \$o_label,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
        'f'     => \$o_perf,            'perfparse'      => \$o_perf,
        'a:s'   => \$o_attr,         	'attributes:s' 	=> \$o_attr,
	'A:s'	=> \$o_perfattr,	'perf_attributes:s' => \$o_perfattr,
	'u:i'	=> \$o_unkdef,		'unknown_default:i' => \$o_unkdef,
	'N:s'	=> \$oid_names,		'oid_attribnames:s' => \$oid_names,
	'D:s'	=> \$oid_data,		'oid_attribdata:s'  => \$oid_data,
	'R'	=> \$o_datatblretr,	'retreive_tablewalk' => \$o_datatblretr
    );
    if (defined($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}; }
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}; }
    if (! defined($o_host) ) # check host and filter
        { print "No host defined!\n";print_usage(); exit $ERRORS{"UNKNOWN"}; }
    # check snmp information
    if (!defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
        { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
    if (!defined($oid_names) || !defined($oid_data))
	{ print "Base SNMP OIDs for name and data are required!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }

    if (defined($o_perfattr)) {
        @o_perfattrL=split(/,/ ,$o_perfattr) if defined($o_perfattr);
    }
    if (defined($o_warn) || defined($o_crit) || defined($o_attr)) {
        if (defined($o_attr)) {
          @o_attrL=split(/,/, $o_attr);
          @o_warnLv=split(/,/ ,$o_warn) if defined($o_warn);
          @o_critLv=split(/,/ ,$o_crit) if defined($o_crit);
        }
        else {
          print "Specifying warning and critical levels requires '-a' parameter with attribute names\n";
          print_usage();
          exit $ERRORS{"UNKNOWN"};
        }
        if (scalar(@o_warnLv)!=scalar(@o_attrL) || scalar(@o_critLv)!=scalar(@o_attrL)) {
          printf "Number of specified warning levels (%d) and critical levels (%d) must be equal to the number of attributes specified at '-a' (%d). If you need to ignore some attribute specify it as '~'\n", scalar(@o_warnLv), scalar(@o_critLv), scalar(@o_attrL);
          print_usage();
          exit $ERRORS{"UNKNOWN"};
	}
        for (my $i=0; $i<scalar(@o_attrL); $i++) {
		$o_warnLv[$i] =~ s/^(\^?[>|<|=|!|~]?)//;
		$o_warnLp[$i] = $1;
		$o_critLv[$i] =~ s/^([>|<|=|!|~]?)//;
                $o_critLp[$i] = $1;
		if (($o_warnLp[$i] =~ /^[>|<]/ && !isnum($o_warnLv[$i])) ||
		    ($o_critLp[$i] =~ /^[>|<]/ && !isnum($o_critLv[$i]))) {
			print "Numeric value required when '>' or '<' are used !\n";
			print_usage();
			exit $ERRORS{"UNKNOWN"};
          	}
		if (isnum($o_warnLv[$i]) && isnum($o_critLv[$i]) && $o_warnLp[$i] eq $o_critLp[$i] && (
		      ($o_warnLv[$i]>=$o_critLv[$i] && $o_warnLp[$i] !~ /</) ||
		      ($o_warnLv[$i]<=$o_critLv[$i] && $o_warnLp[$i] =~ /</)
		   )) {
			print "Problem with warning value $o_warnLv[$i] and critical value $o_critLv[$i] :\n";
                        print "All numeric warning values must be less then critical (or greater then when '<' is used)\n";
			print "Note: to override this check prefix warning value with ^\n";
                        print_usage();
                        exit $ERRORS{"UNKNOWN"};
		}
		$o_warnLp[$i] =~ s/\^//;
		$o_warnLp[$i] = '=' if !$o_warnLp[$i] && !isnum($o_warnLv[$i]);
		$o_warnLp[$i] = '>' if !$o_warnLp[$i] && isnum($o_warnLv[$i]);
		$o_critLp[$i] = '=' if !$o_critLp[$i] && !isnum($o_critLv[$i]);
		$o_critLp[$i] = '>' if !$o_critLp[$i] && isnum($o_critLv[$i]);
        }
    }
    if (scalar(@o_attrL)==0 && scalar(@o_perfattrL)==0) {
        print "You must specify list of attributes with either '-a' or '-A'\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }
}

# help function used when checking SNMP data against critical and warn values
sub check_value {
    my ($attrib, $data, $level, $modifier) = @_;

    return "" if $modifier eq '~';
    return " " . $attrib . " is " . $data . " = " . $level if $modifier eq '=' && $data eq $level;
    return " " . $attrib . " is " . $data . " != " . $level if $modifier eq '!' && $data ne $level;
    return " " . $attrib . " is " . $data . " > " . $level if $modifier eq '>' && $data>$level;
    return " " . $attrib . " is " . $data . " < " . $level if $modifier eq '<' && $data<$level;
    return "";
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

# next part of the code builds list of attributes to be retrieved
my $i;
my $oid;
my $line;
my $line2;
my $attr;
my @varlist = ();
my %dataresults;

for ($i=0;$i<scalar(@o_attrL);$i++) {
  $dataresults{$o_attrL[$i]} = ["check", undef, undef, undef];
}
if (defined($o_perfattr) && $o_perfattr ne '*') {
  for ($i=0;$i<scalar(@o_perfattrL);$i++) {
    $dataresults{$o_perfattrL[$i]} = ["perf", undef, undef, undef];
  }
}

verb("Retrieving SNMP table $oid_names");
my $result = $session->get_table( -baseoid => $oid_names );
if (!defined($result)) {
        printf("ERROR: Problem retrieving OID %s table: %s.\n", $oid_names, $session->error);
        $session->close();
        exit $ERRORS{"UNKNOWN"};
}
L1: foreach $oid (Net::SNMP::oid_lex_sort(keys %{$result})) {
        $line=$result->{$oid};
        verb("got $oid : $line");
	foreach $attr (keys %dataresults) {
	   if ($line =~ m/$attr/) {
		$oid =~ s/$oid_names/$oid_data/;
		$dataresults{$attr}[1] = $oid;
		$dataresults{$attr}[2] = $line;
		push(@varlist,$oid);
		verb("match found for $attr, now set to retrieve $oid");
		next L1;
	   }
	}
	if (defined($o_perfattr) && $o_perfattr eq '*') {
		$oid =~ s/$oid_names/$oid_data/;
		($line2 = $line) =~ s/[^\w\s]/ /;
		$dataresults{$line2} = ["perf", $oid, $line, undef];
		push(@varlist,$oid);
		verb("match found based on -A '*', now set to retrieve $oid");
	}
}

# now we actually retrieve the attributes
my $statuscode = "OK";
my $statusinfo = "";
my $statusdata = "";
my $perfdata = "";
my $chk = "";

if (defined($o_datatblretr)) {
	verb("Retrieving SNMP table $oid_names");
	$result = $session->get_table( -baseoid => $oid_data );
	if (!defined($result)) {
        	printf("ERROR: Problem retrieving OID %s table: %s.\n", $oid_data, $session->error);
        	$session->close();
        	exit $ERRORS{"UNKNOWN"};
	}
}
else {
	verb("Getting SNMP data for oids" . join(" ",@varlist));
	$result = $session->get_request(
		-Varbindlist => \@varlist
	);
	if (!defined($result)) {
		printf("ERROR: Can not retrieve OID(s) %s: %s.\n", join(" ",@varlist), $session->error);
		$session->close();
		exit $ERRORS{"UNKNOWN"};
	}
}

# loop to load values into dataresults array
foreach $attr (keys %dataresults) {
	if (defined($dataresults{$attr}[1]) && defined($result->{$dataresults{$attr}[1]})) {
		$dataresults{$attr}[3]=$result->{$dataresults{$attr}[1]};
		verb("got $dataresults{$attr}[1] : $attr = $dataresults{$attr}[3]");
	}
	else {
		if (defined($o_unkdef)) {
		   $dataresults{$attr}[3]=$o_unkdef;
		   verb("could not find snmp data for $attr, setting to to default value $o_unkdef");
		}
		else {
		   verb("could not find snmp data for $attr");
		}
	}
}

# loop to check if warning & critical attributes are ok
for ($i=0;$i<scalar(@o_attrL);$i++) {
    if (defined($dataresults{$o_attrL[$i]}[3])) {
	if ($chk = check_value($o_attrL[$i],$dataresults{$o_attrL[$i]}[3],$o_critLv[$i],$o_critLp[$i])) {
		$statuscode = "CRITICAL";
		$statusinfo .= $chk;
	}
	elsif ($chk = check_value($o_attrL[$i],$dataresults{$o_attrL[$i]}[3],$o_warnLv[$i],$o_warnLp[$i])) {
               	$statuscode="WARNING" if $statuscode eq "OK";
                $statusinfo .= $chk;
        }
    	else {
		$statusdata .= "," if ($statusdata);
		$statusdata .= " " . $o_attrL[$i] . " is " . $dataresults{$o_attrL[$i]}[3] ;
    	}
        $perfdata .= " " . $o_attrL[$i] . "=" . $dataresults{$o_attrL[$i]}[3] if defined($o_perf) && $dataresults{$o_attrL[$i]}[0] ne "perf";
    }
    else {
	$statusdata .= "," if ($statusdata);
        $statusdata .= " $o_attrL[$i] data is missing";
    }
}

# add data for performance-only attributes
if (defined($o_perfattr) && $o_perfattr eq '*') {
  foreach $attr (keys %dataresults) {
     if ($dataresults{$attr}[0] eq "perf" && defined($dataresults{$attr}[3])) {
	$perfdata .= " " . $dataresults{$attr}[2] . "=" . $dataresults{$attr}[3];
     }
  }
}
else {
  for ($i=0;$i<scalar(@o_perfattrL);$i++) {
     if (defined($dataresults{$o_perfattrL[$i]}[3])) {
	$perfdata .= " " . $o_perfattrL[$i] . "=" . $dataresults{$o_perfattrL[$i]}[3];
     }
  }
}

$session->close;
$o_label .= " " if $o_label ne '';
print $o_label . $statuscode;
print " -".$statusinfo if $statusinfo;
print " -".$statusdata if $statusdata;
print " |".$perfdata if $perfdata;
print "\n";

exit $ERRORS{$statuscode};
