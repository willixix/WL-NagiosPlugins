#!/usr/bin/perl
#
# ============================== SUMMARY =====================================
#
# Program : check_daytime.pl
# Version : 0.2
# Date    : Nov 24 2006
# Author  : William Leibzon - william@leibzon.org
# Summary : This is a nagios plugin that can use 'daytime' or 'time' (RFC868)
#           to make sure time on remote host is same as on localhost
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
# This plugin checks that time on remote host is no more then specified number
# of seconds different then on nagios server. The time is checked using TCP
# or UDP using either daytime (port 13) or time (port 37) protocols. For more
# information about using this plugin use '-h' option
#
# ========================== START OF PROGRAM CODE ===========================

use strict;
use IO::Socket::INET;
use IO::Select;
use Date::Parse;
use Getopt::Long;

my $TIMEOUT = 5;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

my $Version='0.2';

my $o_host=     undef;          # hostname
my $o_protocol= undef;          # Protocol to use (either 'daytime' or 'daytime-udp' or 'time' or 'time-udp'
my $o_port=     undef;          # Port to use (allows to override default port defined for the protocol)
my $o_help=     undef;          # help option
my $o_timeout=  $TIMEOUT;       # Default 10s Timeout
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # version info option
my $o_warn=     undef;          # warning level option
my $o_crit=     undef;          # Critical level option
my $o_perf=     undef;          # Performance data option
my $o_formout=  'str';          # Format of output string
my $proto=      undef;          # Set to "tcp" or "udp" based o_protocol option

sub print_version { print "$0: $Version\n" };

sub print_usage {
        print "Usage: $0 -v | -h | -P daytime|daytime-udp|time|time-udp [-p <port>] -H <hostname> [-w <warning variance>] [-c <critical variance>] [-t <timeout seconds>] [-o str|usec] [-f]\n\n";
        print "This is a nagios plugin that connects to remote host using protocol specified with -P\n";
	print "which can be either daytime (port 13) or RRC868 time service (port 37) running on TCP or UDP\n";
	print "and then checks that time specified on remote host is no more then <variance> seconds\n";
	print "different then local time on host executing this plugin. Port numbers (13 or 37) above\n";
	print "can optionally be overridden with -p option. If daytime service is used the string\n";
	print "returned by remote host should be in the format like '01 JAN 2006 12:01:01 PDT'\n";
        print "\ncheck_daytime plugin v. $Version by william(at)leibzon.org, licensed under GPL\n" if !defined($o_help);
}

sub print_help {
	print "\ncheck_daytime plugin for nagios version ",$Version,"\n";
	print " by William Leibzon - william(at)leibzon.org\n\n";
	print_usage();
	print <<EOD;

-v, --verbose
	print extra debugging information
-h, --help
	print this help message
-H, --hostname=HOST (STRING)
	name or IP address of host to check (required parameter)
-P, --protocol=daytime|daytime-udp|time|time-udp
        protocol used to get remote time (required paramter)
	note that daytime protocol should give one string like
	'01 JAN 2006 12:01:01 PDT' (its parsed with Date::Parse str2time)
-p, --port=port (INTEGER)
        This overrides default values set based on '--protocol' parameter
	which are by default 13 for daytime and 37 for time protocols
-w, --warn=variance (INTEGER)
        If the difference between remote host and localhost is more then equal to this
        number of  seconds then cause WARNING returned to Nagios
-c, --critical=variance (INTEGER)
        If the difference between remote host and localhost is more then equal to this
        number of  seconds then cause CRITICAL error returned to Nagios
-t, --timeout=seconds (INTEGER)
	timeout for network connection (default : 5 seconds)
-f, --perfparse
        Causes time & difference not only in main status line but also as perfparse output
-o, --formout=str|usec
        Time printed as output is a readable time string when 'str' is specified (default)
	or unix seconds with 1970 (when usec is specified)
EOD
}

sub error_end { print for @_; exit $ERRORS{'UNKNOWN'}; }

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

# Get the alarm signal (just in case snmp timeout screws up)
$SIG{'ALRM'} = sub {
     error_end("ERROR: Timeout on alarm signal\n");
};

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'P:s'   => \$o_protocol,        'protocol:s'    => \$o_protocol,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'c:i'   => \$o_crit,            'critical:i'    => \$o_crit,
        'w:i'   => \$o_warn,            'warn:i'        => \$o_warn,
        'p:i'   => \$o_port,         	'port:i' 	=> \$o_port,
        'f'     => \$o_perf,            'perfparse'     => \$o_perf,
	'o:s'   => \$o_formout,         'formout:s'     => \$o_formout
    );
    if (defined($o_help)) { print_help(); exit $ERRORS{"UNKNOWN"}; }
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}; }
    if ($o_formout!='usec' && $o_formout!='str') {
	print "Invalid format for output time (-o option)\n\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"};
    }
    if (!defined($o_protocol) || !defined($o_host)) {
	print "Hostname (-H) and protocol (-P) are required parameters for this plugin\n\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"};
    }
    else {
        # Select which port and transport protocol is to be used based on "-P" parameter to the plugin
	if ($o_protocol eq "daytime") {
	    $o_port = 13 if !defined($o_port);
	    $proto = "tcp";
	}
	elsif ($o_protocol eq "daytime-udp") {
	    $o_port = 13 if !defined($o_port);
	    $proto = "udp";
	}
	elsif ($o_protocol eq "time") {
	    $o_port = 37 if !defined($o_port);
	    $proto = "tcp";
	}
	elsif ($o_protocol eq "time-udp") {
	    $o_port = 37 if !defined($o_port);
	    $proto = "udp";
	}
        else {
	    print "Invalid protocol name $o_protocol specified with -P\n\n";
	    print_usage();
	    exit $ERRORS{"UNKNOWN"};
	}
    }
}

########## MAIN #######
my $return_code="OK";
my $remotedatestring = "";
my $rtime = 0;
my $ltime = 0;
my $df = 0;

check_options();

# Set global timeout just in case something goes really wrong
verb("Alarm at ".($o_timeout+5));
alarm($o_timeout+5);

# Open socket and then select. Also for udp send empty datagram
verb("Connecting to $o_host using $proto on port $o_port");
my $socket = IO::Socket::INET->new(PeerAddr => $o_host, PeerPort => $o_port, Proto => $proto)
	or error_end("Could not connect to $o_host on $proto port $o_port\n");
$socket->send("\n") if $proto eq "udp";
IO::Select->new($socket)->can_read($o_timeout)
	or error_end "Timeout after $o_timeout while doing select when connecting to $o_host on $proto port $o_port\n";

# Receive and process response packet and then close socket
if ($o_protocol eq "daytime" || $o_protocol eq "daytime-udp") {
	$socket->recv($remotedatestring, 256);
	verb("daytime protocol: got string $remotedatestring");
	# str2time is from Date::Parse library
	$rtime = str2time($remotedatestring);
}
elsif ($o_protocol eq "time" || $o_protocol eq "time-udp") {
	$socket->recv($remotedatestring, length(pack("N",0)));
	verb(sprintf("time protocol: got hex string %X",(unpack("N",$remotedatestring))[0]));
	# time protocol on port 37 returns seconds since 1900 (17 below is for leap years to get to 1969)
	$rtime = (unpack("N",$remotedatestring))[0] | 0;
	$rtime -= (70*31536000 + 17*86400);
}
close $socket;

# Now find local time and calculate difference with what has been received and check warning and critical values
$ltime = time();
$df = $rtime - $ltime;
$df = -$df if $df < 0;
verb("$o_host time since 1969 is $rtime, localhost time is $ltime, difference is $df");
if (defined($o_warn) && $df >= $o_warn) {
	$return_code = "WARNING";
}
if (defined($o_crit) && $df >= $o_crit) {
	$return_code = "CRITICAL";
}

# Print result that nagios can use and exit
print "TIME $return_code - $o_host time is ";
if ($o_formout eq 'usec') {
    print $rtime;
}
else {
    print scalar(localtime($rtime));
}
print " ($df seconds variance)";
print " | time=$rtime diff=$df" if $o_perf;
print "\n";
exit $ERRORS{$return_code};
