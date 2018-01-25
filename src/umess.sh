#!/bin/bash
#====================================================================
# NAME          :       umess.sh
# AUTHOR        :       Andrys Jiri, ALJP22100592
# DATE          :       2016.11.22
# VERSION       :       1.1
# DEPENDENCIES:         
#               1)binaries: bash, egrep, grep, awk, notify-send, users, sudo tee
#
# DESCRIPTION   :       
#       Script for sending messages to user to GUI and to terminals
#====================================================================

help() { echo -e "\n Help: \n $0 [-u <username> ] [-m <text message> ] [-a  | send message to all users ]\n"; exit 0; }

print_port_only=0
to_all=0
send_message=""
notif_picture=""

while getopts ":u:ham:p:" p; do
	case "${p}" in
		u)
			user_="${OPTARG}"
			;;
		a)
			to_all=1
			;;
		m)
			send_message="${OPTARG}"
			;;
		p)
            notif_picture="${OPTARG}"
            ;;
		h)
			help
			;;
	esac
done

[ $# -eq 0 ] && help


if [ -z "${user_}" ]; then
  us="$USER"
else
  us="${user_}"
fi


if [ ! -z "${send_message}" ]; then

  term_ids_arr=( `ls -lt /dev/pts | grep "${us}" | awk '{ print $NF }'` )

  term_mess="\nWARNING! \n$delim\n  $send_message \n$delim\nWARNING! \n"
  term_mess="\e[31m${term_mess}\e[0m"


  for term_id in "${term_ids_arr[@]}"; do
    echo -e "${term_mess}" | sudo tee "/dev/pts/""${term_id}" > /dev/null 2>&1
  done

  #X0,X10,X11 etc ...
  disp_ids_arr=( $(ls -lt /tmp/.X11-unix/ | grep "${us}" | awk '{ print $NF }') )

  for disp_id in "${disp_ids_arr[@]}"; do
    disp_id="${disp_id##*X}"
    sudo -u "${us}" DISPLAY=:"${disp_id}" notify-send -u "critical" -i "${notif_picture}" "WARNING" \ "\n${send_message}\n"
  done
  
  
  #cant find universal bond between user and DISPLAY ID and session of given user in case of local real display
  #who command knows
  disp_ids_arr2=( $(who | grep "${us}" | grep "(:" | awk '{new=$NF;if(old!=new){print $NF; old=$NF} }') )
  #(:0.0)
  for disp_id in "${disp_ids_arr2[@]}"; do
    disp_id="${disp_id:2:1}"
    sudo -u "${us}" DISPLAY=:"${disp_id}" notify-send -u "critical" -i "${notif_picture}" "WARNING" \ "\n${send_message}\n"
  done
  
fi

if [ "${to_all}" -eq 1 ]; then

  _logd_users=( $(users | awk '{n=split($0, array, " "); new=$1; for(i=1;i<=n;i++){ if( new!=$(i+1) ){ print new; new=$(i+1)}}}') )
  for usr in "${_logd_users[@]}"; do
      umess.sh -u "${usr}" -m "${send_message}"
  done

fi
