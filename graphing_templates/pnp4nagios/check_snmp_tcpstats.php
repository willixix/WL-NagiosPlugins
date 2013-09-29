<?php
#
# Plugin Check: check_snmp_tcpstats
#   by William Leibzon - http://william.leibzon.org/nagios/
#
$ds_name[1] = "TCP Connections";
$opt[1] = " --vertical-label \"# connections\" -b 1000 --title \"TCP Statistics for $hostname\" ";
$def[1]  = "DEF:active_opens=$RRDFILE[1]:$DS[1]:AVERAGE " ; #iso.3.6.1.2.1.6.9.0
$def[1] .= "DEF:passive_opens=$RRDFILE[2]:$DS[2]:AVERAGE " ;  #iso.3.6.1.2.1.6.6.0
$def[1] .= "DEF:curr_established=$RRDFILE[3]:$DS[3]:AVERAGE " ; #iso.3.6.1.2.1.6.9.0
$def[1] .=  rrd::line1("curr_established", "#00FF00", "Established Current Sessions   ") ;
$def[1] .=  rrd::gprint("curr_established", array("LAST", "MAX", "AVERAGE"), "%6.1lf ") ;
$def[1] .=  rrd::line1("active_opens", "#FF0000", "Connections Closed Per Second  ") ;
$def[1] .=  rrd::gprint("active_opens", array("LAST", "MAX", "AVERAGE"), "%6.1lf ") ;
$def[1] .=  rrd::line1("passive_opens", "#0000FF", "Completed Connections (Passive)") ;
$def[1] .=  rrd::gprint("passive_opens", array("LAST", "MAX", "AVERAGE"), "%6.1lf ") ;

$ds_name[2] = "TCP Problems and Errors";
$opt[2] = " --vertical-label \"#\" -b 1000 --title \"TCP Statistics for $hostname\" ";
$def[2] = "DEF:estab_resets=$RRDFILE[6]:$DS[6]:AVERAGE " ; #iso.3.6.1.2.1.6.8.0
$def[2] .= "DEF:retrans_segs=$RRDFILE[7]:$DS[7]:AVERAGE " ; #iso.3.6.1.2.1.6.12.0
$def[2] .= "DEF:in_errs=$RRDFILE[4]:$DS[4]:AVERAGE " ; #iso.3.6.1.2.1.6.14.0
$def[2] .= "DEF:attempt_fails=$RRDFILE[5]:$DS[5]:AVERAGE " ; #iso.3.6.1.2.1.6.7.0
$def[2] .=  rrd::line1("estab_resets", "#0000FF", "Reset Sessions (Improperly Closed)") ;
$def[2] .=  rrd::gprint("estab_resets", array("LAST", "MAX", "AVERAGE"), "%6.1lf ") ;
$def[2] .=  rrd::line1("attempt_fails", "#FF00CC", "Attempted Sessions Not Established") ;
$def[2] .=  rrd::gprint("attempt_fails", array("LAST", "MAX", "AVERAGE"), "%6.1lf ") ;
$def[2] .=  rrd::line1("retrans_segs", "#00CCFF", "Retransmitted TCP Packets         ") ;
$def[2] .=  rrd::gprint("retrans_segs", array("LAST", "MAX", "AVERAGE"), "%6.1lf ") ;
$def[2] .=  rrd::line1("in_errs", "#FF0000", "Packets with Input/Checksum Errors") ;
$def[2] .=  rrd::gprint("in_errs", array("LAST", "MAX", "AVERAGE"), "%6.1lf ") ;

?>
