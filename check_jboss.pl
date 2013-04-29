#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_jboss.pl
# Version : 0.31
# Date    : May 16, 2007
# Author  : William Leibzon - william@leibzon.org
# Summary : This is a nagios plugin to check jboss parameters by means
#           of twindle utility on the same host
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
# ============================= SETUP NOTES ==================================
#
# This is a nagios plugin to check JBOSS server attributes. It requires
# local JBOSS provided twiddle utility to be available and will call it
# (and consequently JAVA process) to actually connect to JBOSS server.
# Therefore keep in mind that this plugin requires rather heavy processing
# and you're lot better off doing this through NRPE.
#
# For setup make sure to adjust path to twiddle which is rather non-standard
# in this plugin by default (/opt/jboss/bin/twiddle) and make sure you have
# either utils.pm in the directory specified with "use lib" or comment it out
# uncomment 'my %ERRORS' and 'my $TIMEOUT'.
#
# The attributes are data attributes of JBOSS bean which you must
# specify with '-J'; specifying type with '-T' is also required by
# twiddle, please see documentation for JBOSS and twiddle.
#
# For each attribute you specify in '-a' you must also specify warning
# and critical values in the same order in '-w' and '-c' (see below)
# Using '-f' would cause all attribute values to also be available
# for Nagios performance processing and with '-A' you can specify
# list of that attributes even if they are not otherwise listed in
# '-a' (you can also do '-A *' to just get all the atributes).
#
# Warning and critical levels are specified with '-w' and '-c' and each
# one must have exact same number of values (separated by ',') as number
# of attribute names specified with '-a'. Any values you dont want
# to compare you specify as ~ (or just not specify a value, i.e. ',,').
# There are also number of other one-letter modifiers that can be used
# before actual data value to direct how data is to be checked.
# These are as follows:
#    > : issue alert if data is above this value (default for numeric value)
#    < : issue alert if data is below this value (must be followed by number)
#    = : issue alert if data is equal to this value (default for non-numeric)
#    ! : issue alert if data is NOT equal to this value
# A special modifier '^' can also be used to disable checking that warn
# values are less then (or greater then) critical values (it is rarely
# needed). A quick example of specialized use is '--warn=^<100 --crit=>200'
# which will cause warning alert if value is < 100 and critical alert
# if its greater then 200.
#
# =================================== TODO ===================================
#
#  1. [0.3 DONE] Update to my latest format & code for parsing warning & critical
#     parameters so they can be of the form "<value", ">value" as well
#     as "~". Note that in this version the "<value" is specified as
#     "-value" as with check_jboss plugin - but this will be going away!
#  2. Add support for storing values in some file so as to allow to check
#     on rate of change rather then just actual value
#  3. As an option instead of using "twiddle" the data is retrieved
#     from JBoss HTTP status/config data.
#  4. Add full "help" output in the "check_help" function
#  5. [0.2 DONE] Need to change how twiddle its called so that pid of twiddle
#     process is saved and used to kill that process during timeout
#  6. [0.31 DONE] Added -S parameter to specify JMX service instead of type
#     shell is kept and that process can be killed during timeout (otherise
#     it maybe left hanging and become a zombie).
#
# ========================== START OF PROGRAM CODE ============================

use strict;
use Getopt::Long;

my $twiddle = "/opt/jboss/bin/twiddle.sh";
my $tempdir = "/tmp";

# Nagios specific
# use lib "/usr/lib/nagios/plugins";
# use utils qw(%ERRORS $TIMEOUT);
my $TIMEOUT = 20;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

################# DO NOT MODIFY BELOW THIS LINE ########################

my $o_host=     undef;          # hostname
my $o_help=     undef;          # help option
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # version info option
my $o_warn=     undef;          # warning level option
my @o_warnLv=   ();             # array of warn values
my @o_warnLp=   ();             # array of warn data processing modifiers
my $o_crit=     undef;          # Critical level option
my @o_critLv=   ();             # array of critical values
my @o_critLp=   ();             # array of critical data processing modifiers
my $o_perf=     undef;          # Performance data option
my $o_timeout=  5;              # Default 5s Timeout

my $o_jmxmbean= undef;		# JMX MBean to check
my $o_datatype= undef;		# Data type from specified JMX MBean
my $o_servicetype= undef;       # Service type for specified Mbean (use in place of -T)
my $o_jmxattr=  undef;		# Specific MBean attributes to monitor
my @o_jmxattrL= ();		# array from above list
my $o_perfattr= undef;		# JMX Mbean attribute that is only displayed in performance data
my @o_perfattrL= ();		# array from above list
my $tw_pid=undef;

my $Version='0.3';

sub p_version { print "check_jboss version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -J <jmx mbean name> -T <data type from specified mbean> [-H <host>] [-a <attribute list> -w <warn levels> -c <critical levels> [-f]] [-A <attributes for perfomance data>] [-t <timeout>] [-V]\n";
}

# Return true if arg is a number
sub isnum {
  my $num = shift;
  if ( $num =~ /^[-|+]?((\d+\.?\d*)|(^\.\d+))$/ ) { return 1 ;}
  return 0;
}

sub help {
   print "\nJBoss Monitor for Nagios version ",$Version,"\n";
   print " by William Leibzon - william(at)leibzon.org\n\n";
   print_usage();
}

# For verbose output - don't use it right now
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

# Get the alarm signal (just in case this plugin screws up)
$SIG{'ALRM'} = sub {
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     kill 9, $tw_pid if defined($tw_pid);
     exit $ERRORS{"UNKNOWN"};
};

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
	'J:s'   => \$o_jmxmbean,	'jmx_mbean:s'   => \$o_jmxmbean,
	'T:s'	=> \$o_datatype,	'data_type:s'	=> \$o_datatype,
        'S:s'   => \$o_servicetype,     'service_type:s' => \$o_servicetype,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
	'a:s'   => \$o_jmxattr,		'attributes:s'  => \$o_jmxattr,
        'f'     => \$o_perf,            'perfdata'      => \$o_perf,
	'A:s'	=> \$o_perfattr,	'perf_attributes:s' => \$o_perfattr,
    );
    if (defined($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
    if (!defined($o_jmxmbean) || (!defined($o_datatype) && !defined($o_servicetype)))
        { print "No JMX Mbean name or data type specified!\n";print_usage(); exit $ERRORS{"UNKNOWN"}}

    if (defined($o_perfattr)) {
	@o_perfattrL=split(/,/ ,$o_perfattr) if defined($o_perfattr);
    }
    if (defined($o_warn) || defined($o_crit) || defined($o_jmxattr)) {
	if (defined($o_jmxattr)) {
	  @o_jmxattrL=split(/,/, $o_jmxattr);
	  @o_warnLv=split(/,/ ,$o_warn) if defined($o_warn);
	  @o_critLv=split(/,/ ,$o_crit) if defined($o_crit);
	}
	else {
	  print "Specifying warning and critical levels requires '-a' parameter with MBEAN attribute names\n";
	  print_usage();
	  exit $ERRORS{"UNKNOWN"};
        }
	if (scalar(@o_warnLv)!=scalar(@o_jmxattrL) || scalar(@o_critLv)!=scalar(@o_jmxattrL)) {
	  printf "Number of specified warning levels (%d) and critical levels (%d) must be equal to the number of attributes specified at '-a' (%d). If you need to ignore some attribute do it as ',,'\n", scalar(@o_warnLv), scalar(@o_critLv), scalar(@o_jmxattrL);
	  print_usage();
	  exit $ERRORS{"UNKNOWN"};
	}
	for (my $i=0; $i<scalar(@o_jmxattrL); $i++) {
          $o_warnLv[$i] =~ s/^(\^?[>|<|=|!|~]?)//;
          $o_warnLp[$i] = $1;
          $o_warnLp[$i] = "~" if !$o_warnLp[$i] && !$o_warnLv[$i];
          $o_critLv[$i] =~ s/^([>|<|=|!|~]?)//;
          $o_critLp[$i] = $1;
          $o_critLp[$i] = "~" if !$o_critLp[$i] && !$o_critLv[$i];

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
    if (scalar(@o_jmxattrL)==0 && scalar(@o_perfattrL)==0) {
	print "You must specify list of attributes with either '-a' or '-A'\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"};
    }
}

# help function used when checking data against critical and warn values
sub check_value {
    my ($attrib, $data, $level, $modifier) = @_;

    return "" if $modifier eq '~';
    return " " . $attrib . " is " . $data . " = " . $level if $modifier eq '=' && $data eq $level;
    return " " . $attrib . " is " . $data . " != " . $level if $modifier eq '!' && $data ne $level;
    return " " . $attrib . " is " . $data . " > " . $level if $modifier eq '>' && $data>$level;
    return " " . $attrib . " is " . $data . " < " . $level if $modifier eq '<' && $data<$level;
    return "";
}

# twiddle needs to be able to write to twiddle.log file
# this function attempts to make sure it can be done for /tmp/twiddle.log
# or if it can not it will try to create new empty directory in /tmp
sub changedir {
  my $twlogfile="twiddle.log";
  my $maxtry=20;
  my $twdir_prefix="twlog";

  if (!defined($tempdir) || ! -d $tempdir) {
	$tempdir="/tmp"
  }
  my $cnt=0;
  my $twextra="";
  do {
     $twextra="/".$twdir_prefix.$cnt if $cnt!=0;
     if (!chdir($tempdir.$twextra)) {
	chdir $tempdir.$twextra if mkdir($tempdir.$twextra,0755);
     }
     $cnt++;
  }
  until (open(FLT, ">>", $tempdir.$twextra."/".$twlogfile) || $cnt==$maxtry);
  if ($cnt<$maxtry) {
	close FLT;
  	chmod 0777, $tempdir.$twextra."/".$twlogfile;
  }
  else {
	print "Unable to find or create directory within $tempdir tree with writable $twlogfile file\n";
   	exit $ERRORS{"UNKNOWN"};
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

my %dataresults;
my $statuscode = "OK";
my $statusinfo = "";
my $statusdata = "";
my $perfdata = "";
my $chk = "";
my $i;

# prepare command line that will be called and list of attributes hash array
my $twcall=$twiddle;
$twcall .= " -s $o_host" if defined($o_host);
$twcall .= " get " . $o_jmxmbean;
$twcall .= ":type=" . $o_datatype if $o_datatype;
$twcall .= ":service=" . $o_servicetype if $o_servicetype;
for ($i=0;$i<scalar(@o_jmxattrL);$i++) {
  $twcall .= " $o_jmxattrL[$i]";
  $dataresults{$o_jmxattrL[$i]} = ["check", undef];
}
for ($i=0;$i<scalar(@o_perfattrL);$i++) {
  $twcall .= " $o_perfattrL[$i]" if !defined($dataresults{$o_perfattrL[$i]});
  $dataresults{$o_perfattrL[$i]} = ["perf", undef];
}

# here we actually collect the data and put in our hash, very simple actually
changedir();
verb("Executing $twcall");
$tw_pid=open(SHELL_PROCESS,"$twcall 2>&1 |");
if (!$tw_pid) {
    print "UNKNOWN ERROR - unable to execute $twcall - $!";
    exit $ERRORS{"UNKNOWN"};
}
while (<SHELL_PROCESS>) {
  foreach $i (keys %dataresults) {
    $dataresults{$i}[1] = $1 if /$i=(\w+)\s/;
  }
}
close(SHELL_PROCESS);

# main loop to check if warning & critical attributes are ok
for ($i=0;$i<scalar(@o_jmxattrL);$i++) {
  if (defined($dataresults{$o_jmxattrL[$i]}[1])) {
    if ($chk = check_value($o_jmxattrL[$i],$dataresults{$o_jmxattrL[$i]}[1],$o_critLv[$i],$o_critLp[$i])) {
	$statuscode = "CRITICAL";
        $statusinfo .= $chk;
    }
    elsif ($chk = check_value($o_jmxattrL[$i],$dataresults{$o_jmxattrL[$i]}[1],$o_warnLv[$i],$o_warnLp[$i])) {
	$statuscode="WARNING" if $statuscode eq "OK";
	$statusinfo .= $chk;
    }
    else {
	$statusdata .= "," if ($statusdata);
	$statusdata .= " " . $o_jmxattrL[$i] . " is " . $dataresults{$o_jmxattrL[$i]}[1] ;
    }
    $perfdata .= " " . $o_jmxattrL[$i] . "=" . $dataresults{$o_jmxattrL[$i]}[1] if defined($o_perf) && $dataresults{$o_jmxattrL[$i]}[0] ne "perf";
  }
  else {
	$statuscode="CRITICAL";
	$statusinfo .= " $o_jmxattrL[$i] data is missing";
  }
}

# add data for performance-only attributes
for ($i=0;$i<scalar(@o_perfattrL);$i++) {
  if (defined($dataresults{$o_perfattrL[$i]}[1])) {
    $perfdata .= " " . $o_perfattrL[$i] . "=" . $dataresults{$o_perfattrL[$i]}[1];
  }
}

print "JBOSS " . $statuscode . $statusinfo;
print " -".$statusdata if $statusdata;
print " |".$perfdata if $perfdata;
print "\n";

exit $ERRORS{$statuscode};
