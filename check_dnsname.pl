#!/usr/bin/perl
#
# ============================== SUMMARY =====================================
#
# Program : check_dnsname.pl
# Version : 0.11
# Date    : Nov 24 2006
#          (added all the top comments you see, no code changes since 2005?)
# Author  : William Leibzon - william@leibzon.org
# Summary : This is a nagios plugin that makes sure two dns hostnames point
#           to the same set of ip addresses
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
# This is a simple nagios plugin that checks that two dns names (given as
# parameters to the plugin) have same list of ip addresses. Primary it is
# used to check virtual host name & canonical names are properly setup.
# This plugin is using Net:DNS library and should work with both ipv4 & ipv6
# but I only used this with with ipv4...
#
# Here is an example of how to use it to verify logical name for checked host exists:
#
# define command{
#        command_name    check_dns_virtualname
#        command_line    $USER1$/check_dnsname.pl $HOSTADDRESS$ $ARG1$
#        }
#
#
# define service{
#        use                             gerneric-service
#        host_name                       my.example.com
#        service_description             Virtual DNS Name: virtual.example.com
#        check_command                   check_dns_virtualname!virtual_example.com
#        }
#
# =================================== TODO ===================================
#
#  1. Using GetOpt::Long for specifying parameters like timeout, etc
#  2. Report how long dns resolution took for each name and warn if there
#     are significant differences
#  3. Allow multiple names to be checked (more then 2 dns names specified
#     as parameters)
#
# ========================== START OF PROGRAM CODE ===========================

use strict;
use Net::DNS;

# Nagios specific
# use lib "/usr/local/nagios/libexec";
# use utils qw(%ERRORS $TIMEOUT);
my $TIMEOUT = 30;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

sub print_usage {
   print "Nagios plugin to verify dns names by william(at)leibzon.org\n\n";
   print "Usage:  check_dnsname.pl realhostname virtualhostname\n";
}

# Get the alarm signal (just in case)
$SIG{'ALRM'} = sub {
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $ERRORS{"CRITICAL"};
};

if (!defined($ARGV[0]) || !defined($ARGV[1])) {
  print_usage();
  exit $ERRORS{"UNKNOWN"};
}

my $HOSTNAME = $ARGV[0];
my $LOGICALNAME = $ARGV[1];

alarm($TIMEOUT);

my $res = Net::DNS::Resolver->new;
my %ip_addresses;

my $err = get_ipaddresses(\%ip_addresses, $res, $HOSTNAME);
if ($err) {
  print "CRITICAL ERROR - could not do lookup on $HOSTNAME - $err";
  exit $ERRORS{"CRITICAL"};
}
$err = get_ipaddresses(\%ip_addresses, $res, $LOGICALNAME);
if ($err) {
  print "CRITICAL ERROR - could not do lookup on $LOGICALNAME - $err";
  exit $ERRORS{"CRITICAL"};
}

my $result_ok="";
my $result_error="";
foreach my $ip (keys %ip_addresses) {
  if (defined($ip_addresses{$ip}->[1])) {
	$result_ok .= " $ip";
  }
  else {
	$result_error .= " only $ip_addresses{$ip}->[0] has ip $ip";
  }
}

if ($result_error) {
  print "CRITICAL ERROR -" . $result_error;
  print "- both $HOSTNAME and $LOGICALNAME have address(es)". $result_ok if $result_ok;
  print "\n";
  exit $ERRORS{"CRITICAL"};
}
else {
  if ($result_ok) {
	print "OK - $HOSTNAME and $LOGICALNAME are" . $result_ok . "\n";
	exit $ERRORS{"OK"};
  }
  else {
	print "WARNING - no ip addresses found for $HOSTNAME and $LOGICALNAME\n";
	exit $ERRORS{"WARNING"};
  }
}

# should never get here...

sub get_ipaddresses{
  my ($ip_hash, $dnsres, $lookupname) = @_;

  my $query = $dnsres->search($lookupname);
  if ($query) {
    foreach my $rr ($query->answer) {
	if ($rr->type eq "A") {
		if (defined($ip_hash->{$rr->address})) {
			my $temp = $ip_hash->{$rr->address};
			push(@$temp, $lookupname);
		}
		else {
			$ip_hash->{$rr->address} = [$lookupname];
		}
  	}
    }
    return "";
  }
  else {
    return $dnsres->errorstring;
  }
}
