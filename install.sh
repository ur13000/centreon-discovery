#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation ; either version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with 
# this program; if not, see <http://www.gnu.org/licenses>.
# 
# Linking this program statically or dynamically with other modules is making a 
# combined work based on this program. Thus, the terms and conditions of the GNU 
# General Public License cover the whole combination.
# 
# As a special exception, the copyright holders of this program give MERETHIS 
# permission to link this program with independent modules to produce an executable, 
# regardless of the license terms of these independent modules, and to copy and 
# distribute the resulting executable under terms of MERETHIS choice, provided that 
# MERETHIS also meet, for each linked independent module, the terms  and conditions 
# of the license of that module. An independent module is a module which is not 
# derived from this program. If you modify this program, you may extend this 
# exception to your version of the program, but you are not obliged to do so. If you
# do not wish to do so, delete this exception statement from your version.
# 
# Module name: Centreon-Discovery
# 
# First developpement by : Jean Marc Grisard - Christophe Coraboeuf
# 
# Adaptation for Centreon 2.0 by : Merethis team 
#
# Script on Centreon install script by Watt
#
# Modified by Sub2.13
#
# SVN : $URL: http://svn.modules.centreon.com/centreon-discovery $
#


#---
## {Print help and usage}
##
## @Stdout Usage and Help program
#----
function usage() {
    local program=$PROGRAM
    echo -e "Usage: $program"
    echo -e "  -i\tinstall Discovery module"
#    echo -e "  -u\tinstall/upgrade Discovery with specify directory with contain $FILE_CONF"
    echo -e "  -t\tdefine type install : central/poller/both"
    echo -e "  -h\tdisplay this message"
    echo -e "\nExample for poller:"
    echo -e "  ./install.sh -i -t poller"
    exit 1
}


### Main
echo "Waiting ..."

# define where is a centreon-module source 
BASE_DIR=$(dirname $0)
## set directory
BASE_DIR=$( cd $BASE_DIR; pwd )
export BASE_DIR
if [ -z "${BASE_DIR#/}" ] ; then
    echo -e "I think it is not right to have Centreon-Discovery source on slash"
    exit 1
fi

INSTALL_DIR="$BASE_DIR/install"
export INSTALL_DIR

## load all functions used in this script
. $INSTALL_DIR/variables
. $INSTALL_DIR/display_functions
. $INSTALL_DIR/functions

#INSTALL_DIR="$BASE_DIR/install"
#export INSTALL_DIR

#export line

## Define a default log file
LOG_DIR="$BASE_DIR/log"
LOG_FILE="$PWD/install.log"

## Getopts
while getopts "iu:t:h" Options
do
    case ${Options} in
	i )	
	    _tmp_install_opts="1"
	    silent_install="0"
	    ;;
	u )	
	    _tmp_install_opts="1"
	    silent_install="1"
	    user_conf="${OPTARG%/}"
	    ;;
	t )
	    typeInstall=$OPTARG
	    ;;
	\?|h)
	    usage ; 
	    exit 0 
	    ;;
	* )
	    usage ; 
	    exit 1 
	    ;;
    esac
done

if [ "$_tmp_install_opts" -eq 0 ] || ([ "$typeInstall" != "poller" ] && [ "$typeInstall" != "central" ] && [ "$typeInstall" != "both" ]) ; then
    usage
    exit 1
fi

## Valid if you are root 
USERID=`id -u`
if [ "$USERID" != "0" ]; then
    echo -e "You must exec with root user"
    exit 1
fi

#Export variable for all programs
export silent_install CENTREON_CONF  

## init LOG_FILE
# backup old log file...
[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
if [ -e "$LOG_FILE" ] ; then
    mv "$LOG_FILE" "$LOG_FILE.`date +%Y%m%d-%H%M%S`"
fi
# Clean (and create) my log file
${CAT} << __EOL__ > "$LOG_FILE"
__EOL__

# Init GREP,CAT,SED,CHMOD,CHOWN variables
define_specific_binary_vars;

${CAT} << __EOT__
###############################################################################
#                                                                             #
#          http://community.centreon.com/projects/centreon-discovery          #
#                          Thanks for using Centreon                          #
#                                                                             #
#                                    v$VERSION                                   #
#                                                                             #
###############################################################################
__EOT__

## Find OS
echo "$line"
echo -e "\tFind distribution"
echo "$line"
find_OS;
if [ $? -eq 0 ] ; then
     echo_success "OS found: $distrib" "$ok"
else
     echo_failure "OS not found" "$fail"
     exit 1
fi
echo ""

BINARIES="rm cp mv ${CHMOD} ${CHOWN} echo more mkdir find ${GREP} ${CAT} ${SED} ${PYTHON} ${GCC}"
## binaries in function typeInstall
if [ "$typeInstall" != "central" ] ; then
    BINARIES=$BINARIES" ${NMAP}"
fi    

## binaries/packages in function distrib 
if [ "$distrib" == "DEBIAN" ] || [ "$distrib" == "UBUNTU" ] ; then
    BINARIES=$BINARIES" ${DPKG}"
    if [ "$typeInstall" == "poller" ] ; then
	PACKAGES="python-dev"
    else
	PACKAGES="python-dev libmysqlclient-dev"
    fi
elif [ "$distrib" == "REDHAT" ] || [ "$distrib" == "CENTOS" ] ; then
    BINARIES=$BINARIES" ${YUM}"
    if [ "$typeInstall" == "poller" ] ; then
	PACKAGES="python-devel"
    else
	PACKAGES="python-devel mysql-devel"
    fi
fi

echo "$line"
echo -e "\tChecking all needed binaries"
echo "$line"

binary_fail=0
# For the moment, I check if all binary exists in path.
# After, I must look a solution to use complet path by binary
for binary in $BINARIES; do
    if [ ! -e ${binary} ] ; then 
	pathfind "$binary"
	if [ "$?" -eq 0 ] ; then
	    echo_success "${binary}" "$ok"
	else 
	    echo_failure "${binary}" "$fail"
	    log "ERR" "\$binary not found in \$PATH"
		binary_fail=1
	fi
    else
	echo_success "${binary}" "$ok"
    fi
done

# Script stop if one binary wasn't found
if [ "$binary_fail" -eq 1 ] ; then
	echo ""
    echo_info "Please check fail binary/package and retry"
    exit 1
fi

# Check package
echo -e "\n$line"
echo -e "\tChecking all needed packages"
echo "$line"
error=0
for package in $PACKAGES; do
    echo -n $package
    check_package $package;
    if [ $? -eq 0 ] ; then
  	#package not installed !
	display_return "1" "$package"
	error=1
    else
  	#package installed !
	display_return "0" "$package"
    fi
done
if [ $error == 1 ]; then
    echo_info "\nPlease check fail packages and retry"
    exit 1
fi

echo -e "\n$line"
echo -e "\tAccepting licence"
echo "$line"
if [ "$silent_install" -eq 0 ] ; then
    echo -e "\nYou will now read Centreon Discovery module Licence.\\n\\tPress enter to continue."
    read 
    tput clear 
    more "$BASE_DIR/LICENSE"
    
    yes_no_default "Do you accept GPL license ?"
    if [ "$?" -ne 0 ] ; then 
	echo_info "You do not agree to GPL license ? Okay... have a nice day."
	echo -e "\tINSTALL ABORT"
	exit 1
    else
	log "INFO" "You accepted GPL license"
    fi
    
    if [ "$typeInstall" == "poller" ] ; then
	install_modPython;
	if [ "$?" -eq 0 ] ; then
	    install_agent;
        else
	    echo_failure "Modules Python weren't installed with success" "$fail"
	    echo -e "\tINSTALL ABORT"
	    exit 1
	fi
    else
	get_centreon_configuration_location;
	get_centreon_parameters;
	if [ "$?" -eq 0 ] ; then
	    echo_success "Parameters were loaded with success" "$ok"
	else
	    echo -e "\nUnable to load all parameters in \"$FILE_CONF\""
	    echo -e "\tINSTALL ABORT"
	    exit 1
	fi
	install_modPython;
	if [ "$?" -eq 0 ] ; then
	    install_agent;
	    install_module;
        else
	    echo_failure "Modules Python weren't installed with success" "$fail"
	    echo -e "\tINSTALL ABORT"
	    exit 1
        fi
    fi
fi


${CAT} << __EOT__
###############################################################################
#                                                                             #
#      Go to the URL : http://your-server/centreon/                           #
#                   	to finish the setup                                   #
#                                                                             #
#  Report bugs at                                                             #
#    http://community.centreon.com/projects/centreon-discovery/issues/new     #
#                                                                             #
###############################################################################
__EOT__

exit 0
