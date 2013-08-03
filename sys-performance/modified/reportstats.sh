#!/bin/bash
#
#report-status.sh - Generate Report from Catured Perf Stats
###########################################################
# Set Script Variables
#
REPORT_FILE=/etc/SI/docs/capstats.csv
TEMP_FILE=/etc/SI/tmp/capstats.html
#
DATE=`date +%m/%d/%Y`
#
MAIL_TO="jamey@securityinspection.com pperic@securityinspection.com nsmlead@dcctools.com"
#MAIL_TO="jamey@securityinspection.com"
#
HOSTNAME=`hostname`
IP=`/sbin/ifconfig eth0 | grep "inet addr" | gawk -F: '{print $2}' | gawk '{print $1}'`
###########################################################
# Create Head and CSS Presentation
echo "<html>" > $TEMP_FILE
echo "<head>" >> $TEMP_FILE
echo "<style>" >> $TEMP_FILE
echo " /* ------------------

 styling for the tables 

   ------------------   */





body

{

	line-height: 1.6em;

}

#nsm-stat-table

{

	font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;

	font-size: 12px;

	margin: 45px;

	width: 1000px;

	text-align: center;

	border-collapse: collapse;

}

#nsm-stat-table th

{

	font-size: 13px;

	font-weight: normal;

	padding: 10px;

	background: #b9c9fe;

	border-top: 4px solid #aabcfe;

	border-bottom: 1px solid #fff;

	color: #039;

}

#nsm-stat-table td

{

	padding: 10px;
 
	background: #e8edff;

	border-bottom: 1px solid #fff;

	color: #669;

	border-top: 1px solid transparent;

}

.odd
{
	background: #eff2ff; 
}
.even
{
	background: #e8edff;
}

#nsm-stat-table tr:hover td

{

	background: #d0dafd;

	color: #339;

} " >> $TEMP_FILE
echo "</style>" >> $TEMP_FILE
echo "</head> " >> $TEMP_FILE
###########################################################
# Create Report Body
#
echo "<body><h3>Reported on $DATE</h3>" >> $TEMP_FILE
echo "<h3>Hostname: $HOSTNAME</h3>" >> $TEMP_FILE
echo "<h3>Internal IP: $IP</h3>" >> $TEMP_FILE
echo "<table id="nsm-stat-table" summary="NSM 30 Daily Statistics">" >> $TEMP_FILE
echo "<thead>" >> $TEMP_FILE
echo "<tr><th scope="col">Date</th><th scope="col">Time</th><th scope="col">Users</th>" >> $TEMP_FILE
echo "<th scope="col">Load 15 Min</th><th scope="col">Free Memory</th><th scope="col">Swap Used</th>" >> $TEMP_FILE
echo "<th scope="col">% CPU Idle</th><th scope="col">Disk Free / </th><th scope="col">Disk Free /var</th><th scope="col">Disk Free /usr</th></tr>" >> $TEMP_FILE
echo "</thead>" >> $TEMP_FILE
#
###########################################################
# Place Performance Stats in Report
#
echo "<tbody>" >> $TEMP_FILE
cat $REPORT_FILE | gawk -F, '{
printf "<tr><td>%s</td><td>%s</td><td>%s</td>", $1, $2, $3;
printf "<td>%s</td><td>%s</td><td>%s</td>", $4, $5, $6;
printf "<td>%s</td><td>%s</td><td>%s</td><td>%s</td>\n</tr>\n", $7, $8, $9, $10;
}' >> $TEMP_FILE
#
echo "</tbody></table></body></html>" >> $TEMP_FILE
#
###########################################################
# Mail Performance Report & Clean up
#
(printf "%s\n%s\n" "Performance Report $DATE"; uuencode $TEMP_FILE "NSM-Performance.html") |mailx -s "NSM 30 Performance Report" $MAIL_TO
#
rm -f $TEMP_FILE
rm -f $REPORT_FILE
# EOF

