#!/bin/bash
set -Eeuo pipefail

curl=(curl -s)
deb=( \
 # "win32_debian10=on" \
 # "win32_debian10_lang=en_US" \
 # "wow32_debian10=on" \
 # "wow32_debian10_lang=en_US" \
 # "wow64_debian10=on" \
 # "wow64_debian10_lang=en_US" \
 "win32_debian11=on" \
 "win32_debian11_lang=en_US" \
 "wow32_debian11=on" \
 "wow32_debian11_lang=en_US" \
 "wow64_debian11=on" \
 "wow64_debian11_lang=en_US" \
)
win=( \
 "vm_w1064=on" \
 "vm_w1064_2qxl=on" \
 "vm_w1064_tsign=on" \
 "vm_w1064v1507=on" \
 "vm_w1064v1809=on" \
 "vm_w10pro64=on" \
 "vm_w7u_2qxl=on" \
 "vm_w7u_adm=on" \
 "vm_w8=on" \
 "vm_w864=on" \
 "vm_w8adm=on" \
 # "vm_wxppro_2scr=on" \
 # "vm_w2008s64=on" \
)
lng=( \
 "vm_w10pro64_ar=on" \
 "vm_w10pro64_he=on" \
 "vm_w10pro64_ja=on" \
 "vm_w10pro64_zh_CN=on" \
 "vm_w7u_el=on" \
)

case "$1" in
  run-deb) "${curl[@]}" 'https://testbot.winehq.org/Submit.pl' --compressed \
                          -F "Page=4" -F "Upload=@$2" -F "Branch=master" \
                          ${deb[@]/#/-F } \
                          -F "UserVMSelection=1" -F "Remarks=" \
                          -F "TestExecutable=$3" -F "CmdLineArg=${*:4}" \
                          -F "Run32=on" -F "Run64=on" \
                          -F "DebugLevel=1" -F "Action=Submit" \
                          |grep moved|awk -F'"' '{print $2}'
                          ;;
  run-win) "${curl[@]}" 'https://testbot.winehq.org/Submit.pl' --compressed \
                          -F "Page=4" -F "Upload=@$2" -F "Branch=master" \
                          ${win[@]/#/-F } \
                          -F "UserVMSelection=1" -F "Remarks=" \
                          -F "TestExecutable=$3" -F "CmdLineArg=${*:4}" \
                          -F "Run32=on" -F "Run64=on" \
                          -F "DebugLevel=1" -F "Action=Submit" \
                          |grep moved|awk -F'"' '{print $2}'
                          ;;
  run-all) "${curl[@]}" 'https://testbot.winehq.org/Submit.pl' --compressed \
                          -F "Page=4" -F "Upload=@$2" -F "Branch=master" \
                          ${win[@]/#/-F } ${deb[@]/#/-F } \
                          -F "UserVMSelection=1" -F "Remarks=" \
                          -F "TestExecutable=$3" -F "CmdLineArg=${*:4}" \
                          -F "Run32=on" -F "Run64=on" \
                          -F "DebugLevel=1" -F "Action=Submit" \
                          |grep moved|awk -F'"' '{print $2}'
                          ;;
  run-lng) "${curl[@]}" 'https://testbot.winehq.org/Submit.pl' --compressed \
                          -F "Page=4" -F "Upload=@$2" -F "Branch=master" \
                          ${win[@]/#/-F } ${lng[@]/#/-F } \
                          -F "UserVMSelection=1" -F "Remarks=" \
                          -F "TestExecutable=$3" -F "CmdLineArg=${*:4}" \
                          -F "Run32=on" -F "Run64=on" \
                          -F "DebugLevel=1" -F "Action=Submit" \
                          |grep moved|awk -F'"' '{print $2}'
                          ;;
	cancel) "${curl[@]}" 'https://testbot.winehq.org/JobDetails.pl' \
                         --data "JobId=$1&Action=Cancel+job";;
esac
