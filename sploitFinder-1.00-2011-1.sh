#!/bin/sh
###############################################################################
# Version:   1.00
# Date:      4th February 2011 (Originally released 5th September 2006)
# Author:    Network SMARTS, Queensland. Australia
# Contact:   Joomla! Forums - RussW
# FileName:  sploitFinder.sh
# ----------------------------------------------------------------------------
# sploitFinder: list possible exploit scripts and optionally email output
#
# Usage: ./sploitFinder(.sh) [-a] [-c] [-m <emailaddress>] [egrep pattern]
#        -m : email output to <emailaddress> instead of writing to stdout
#        -a : shows all files not just changes since last run
#        -c : shows matching lines with context
#        -r : reset/delete history
# ----------------------------------------------------------------------------
# Information/Overview:
# A reasonably effective script to search for particular known strings
# within .php and .cgi files that MAY present exploit capabilities.
# The logic is by no means "fool proof" or "exhaustive" but gives a 
# reasonably good indication that the target script maybe part of an 
# exploit set. False positives are extremely possible due to the fact
# that many valid scripts make use of the same logic/technologies to
# acheive required activities, therefore some "human intelligence" 
# must be applied to the final reports.
###############################################################################



###############################################################################
# VARIABLES THAT NEED CHANGING BEFORE RUNNING
###############################################################################
#     searchpath=/home  (Default : /home)
#     sploitdir=/<your_location>/sploitFind  (Default : none)
#
# and DON'T FORGET to use "-m <your@emailaddress.com.au>" in the command 
# string to email the output....!
#
# VARIABLES THAT MAYBE CHANGED TO SUIT
# This is the search pattern criteria. Listed are some of the signatures
# of some exploits we have heard of, these ARE NOT exhaustive. Obviously,
# the more variables there are, the longer each run will take.
#
# sploitpattern='r0nin|m0rtix|upl0ad|r57shell|c99shell|shellbot|phpshell|void\.ru|phpremoteview|directmail|bash_history|\.ru/|brute *force|multiviews|cwings|vandal|bitchx|eggdrop|guardservices|psybnc|dalnet|undernet|vulnscan|spymeta|raslan58|Webshell'
#
# ----------------------------------------------------------------------------
# The first run (with or without any switches will produce a text file 
# containing the baseline search results. (/sploitFinderDB/last) Subsequent
# runs will reference and compare the current output to this baseline.
#
# To rebuild the Baseline from scratch run, or to build a new Baseline 
# at anytime, run ./sploitFinder -r. (-a, display all files is implied)
#
# If no switches are issued (ie: ./sploitFinder) only files found after
# the last run are reported. (If this is not the first run)
#
# There are two reporting methods;
# If the -a (all) switch is issued (ie: ./sploitFinder -a) then ALL files
# found (including those prior to the last run or since the last reset) 
# are displayed.  /path/name/to/file/filename
#
# If the -c (context) switch is issued (ie: ./sploitfinder -c) then a more
# more indepth report is produced attempting to provide the viewer with 
# some "context" as to where the match was found. Again if using -ac, ALL
# files since the last reset are displayed, else only files since the last
# run are displayed. Default is to display 3 lines per match.
# /path/name/to/file/filename --<linenumber> <line from file matching search criteria>
#                             --<line from file matching search criteria>
#                             --<line from file matching search criteria>
#
# Note: This can look/get a little messy with a high number of matches.
#
# The -m switch (./sploitFinder -m <emailaddress>) will email the output
# to the specified email address.
#
# Combination switches maybe used such as;
# ./sploitFinder -ac -m your@emailaddress.com.au
#   - Report all files since last reset, showing context information and email it.
# ./sploitFinder -c -m your@emailaddress.com.au
#   - Report only files since last run, showing context information and email it.
# ./sploitFinder -rc -m your@emailaddress.com.au
#   - Reset/Rebuild the basline to now and report ALL files (-r, implies -a) found, 
#     showing context information and email it.
#
# CRONTAB/Regular usage:
# This script may be run adhoc if prefered, however we run it on TWO regular cron jobs.
# The first cron runs every 8 hours on Monday through Saturday at 02.10hrs, 10.10hrs & 16.10hrs
# - Showing only new files since the previous run and mailing the report
# The second cron runs once a week on Sunday at 02.10hrs
# - Resets/rebuilds the Baseline and mails out a full report of ALL files (-a implied)
# EG:
#   10 2,10,18 * * 1-6 /<your_loacation>/sploitFinder.sh -m your@emailaddress.com.au >& /dev/null
#   10 2 * * 0 /<your_location>/sploitFinder.sh -rm your@emailaddress.com >& /dev/null
#
###############################################################################


###############################################################################
# Originally posted in the Joomla 1.0 Security Forums after several attempted
# exploits on old or weak 3rd Party components/Modules being installed by clients.
# Please post any modifications or improvements to assist others in the promotion
# and execution of Joomla and the Open Source cause.
# If you update the search criteria for additional exploits or useful keywords
# it might be a nice idea to post your alterations to allow others to take advantage 
# of your experience and knowledge.
###############################################################################


###############################################################################
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later 
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for 
# more details.
###############################################################################




PATH=/bin:/usr/bin:/usr/local/bin
export LANG=C


## DEFAULT PATTERN - modify this required  ####################################
sploitpattern='r0nin|m0rtix|upl0ad|r57shell|c99shell|shellbot|phpshell|void\.ru|phpremoteview|directmail|bash_history|\.ru/|brute *force|multiviews|cwings|vandal|bitchx|eggdrop|guardservices|psybnc|dalnet|undernet|vulnscan|spymeta|raslan58|Webshell'

# process command line options
progname=$(basename $0)
domail=false showall=false showcontext=false reset=false
opts=$(getopt acrm: "$@")
if [ $? != 0 ]; then
        echo "$progname: usage: $progname [-a] [-c] [-r] [-m <emailaddress>] [egrep pattern]" >&2
        exit 1
fi
eval set -- "$opts"
for i; do
   case "$i" in
           -a) showall=true; shift;;
           -c) showcontext=true; shift;;
           -r) reset=true; shift;;
           -m) domail=true; email=$2; shift; shift;;
           --) shift; break;;
   esac
done
if [ $# -gt 0 ]; then
        sploitpattern="$1"
fi


## SETUP OPTIONS - change these to suit your environment ######################
# Where you want to search
  searchpath=/home

## The location where the sploitFinder DB is to stored. This will be auto-generated at first execution
## Example: /opt/adminTools/ is where the sploitFinder script is and you want the DB stored in /opt/adminTools/sploitFinderDB/

  sploitdir=/<your_location>/sploitFinderDB
## END SETUP OPTIONS ##########################################################

# DB files
  last=$sploitdir/last
  this=$sploitdir/this
  pid=$sploitdir/pid



if $reset; then
  rm -f $last
fi 


tmpout=$sploitdir/sploit.$$
tmpout2=$sploitdir/sploit2.$$
trap 'rm -f $tmpout $tmpout2' 0 1 2 3 15

umask 077

if [ ! -d $sploitdir ]; then
        mkdir $sploitdir || exit 2
fi

# exit if already running
[ -f $pid ] && kill -0 $(cat $pid) >/dev/null 2>&1 && exit 3
echo $$ > $pid

# search for files containing sploitpattern
find $searchpath \( -regex '.*\.php$' -o -regex '.*\.cgi$' -o -regex '.*\.inc$' \) -print0 | xargs -0 egrep -il "$sploitpattern" /dev/null | sort > $this


if [ -f $last ] && ! $showall ; then
        # show only changes since last run
        comm -13 $last $this > $tmpout
else
        # show all output
        cat $this > $tmpout
fi
mv $this $last

if $showcontext; then

        while read filename; do
                echo; echo "---* Possible Exploit *---"; echo
                # -niC3, the number three(3) represents how many lines to display in the output of matches with the -c(ontext) param.
                egrep -niC3 "$sploitpattern" "$filename" /dev/null

                
        done < $tmpout >> $tmpout2
        mv -f $tmpout2 $tmpout

fi

# Show Messages For options
  echo >> $tmpout;
  echo >> $tmpout;
  echo "  -- Run Time Options ---------------------------------------------------------------" >> $tmpout;

    if ! $showall ; then
      echo "  Show All Files     =   No,  only new files." >> $tmpout;
    else
      echo "  Show All Files     =   Yes, new and historical files." >> $tmpout;
    fi

    if ! $showcontext ; then
      echo "  Show Context       =   No,  only file names." >> $tmpout;
    else
      echo "  Show Context       =   Yes, showing offending lines in files." >> $tmpout;
    fi

    if ! $reset ; then
      echo "  History Cleared    =   No,  previous entries left inplace." >> $tmpout;
    else
      echo "  History Cleared    =   Yes, old entries deleted." >> $tmpout;
    fi

    if ! $domail ; then
      echo "  Email Notification =   No,  notification not requested." >> $tmpout;
    else
      echo "  Email Notification =   Yes, notification to $email." >> $tmpout;
    fi

  echo >> $tmpout;
  echo "  Search Patterns:" >> $tmpout;
  echo "  $sploitpattern" >> $tmpout;
  echo >> $tmpout;
  echo >> $tmpout;
  echo "  -- Execution Notes ----------------------------------------------------------------" >> $tmpout;
  echo "  If new potential exploit scripts are found, either manually review the file, or run" >> $tmpout;
  echo "  \"sploitFinder.sh -ac\" (optionally -m email@address.com.au) to view the offending" >> $tmpout;
  echo "  line within the indentified script." >> $tmpout;
  echo >> $tmpout;
  echo "  CAUTION: NOT all matches are guaranteed positives, valid scripts may also match" >> $tmpout;
  echo "  some of the search criteria listed above." >> $tmpout;
  echo "  -----------------------------------------------------------------------------------" >> $tmpout;
  echo "  usage: sploitFinder [-a] [-c] [-r] [-m <emailaddress>] [egrep pattern]" >> $tmpout;
  echo "         -m : Email output to <emailaddress> instead of writing to stdout" >> $tmpout;
  echo "         -a : Shows all files not just changes since last run" >> $tmpout;
  echo "         -c : Shows matching lines with context" >> $tmpout;
  echo "         -r : Reset/delete file match history" >> $tmpout;
  echo >> $tmpout;

if $domail; then
        # send mail if there is any output
        if [ $(awk 'END {print NR}' $tmpout) -gt 0 ]; then
                 mail -s "Possible Exploit Script Report for on $(hostname)" $email < $tmpout || exit 2
        fi
else
        # output sent to stdout
        cat $tmpout
fi
exit 0
