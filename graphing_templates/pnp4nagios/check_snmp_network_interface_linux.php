<?php
#
# Plugin: check_snmp_netint.pl (COUNTER, PERCENT, and errors)
#   by William Leibzon - http://william.leibzon.org/nagios/
# (based on pnp4nagios template for check_iftraffic.pl by Joerg Linge)
# Output based on Bits/s
#
$ds_name[1] = "Network Interface Traffic (bps)";
$opt[1] = " --vertical-label \"traffic bps\" -b 1000 --title \"Network Data Traffic for $hostname\" ";
$def[1] = "DEF:var1=$RRDFILE[3]:$DS[3]:AVERAGE " ;
$def[1] .= "DEF:var2=$RRDFILE[4]:$DS[4]:AVERAGE " ;
$def[1] .= "CDEF:in_bits=var1,8,* ";
$def[1] .= "CDEF:out_bits=var2,8,* ";
$def[1] .= "LINE1:in_bits#0000ff:\"in  \" " ;
$def[1] .= "GPRINT:in_bits:LAST:\"%7.2lf %Sbit/s last\" " ;
$def[1] .= "GPRINT:in_bits:AVERAGE:\"%7.2lf %Sbit/s avg\" " ;
$def[1] .= "GPRINT:in_bits:MAX:\"%7.2lf %Sbit/s max\\n\" " ;
$def[1] .= "LINE1:out_bits#00ff00:\"out \" " ;
$def[1] .= "GPRINT:out_bits:LAST:\"%7.2lf %Sbit/s last\" " ;
$def[1] .= "GPRINT:out_bits:AVERAGE:\"%7.2lf %Sbit/s avg\" " ;
$def[1] .= "GPRINT:out_bits:MAX:\"%7.2lf %Sbit/s max\\n\" ";
if($this->MACRO['TIMET'] != ""){
    $def[1] .= "VRULE:".$this->MACRO['TIMET']."#000000:\"Last Service Check \\n\" ";
}
if ($WARN[1] != "") {
    $def[1] .= "HRULE:$WARN[1]#FF8C00:\"In-Traffic Warning on $WARN[1] \" ";
}
if ($WARN[2] != "") {
    $def[1] .= "HRULE:$WARN[2]#FFFF00:\"Out-Traffic Warning on $WARN[2] \" ";
}
if ($CRIT[1] != "") {
    $def[1] .= "HRULE:$CRIT[1]#FF008C:\"In-Traffic Critical on $CRIT[1] \" ";
}
if ($CRIT[2] != "") {
    $def[1] .= "HRULE:$CRIT[2]#FF0000:\"In-Traffic Critical on $CRIT[2] \" ";
}

$ds_name[2] = "Network Interface Traffic (% of capacity)";
$opt[2] = " --vertical-label \"traffic %\" -b 1000 --title \"Network Data Traffic for $hostname\" --upper-limit 100";
$def[2] = "DEF:in_prct=$RRDFILE[1]:$DS[1]:AVERAGE " ;
$def[2] .= "DEF:out_prct=$RRDFILE[2]:$DS[2]:AVERAGE " ;
$def[2] .= "LINE1:in_prct#0000ff:\"in  \" " ;
$def[2] .= "GPRINT:in_prct:LAST:\"%7.2lf%% last\" " ;
$def[2] .= "GPRINT:in_prct:AVERAGE:\"%7.2lf%% avg\" " ;
$def[2] .= "GPRINT:in_prct:MAX:\"%7.2lf%% max\\n\" " ;
$def[2] .= "LINE1:out_prct#00ff00:\"out \" " ;
$def[2] .= "GPRINT:out_prct:LAST:\"%7.2lf%% last\" " ;
$def[2] .= "GPRINT:out_prct:AVERAGE:\"%7.2lf%% avg\" " ;
$def[2] .= "GPRINT:out_prct:MAX:\"%7.2lf%% max\\n\" ";
if($this->MACRO['TIMET'] != ""){
    $def[2] .= "VRULE:".$this->MACRO['TIMET']."#000000:\"Last Service Check \\t\" ";
}
if ($WARN[1] != "") {
    $def[2] .= "HRULE:$WARN[1]#FF8C00:\"In Warning on $WARN[1]%\\t\" ";
}
if ($WARN[2] != "") {
    $def[2] .= "HRULE:$WARN[2]#FFFF00:\"Out Warning on $WARN[2]%\\n\" ";
}
if ($CRIT[1] != "") {
    $def[2] .= "COMMENT:\"\\t\\t\\t\\t\" ";
    $def[2] .= "HRULE:$CRIT[1]#FF008C:\"In Critical on $CRIT[1]%\\t\" ";
}
if ($CRIT[2] != "") {
    $def[2] .= "HRULE:$CRIT[2]#FF0000:\"Out Critical on $CRIT[2]%\" ";
}
# create max line and legend
# $def[2] .= rrd::gprint( "v_n", "MAX", "$fmt $label$pct max used \\n" );
# $def[2] .= rrd::hrule( $max[1], "#003300", "Size of FS  $max[0] \\n");

$ds_name[3] = "Network Interface Errors";
$opt[3] = " --vertical-label \"# errors\" -b 1000 --title \"Network Errors for $hostname\" ";
$def[3] = "DEF:in_error=$RRDFILE[5]:$DS[5]:AVERAGE " ;
$def[3] .= "DEF:in_discard=$RRDFILE[6]:$DS[6]:AVERAGE " ;
$def[3] .= "DEF:out_error=$RRDFILE[7]:$DS[7]:AVERAGE ";
$def[3] .= "DEF:out_discard=$RRDFILE[8]:$DS[8]:AVERAGE ";
$def[3] .= "LINE1:in_error#0000ff:\"in error \\t\\t\" " ;
$def[3] .= "GPRINT:in_error:LAST:\"%4.1lf last\" " ;
$def[3] .= "GPRINT:in_error:AVERAGE:\"%4.1lf avg\" " ;
$def[3] .= "GPRINT:in_error:MAX:\"%4.1lf max\\n\" " ;
$def[3] .= "LINE1:out_error#00ff00:\"out error \\t\" " ;
$def[3] .= "GPRINT:out_error:LAST:\"%4.1lf last\" " ;
$def[3] .= "GPRINT:out_error:AVERAGE:\"%4.1lf avg\" " ;
$def[3] .= "GPRINT:out_error:MAX:\"%4.1lf max\\n\" ";
$def[3] .= "LINE1:in_discard#ff008c:\"in discard \\t\" " ;
$def[3] .= "GPRINT:in_discard:LAST:\"%4.1lf last\" " ;
$def[3] .= "GPRINT:in_discard:AVERAGE:\"%4.1lf avg\" " ;
$def[3] .= "GPRINT:in_discard:MAX:\"%4.1lf max\\n\" " ;
$def[3] .= "LINE1:out_discard#ffff00:\"out discard \\t\" " ;
$def[3] .= "GPRINT:out_discard:LAST:\"%4.1lf last\" " ;
$def[3] .= "GPRINT:out_discard:AVERAGE:\"%4.1lf avg\" " ;
$def[3] .= "GPRINT:out_discard:MAX:\"%4.1lf max\\n\" " ;


?>
