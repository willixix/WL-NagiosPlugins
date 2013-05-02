#!/usr/bin/perl
#
# ============================== SUMMARY =====================================
#
# Program : check_localtime.pl
# Version : 0.11
# Date    : Nov 24 2006
#           (all this top section added, also small code for output format)
# Author  : William Leibzon - william@leibzon.org
# Summary : This is a nagios plugin that display local time and can return
#           CRITICAL for specified timeperiods to impliment heartbeat
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
# This is a simple nagios plugin to report localtime of the nagios system itself
# (or remote system when this is used with NRPE).
#
# It has interesting feature in that it accepts (one or more) parameters for certain
# timerange and report CRITICAL value if local time is within that range. This can
# be used to setup daily 'hearbeat' alerts for example as follows:
#
# define command {
#        command_name daily_alert
#        command_line $USER1$/check_localtime.pl $ARG1$ $ARG2$
# }
#
# define service{
#        use                             generic-service
#        host_name                       nagios
#        service_description             Heartbeat Alert
#        check_command                   daily_alert!9:00-9:10!21:00-21:10
#        is_volatile                     0
#        check_period                    24x7
#        max_check_attempts              1
#        normal_check_interval           1
#        retry_check_interval            1
#        notification_interval           0
#        }
#
# =================================== TODO ===================================
#
# 1. Currently accepts fixed format parameters "hour:minute-hour:minute".
#    It maybe interesting to extend for example to specify day of the week
#    to allow for one CRITICAL period during the week...
# 2. There is a bug in that it can not properly handle range like "23:55-00:05"
#    this is really related to #1 above as far as limits of current input
# 3. Allow for alert to be WARNING rather then CRITICAL
#
# Note: I'm unlikely to work any of the above any time soon actually...
#       Send me an email if you really need it.
#
# ========================== START OF PROGRAM CODE ===========================

use strict;
use Time::Local;

my $ctime=time();
my ($sec,$min,$hr,$mday,$mon,$year) = localtime($ctime);
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my $return_code="OK";
my $return_info="";
foreach (@ARGV) {
        if (/(\d+):(\d+)(-(\d+):(\d+))?/) {
                if (!$3 && $1 == $hr && $2 == $min) {
                        $return_code="CRITICAL";
			$return_info.="(within $_ range)";
                }
                elsif ($1 && $2 && $4 && $5) {
                        my $t1 = timelocal(0,$2,$1,$mday,$mon,$year);
                        my $t2 = timelocal(0,$5,$4,$mday,$mon,$year);
			if ($t1 <= $ctime && $ctime <= $t2) {
				$return_code = "CRITICAL";
				$return_info.="(within $_ range)";
			}
                }
        }
}
printf "%s: localtime is %02d:%02d:%02d", $return_code, $hr, $min, $sec;
print " ".$return_info if $return_info;
print "\n";
exit $ERRORS{$return_code};
