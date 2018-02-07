#!/bin/bash
#====================================================================
# NAME      :   docker_user_prep.sh
# AUTHOR    :   Andrys Jiri
# DATE      :   2017.01.05
# VERSION   :   0.2
#
# DEPENDENCIES:
#               1) Executables: bash, echo, mkdir, chmod, chown, 
#                               ymount, umess.sh
#
#               2) Part of docker_user_prep@.service, docker_user@service
#
#
# DESCRIPTION:
#             Preparing settings, 
#             creating files and configures docker_user@service environment
#
#             1)If template file
#               (OPT_FOLDER_TEMPLATE=/etc/default/docker_user_default) does not exists
#             during first run(for every user), script prepare and set user setting from default 
#             values in script vars TEMPLATE_ADD_DOCKER, TEMPLATE_ADD_MOUNT
#
#             2)If template file
#               (OPT_FOLDER_TEMPLATE=/etc/default/docker_user_default) does exists
#             during first run(for every user), script source template file and
#             and write results of variables EXT_MOUNT_DOCKER_STORAGE, DOCKER_OPTS
#             to user settings ${OPT_FOLDER}/docker
#
#             An EXT_MOUNT_DOCKER_STORAGE variable contains image where docker save its images
#             An DOCKER_OPTS variable contains parameters for dockerd 
#
#TODO:remove teplate_file values from this script
#
#====================================================================




prepenv() {

  #first time settings
  if [ ! -e "${OPT_FOLDER}/docker" ]; then
    echo -e "\n\n" >>"${HOME}/.bashrc"
    echo -e "${BASHRC_ADD}" >>"${HOME}/.bashrc"

    mkdir -p "${OPT_FOLDER}/execroot"

    if [ ! -e "${OPT_FOLDER_TEMPLATE}" ]; then
      echo "${TEMPLATE_ADD_DOCKER}" >>"$OPT_FOLDER/docker"
      echo "${TEMPLATE_ADD_MOUNT}" >>"$OPT_FOLDER/docker"
    else
      #read teplate and add result 
      source "${OPT_FOLDER_TEMPLATE}"
      echo EXT_MOUNT_DOCKER_STORAGE='"'"${EXT_MOUNT_DOCKER_STORAGE}"'"' >>"${OPT_FOLDER}/docker"
      echo DOCKER_OPTS='"'"${DOCKER_OPTS}"'"' >>"${OPT_FOLDER}/docker"
    fi

    chmod 775 -R "${OPT_FOLDER}"
    chown "${_USER}":"${_USER}" -R "${OPT_FOLDER}"
    chown :root "${OPT_FOLDER}/execroot"
    chmod 777 "${OPT_FOLDER}/execroot"
    
    #create folder for overlay image EXT_MOUNT_DOCKER_STORAGE
    #mkdir -p ${EXT_MOUNT_DOCKER_STORAGE%/*}
    
  fi
}


mntdocimg() {

  #TODO: sec issue
  #. "${OPT_FOLDER}/docker"
  #extraction of vars from user's config file
  EXT_MOUNT_DOCKER_STORAGE=$(awk '{varname="EXT_MOUNT_DOCKER_STORAGE=";if(index($0,varname)){bla=$0;sub(varname,"",bla);gsub("\"","",bla);print bla }    }' "${OPT_FOLDER}/docker" )
  DOCKER_OPTS=$(awk '{varname="DOCKER_OPTS=";if(index($0,varname)){bla=$0;sub(varname,"",bla);gsub("\"","",bla);print bla }    }' "${OPT_FOLDER}/docker" )

  _ret="10"
  echo "docker_user_prep: ext_mount_docker_storage=$EXT_MOUNT_DOCKER_STORAGE"

  if [ ! -d "${RUNTIME_FOLDER_IMAGES}" ]; then
    #Is docker storage available, had been mounted before ? > No > mount docker storage(dockerd -g):
    if [ -f "${EXT_MOUNT_DOCKER_STORAGE}" ]; then
    #does docker-image for storing docker images exist ? > Yes > mount to /mnt/$USER/vd2 
      ymount -n -i="${dockermntpointid}" --user="${_USER}" -m="${EXT_MOUNT_DOCKER_STORAGE}"
      _ret="$?"
    else
     _ret="9"
     echo "Error: File not found: ${EXT_MOUNT_DOCKER_STORAGE}"
    fi

  fi
  if [ "$_ret" != "0" ]; then
    echo "Error: Please mount image to""${RUNTIME_FOLDER_IMAGES} by following command"
    echo "       $ ymount -n -i=${dockermntpointid}"
    umess.sh -u "$_USER" -m "Error: Please mount image to""${RUNTIME_FOLDER_IMAGES} by following command: \n       $ ymount -n -i=${dockermntpointid} \n"
    exit "${_ret}"
  fi
}

main() {
  _USER="$1"; export _USER
  _ACTION="$2"

  ymount_settings_arr=( $(/usr/local/bin/ymount settings) )
  eval "${ymount_settings_arr[@]}"

  ((dockermntpointid=${USER_LOOPDEV_MAX}-1))
  export dockermntpointid

  HOME=$(awk -v cusr=$_USER 'BEGIN{FS=":"}{if(match($1,cusr)){print $6}}' /etc/passwd)
  export HOME

  OPT_FOLDER="${HOME}/.config/docker_user"; export OPT_FOLDER

  OPT_FOLDER_TEMPLATE=/etc/default/docker_user_default; export OPT_FOLDER_TEMPLATE

  RUNTIME_FOLDER_IMAGES="/mnt/$_USER/vd$dockermntpointid/docker"; export RUNTIME_FOLDER_IMAGES

  COM_SOCKET="-H unix://${OPT_FOLDER}/docker.sock"; export COM_SOCKET

BASHRC_ADD="\

docker_user() {
  params=\"\$@\"
  . \"\$HOME/.config/docker_user/docker\"
  DOCKER_SOCKET=\$(printf \"%s\" \"\$DOCKER_OPTS\" | grep -oP -e '(-H|--host)\W*\K(\S+)')
  params=\"-H\"\" \"\"\${DOCKER_SOCKET}\"\" \"\${params}
  docker \${params}
}
export -f docker_user
"
export BASHRC_ADD

  if [ ! -e "${OPT_FOLDER_TEMPLATE}" ]; then
    TEMPLATE_ADD_DOCKER="DOCKER_OPTS=\"--dns 8.8.8.8 --dns 8.8.4.4 -g ${RUNTIME_FOLDER_IMAGES} ${COM_SOCKET} -p ${OPT_FOLDER}/docker.pid --exec-root=${OPT_FOLDER}/execroot \""
    export TEMPLATE_ADD_DOCKER
    TEMPLATE_ADD_MOUNT="EXT_MOUNT_DOCKER_STORAGE=/mnt/nas_raid10/$_USER/images/docker/docker_imgs_storage.qemurawimg"; 
    export TEMPLATE_ADD_MOUNT
  fi

  echo "docker_user_prep: action=$_ACTION"
  echo "docker_user_prep: user=$_USER"
  echo "docker_user_prep: home=$HOME"
  echo "docker_user_prep: opt_folder=$OPT_FOLDER"
  echo "docker_user_prep: opt_folder_template=$OPT_FOLDER_TEMPLATE"
  echo "docker_user_prep: runtime_folder_images=$RUNTIME_FOLDER_IMAGES"
  echo "docker_user_prep: docker_mntpointid=$dockermntpointid"
  echo "docker_user_prep: template_add_docker=$TEMPLATE_ADD_DOCKER"
  echo "docker_user_prep: template_add_mount=$TEMPLATE_ADD_MOUNT"

  if [ "$_ACTION" == "start" ]; then
    prepenv
    mntdocimg
  elif  [ "$_ACTION" == "unmount" ]; then
    #TODO: sec issue
    #. "$OPT_FOLDER/docker"
    #extraction of vars from user's config file
    EXT_MOUNT_DOCKER_STORAGE=$(awk '{varname="EXT_MOUNT_DOCKER_STORAGE=";if(index($0,varname)){bla=$0;sub(varname,"",bla);gsub("\"","",bla);print bla }    }' "${OPT_FOLDER}/docker" )
    DOCKER_OPTS=$(awk '{varname="DOCKER_OPTS=";if(index($0,varname)){bla=$0;sub(varname,"",bla);gsub("\"","",bla);print bla }    }' "${OPT_FOLDER}/docker" )

    umess.sh -u "$_USER" -m "Info: Un-mounting docker image [/mnt/$_USER/vd${dockermntpointid}: \n        $ ymount unmount -n -i=${dockermntpointid}\n"
    ymount unmount --user="$_USER" -i="${dockermntpointid}"
    _ret1=$?
    if [ "${_ret1}" != "0" ]; then
      umess.sh -u "$_USER" -m "Error: Un-mounting /mnt/$_USER/vd${dockermntpointid} !! \n"
      exit "${_ret1}"
    else
      umess.sh -u "$_USER" -m "Info: Un-mounting /mnt/$_USER/vd${dockermntpointid} : OK \n"
      exit "${_ret1}"
    fi
  fi

}


#Check user existence in paramater 1
id "$1" || exit 1

main "$1" "$2"
