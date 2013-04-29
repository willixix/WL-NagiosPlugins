<?php
# ================================ SUMMARY ====================================
#
# File    : check_mmemcached.php
# Version : 0.1
# Date    : Apr 10, 2012
# Author  : William Leibzon - william@leibzon.org
# Summary : PNP4Nagios template for check_memcached.pl
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# This is considered a supplemental file to check_memcached.pl plugin and though
# not distributed in unified package it is distributed under the same licencing
# terms (GNU 2.0 license). Any redisribution of this file in modified form must
# reproduce this summary (modified if appropriate) and must either include
# entire GNU license in a package or list URL where it can be found if
# distributed as a single file.
#
# ===================== INFORMATION ABOUT THIS TEMPLATE =======================
#
# This is a pnp4nagios template for memcache database check done with check_memcached.pl
#
# The template would graph some status variables returned by check_memcached.pl
# Here is an example of nagios command config:
#
# define command {
#    command_name    check_memcached
#    command_line    $USER1$/check_memcached.pl -H $HOSTADDRESS$ -P $ARG1$ -T $ARG2$ -R $ARG3$ -U $ARG4$ -a curr_connections,evictions -w ~,~ -c ~,~ -f -A 'utilization,hitrate,response_time,curr_connections,evictions,cmd_set,bytes_written,curr_items,uptime,rusage_system,get_hits,total_connections,get_misses,bytes,time,connection_structures,total_items,limit_maxbytes,rusage_user,cmd_get,bytes_read,threads,rusage_user_ms,rusage_system_ms,cas_hits,conn_yields,incr_misses,decr_misses,delete_misses,incr_hits,decr_hits,delete_hits,cas_badval,cas_misses,cmd_flush,listen_disabled_num,accepting_conns,pointer_size,pid'
# }
#
# ========================= VERSION HISTORY and TODO ==========================
#
# v0.1  - 03/05/2012 : Initial version of the template created. Includes the following:
#			1. Response Times Graph
#			2. Client Connections Graph
#			3. Network Data Traffic
#			4. Hits and Misses
#			5. Memory Utilization Graph
#			6. Data items
#			7. CPU Usage (this maybe wrong, showing too high)
#
# =============================== END OF HEADER ===============================

$ds_name[0] = "Memcache Response Time";
$opt[0] = "--vertical-label \"$UNIT[3]\" --title \"$servicedesc Response Time on $hostname \" --slope-mode --color=BACK#000000 --color=FONT#F7F7F7 --color=SHADEA#ffffff --color=SHADEB#ffffff --color=CANVAS#000000 --color=GRID#00991A --color=MGRID#00991A --color=ARROW#FF0000 ";
$def[0] =  "DEF:var1=$RRDFILE[3]:$DS[3]:AVERAGE " ;
$def[0] .= "VDEF:slope=var1,LSLSLOPE " ;
$def[0] .= "VDEF:int=var1,LSLINT " ;
$def[0] .= "CDEF:proj=var1,POP,slope,COUNT,*,int,+ " ;
$def[0] .= "LINE2:proj#ff00ff:\"Projection \" " ;
$def[0] .= "GPRINT:var1:LAST:\"%6.2lf$UNIT[3] last\" " ;
$def[0] .= "GPRINT:var1:AVERAGE:\"%6.2lf$UNIT[3] avg\" " ;
$def[0] .= "GPRINT:var1:MAX:\"%6.2lf$UNIT[3] max\\n\" ";
$def[0] .=  "CDEF:sp1=var1,100,/,10,* " ;
$def[0] .=  "CDEF:sp2=var1,100,/,20,* " ;
$def[0] .=  "CDEF:sp3=var1,100,/,30,* " ;
$def[0] .=  "CDEF:sp4=var1,100,/,40,* " ;
$def[0] .=  "CDEF:sp5=var1,100,/,50,* " ;
$def[0] .=  "CDEF:sp6=var1,100,/,60,* " ;
$def[0] .=  "CDEF:sp7=var1,100,/,70,* " ;
$def[0] .=  "CDEF:sp8=var1,100,/,80,* " ;
$def[0] .=  "CDEF:sp9=var1,100,/,90,* " ;
$def[0] .= "AREA:var1#0000A0:\"Response Time \" " ;
$def[0] .= "AREA:sp9#0000A0: " ;
$def[0] .= "AREA:sp8#0000C0: " ;
$def[0] .= "AREA:sp7#0010F0: " ;
$def[0] .= "AREA:sp6#0040F0: " ;
$def[0] .= "AREA:sp5#0070F0: " ;
$def[0] .= "AREA:sp4#00A0F0: " ;
$def[0] .= "AREA:sp3#00D0F0: " ;
$def[0] .= "AREA:sp2#A0F0F0: " ;
$def[0] .= "AREA:sp1#F0F0F0: " ;

$ds_name[1] = "Memcached Client Connections";
$opt[1]  = "--lower-limit=0 --vertical-label \"connections\" --title \"$servicedesc Connections to $hostname\" ";
$def[1]  = rrd::def("curr_conn", $RRDFILE[4], $DS[4], "AVERAGE");
$def[1] .= rrd::def("conn_rate", $RRDFILE[12], $DS[12], "AVERAGE");
$def[1] .= rrd::def("conn_struct", $RRDFILE[16],$DS[16], "AVERAGE");
$def[1] .= rrd::area("curr_conn", "#00FF00", "Current Number of Connections");
$def[1] .= rrd::gprint("curr_conn", array("LAST", "MAX", "AVERAGE"), "%3.0lf ") ;
$def[1] .= rrd::line1("conn_rate", "#0000FF", "New Connnections Per Second  ");
$def[1] .= rrd::gprint("conn_rate", array("LAST", "MAX", "AVERAGE"), "%3.0lf ") ;
# $def[1] .= rrd::line1("conn_struct", "#000000", "Connection Structures");
$def[1] .= rrd::comment("- Total Connection Structures ");
$def[1] .= rrd::gprint("conn_struct", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");

$ds_name[2] = "Data Traffic";
$opt[2]  = " --vertical-label \"bits/sec\" -b 1000 --title \"$servicedesc Net Traffic on $hostname\" ";
$def[2]  = "DEF:bytes_read=$RRDFILE[21]:$DS[21]:AVERAGE ";
$def[2] .= "DEF:bytes_written=$RRDFILE[7]:$DS[7]:AVERAGE ";
$def[2] .= "CDEF:out_bits=bytes_written,8,* ";
$def[2] .= "AREA:out_bits#00ff00:\"out\" " ;
$def[2] .= "GPRINT:out_bits:LAST:\"%7.2lf %Sbit/s last\" " ;
$def[2] .= "GPRINT:out_bits:AVERAGE:\"%7.2lf %Sbit/s avg\" " ;
$def[2] .= "GPRINT:out_bits:MAX:\"%7.2lf %Sbit/s max\\n\" ";
$def[2] .= "CDEF:in_bits=bytes_read,8,* ";
$def[2] .= "LINE1:in_bits#0000ff:\"in \" " ;
$def[2] .= "GPRINT:in_bits:LAST:\"%7.2lf %Sbit/s last\" " ;
$def[2] .= "GPRINT:in_bits:AVERAGE:\"%7.2lf %Sbit/s avg\" " ;
$def[2] .= "GPRINT:in_bits:MAX:\"%7.2lf %Sbit/s max\\n\" " ;

$ds_name[3] = "Hits and Misses";
$opt[3]  = "--lower-limit=0 --vertical-label \"hits and misses\" --title \"$servicedesc Hits and Misses on $hostname\" ";
$def[3]  = rrd::def("get_hits", $RRDFILE[11], $DS[11], "AVERAGE");
$def[3] .= rrd::def("get_misses", $RRDFILE[13], $DS[13], "AVERAGE");
$def[3] .= rrd::def("cmd_get", $RRDFILE[20], $DS[20], "AVERAGE");
$def[3] .= rrd::area("get_hits", "#00FF00", "Hits     ");
$def[3] .= rrd::gprint("get_hits", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
$def[3] .= rrd::area("get_misses", "#FF0000", "Misses   ", "STACK");
$def[3] .= rrd::gprint("get_misses", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
$def[3] .= rrd::cdef("hitrate", "get_hits,get_hits,get_misses,+,/,100,*");
$def[3] .= rrd::comment("- Hit Rate");
$def[3] .= rrd::gprint("hitrate", array("LAST", "MAX", "AVERAGE"), "%.2lf%% ");

$ds_name[4] = "Memcached Memory";
$opt[4]  = "--lower-limit=0 --vertical-label \"MB\" --title \"$servicedesc Memory Use on $hostname\" ";
$def[4]  = rrd::def("bytes", $RRDFILE[14], $DS[14], "AVERAGE");
$def[4] .= rrd::def("maxbytes", $RRDFILE[18], $DS[18], "AVERAGE");
$def[4] .= rrd::cdef("total_mb", "maxbytes,1024,/,1024,/");
$def[4] .= rrd::cdef("use_mb", "bytes,1024,/,1024,/");
$def[4] .= rrd::cdef("free_mb", "maxbytes,bytes,-,1024,/,1024,/");
$def[4] .= rrd::cdef("use_perc", "bytes,maxbytes,/,100,*");
$def[4] .= rrd::cdef("free_perc", "100,use_perc,-");
$def[4] .= rrd::area("use_mb", "#00FF00", "Used Memory ");
$def[4] .= "GPRINT:use_mb:LAST:\"%6.1lfMB \g\" " ;
$def[4] .= "GPRINT:use_perc:LAST:\" (%2.1lf%%) Last\" " ;
$def[4] .= "GPRINT:use_mb:MAX:\"%6.1lfMB \g\" " ;
$def[4] .= "GPRINT:use_perc:MAX:\" (%2.1lf%%) Max\" " ;
$def[4] .= "GPRINT:use_mb:AVERAGE:\"%6.1lfMB \g\" " ;
$def[4] .= "GPRINT:use_perc:AVERAGE:\" (%2.1lf%%) Avg\\n\" " ;
$def[4] .= rrd::area("free_mb", "#00FFFF", "Free Memory ", "STACK");
$def[4] .= "GPRINT:free_mb:LAST:\"%6.1lfMB \g\" " ;
$def[4] .= "GPRINT:free_perc:LAST:\" (%2.1lf%%) Last\" " ;
$def[4] .= "GPRINT:free_mb:MAX:\"%6.1lfMB \g\" " ;
$def[4] .= "GPRINT:free_perc:MAX:\" (%2.1lf%%) Max\" " ;
$def[4] .= "GPRINT:free_mb:AVERAGE:\"%6.1lfMB \g\" " ;
$def[4] .= "GPRINT:free_perc:AVERAGE:\" (%2.1lf%%) Avg\\n\" " ;
$def[4] .= rrd::comment("= Total Memory");
$def[4] .= "GPRINT:total_mb:LAST:\"%6.1lfMB\\n\" ";

$ds_name[5] ="Data Items Store";
$opt[5]  = "--vertical-label \"# items\" --title \"$servicedesc Data Items on $hostname\" ";
$def[5]  = rrd::def("curr_items", $RRDFILE[8], $DS[8], "AVERAGE");
$def[5] .= rrd::def("total_items", $RRDFILE[17], $DS[17], "AVERAGE");
$def[5] .= rrd::area("total_items", "#00FF00", "Items Added Per Sec");
$def[5] .= rrd::gprint("total_items", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
$def[5] .= rrd::comment("- Total Current Items ");
$def[5] .= rrd::gprint("curr_items", array("LAST"), "%6.0lf ");

$ds_name[6] ="CPU Use";
$opt[6]  = "--vertical-label \"cpu time in msec\" --title \"CPU Time Use for $servicedesc on $hostname\" ";
$def[6]  = rrd::def("rusage_system", $RRDFILE[10], $DS[10], "AVERAGE");
$def[6] .= rrd::def("rusage_user", $RRDFILE[19], $DS[19], "AVERAGE");
$def[6]  = rrd::def("rusage_system_ms", $RRDFILE[24], $DS[24], "AVERAGE");
$def[6] .= rrd::def("rusage_user_ms", $RRDFILE[23], $DS[23], "AVERAGE");
$def[6] .= rrd::cdef("rusage_system_graph", "rusage_system_ms,1024,/");
$def[6] .= rrd::cdef("rusage_user_graph", "rusage_user_ms,1024,/");
$def[6] .= rrd::area("rusage_system_graph", "#FFFF00", "CPU System Mode Time");
$def[6] .= rrd::gprint("rusage_system_graph", array("LAST","MAX","AVERAGE"), "%3.2lf msec ");
$def[6] .= rrd::area("rusage_user_graph", "#00FF00", "CPU User Mode Time  ", "STACK");
$def[6] .= rrd::gprint("rusage_user_graph", array("LAST","MAX","AVERAGE"), "%3.2lf msec ");

?>
