#!/usr/bin/perl
#
# ============================== SUMMARY =====================================
#
# Program : check_tftp.pl
# Version : 0.11
# Date    : Nov 24 2006 
#           (added all the top comments you see, no code changes since 2005?)
# Author  : William Leibzon - william@leibzon.org
# Summary : This is a nagios plugin that verifies TFTP server is working
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
# This is a very simple nagios plugin that checks if TFTP server is up
# It is using Net::TFTP perl module for protocol support
# There are two required parameters/arguments:
#   $1 - HOSTNAME to check
#   $2 - file to retrieve for this check
# An example of how to use this is as follows:
#
#define command{
#        command_name    check_tftp
#        command_line    $USER1$/check_tftp.pl $HOSTADDRESS$ X86PC/UNDI/linux-install
#        }
#
#define service{
#       use                             generic-service
#       hostgroup_name                  dhcpserv
#       service_description             TFTP
#       check_command                   check_tftp
#       }
# =================================== TODO ===================================
#
#  1. Using GetOpt::Long for specifying parameters including timeout &
#     number of retries
#  2. Check to make sure file is writable rather then just read-only check
#
#  Note: I'm unlikely to work on this plugin unless somebody writes me they
#        actually want "tftp write" or similar feature.
#
# ========================== START OF PROGRAM CODE ===========================

use strict;
use Net::TFTP;
use FileHandle;

# Nagios specific
# use lib "/usr/local/nagios/libexec";
# use utils qw(%ERRORS $TIMEOUT);
my $TIMEOUT = 20;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

sub print_usage {
   print "TFTP Monitor for Nagios by william(at)leibzon.org\n\n";
   print "Usage:  check_tftp.pl hostname filename\n";
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
my $FILENAME = $ARGV[1];

alarm($TIMEOUT);

my $tftp = Net::TFTP->new($HOSTNAME, Port => 69, Retries => 2);
my $err=$tftp->error();
my $fh=$tftp->get($FILENAME);

if (!$fh || $err) {
  print "CRITICAL ERROR - could not retrieve $FILENAME from $HOSTNAME using tftp - $err\n";
  exit $ERRORS{"CRITICAL"};
}
else {
  my $data = $fh->getline;
  $err = $tftp->error();
  if (defined($data) && !$err) {
    print "TFTP OK - file $FILENAME present on server $HOSTNAME\n";
    exit $ERRORS{"OK"};
  }
  else {
    print "CRITICAL ERROR - could not retrieve $FILENAME from $HOSTNAME using tftp - $err\n";
    exit $ERRORS{"CRITICAL"};
  }
}
