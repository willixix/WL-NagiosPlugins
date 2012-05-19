<?php
#
# Copyright (c) 2010-2012 William Leibzon - http://william.leibzon.org/nagios/
#
$ds_name[1] = "System Memory";
$opt[1]  = "--height=250 --vertical-label \"Memory (MB)\" -b 1000 --title \"Memory Use on $hostname\" ";

$def[1]  = "DEF:total_free=$RRDFILE[1]:$DS[1]:AVERAGE " ;
$def[1] .= "DEF:perc_avail_real=$RRDFILE[2]:$DS[2]:AVERAGE " ;
$def[1] .= "DEF:shared=$RRDFILE[3]:$DS[3]:AVERAGE " ;
$def[1] .= "DEF:perc_avail_swap=$RRDFILE[4]:$DS[4]:AVERAGE ";
$def[1] .= "DEF:perc_buffer_real=$RRDFILE[5]:$DS[5]:AVERAGE ";
$def[1] .= "DEF:user=$RRDFILE[6]:$DS[6]:AVERAGE ";
$def[1] .= "DEF:perc_user_real=$RRDFILE[7]:$DS[7]:AVERAGE ";
$def[1] .= "DEF:avail_swap=$RRDFILE[8]:$DS[8]:AVERAGE ";
$def[1] .= "DEF:perc_used_real=$RRDFILE[9]:$DS[9]:AVERAGE ";
$def[1] .= "DEF:used_swap=$RRDFILE[10]:$DS[10]:AVERAGE ";
$def[1] .= "DEF:total=$RRDFILE[11]:$DS[11]:AVERAGE ";
$def[1] .= "DEF:perc_cached_real=$RRDFILE[12]:$DS[12]:AVERAGE ";
$def[1] .= "DEF:cached=$RRDFILE[13]:$DS[13]:AVERAGE ";
$def[1] .= "DEF:total_swap=$RRDFILE[14]:$DS[14]:AVERAGE ";
$def[1] .= "DEF:buffer=$RRDFILE[15]:$DS[15]:AVERAGE ";
$def[1] .= "DEF:min_swap=$RRDFILE[16]:$DS[16]:AVERAGE ";
$def[1] .= "DEF:avail_real=$RRDFILE[17]:$DS[17]:AVERAGE ";
$def[1] .= "DEF:total_real=$RRDFILE[18]:$DS[18]:AVERAGE ";
$def[1] .= "DEF:perc_used_swap=$RRDFILE[19]:$DS[19]:AVERAGE ";

$def[1] .= "AREA:user#FFF200:\"Used\: \t\g\" " ;
$def[1] .= "GPRINT:user:LAST:\"%6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_user_real:LAST:\"(%2.1lf%% of RAM)\" " ;
$def[1] .= "GPRINT:user:MAX:\"Max\: %6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_user_real:MAX:\"(%2.1lf%%)\" " ;
$def[1] .= "GPRINT:user:AVERAGE:\"Average\: %6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_user_real:AVERAGE:\"(%2.1lf%%)\\n\" " ;

$def[1] .= "AREA:buffer#6EA100:\"Buffers\: \t\g\":STACK " ;
$def[1] .= "GPRINT:buffer:LAST:\"%6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_buffer_real:LAST:\"(%2.1lf%% of RAM)\" " ;
$def[1] .= "GPRINT:buffer:MAX:\"Max\: %6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_buffer_real:MAX:\"(%2.1lf%%)\" " ;
$def[1] .= "GPRINT:buffer:AVERAGE:\"Average\: %6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_buffer_real:AVERAGE:\"(%2.1lf%%)\\n\" " ;

$def[1] .= "AREA:cached#00CF00:\"Cached\: \t\g\":STACK " ;
$def[1] .= "GPRINT:cached:LAST:\"%6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_cached_real:LAST:\"(%2.1lf%% of RAM)\" " ;
$def[1] .= "GPRINT:cached:MAX:\"Max\: %6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_cached_real:MAX:\"(%2.1lf%%)\" " ;
$def[1] .= "GPRINT:cached:AVERAGE:\"Average\: %6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_cached_real:AVERAGE:\"(%2.1lf%%)\\n\" " ;

$def[1] .= "AREA:avail_real#00FF00:\"Free\: \t\g\":STACK " ;
$def[1] .= "GPRINT:avail_real:LAST:\"%6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_avail_real:LAST:\"(%2.1lf%% of RAM)\" " ;
$def[1] .= "GPRINT:avail_real:MAX:\"Max\: %6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_avail_real:MAX:\"(%2.1lf%%)\" " ;
$def[1] .= "GPRINT:avail_real:AVERAGE:\"Average\: %6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_avail_real:AVERAGE:\"(%2.1lf%%)\\n\" " ;

$def[1] .= "CDEF:linewidth4=total_real,total_real,-,4,+ ";
$def[1] .= "AREA:linewidth4#000000:\"Total RAM\: \":STACK ";
$def[1] .= "GPRINT:total_real:LAST:\"%6.1lf MB \\n\" ";

$def[1] .= "AREA:used_swap#FF8C00:\"Swap Used\: \g\":STACK " ;
$def[1] .= "GPRINT:used_swap:LAST:\"%6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_used_swap:LAST:\"(%2.1lf%% of RAM)\" " ;
$def[1] .= "GPRINT:used_swap:MAX:\"Max\: %6.1lfMB \g\" " ;
$def[1] .= "GPRINT:perc_used_swap:MAX:\"(%2.1lf%%)\" " ;
$def[1] .= "GPRINT:used_swap:AVERAGE:\"Average\: %6.1lf MB \g\" " ;
$def[1] .= "GPRINT:perc_used_swap:AVERAGE:\"(%2.1lf%%)\\n\" " ;

$def[1] .= "CDEF:swap_plus_real=total_swap,total_real,+ ";
$def[1] .= "LINE1:swap_plus_real#FF0000:\"Swap Total\: \" ";
$def[1] .= "GPRINT:total_swap:LAST:\"%6.1lf MB \" ";
$def[1] .= "LINE2:total_real#000000 ";

?>
