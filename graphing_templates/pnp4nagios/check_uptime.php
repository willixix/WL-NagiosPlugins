<?php
#
# Plugin for check_uptime adapted from template for check_icmp
#

$ds_name[1] = "Uptime";
$opt[1]  = "--vertical-label \"days\"  --title \"Uptime for $hostname\" --slope-mode ";
$def[1]  =  rrd::def("minutes", $RRDFILE[2], $DS[2], "AVERAGE") ;
$def[1] .=  rrd::cdef("days", "minutes,60,/,24,/");
#$def[1] .=  rrd::gradient("days", "228b22", "adff2f", "Uptime", 20) ;
$def[1] .=  rrd::gradient("days", "00ff2f", "00ffff", "Uptime", 20) ;
$def[1] .=  rrd::gprint("days", array("LAST", "AVERAGE", "MAX"), "%6.2lf Days") ;
$def[1] .=  rrd::line1("days", "#000000") ;

?>
