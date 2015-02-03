#!/bin/bash
################################################################################
# input-output.lib.sh - Bash library functions related to in- and output
################################################################################
#
# Copyright (C) 2013 - 2015 stepping stone GmbH
#                           Bern, Switzerland
#                           http://www.stepping-stone.ch
#                           support@stepping-stone.ch
#
# Authors:
#   Christian Affolter <christian.affolter@stepping-stone.ch>
#  
# Licensed under the EUPL, Version 1.1.
#
# You may not use this work except in compliance with the
# Licence.
# You may obtain a copy of the Licence at:
#
# http://www.osor.eu/eupl
#
# Unless required by applicable law or agreed to in
# writing, software distributed under the Licence is
# distributed on an "AS IS" basis,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied.
# See the Licence for the specific language governing
# permissions and limitations under the Licence.
#
################################################################################

# The path to the lib directory.
# The default value only works if not sourced or executed from within $PATH
LIB_DIR=${LIB_DIR:="$(readlink -f ${0%/*})"}

source "${LIB_DIR}/syslog.lib.sh"

BASENAME_CMD=${BASENAME_CMD:="/usr/bin/basename"}

IO_LOG="${IO_LOG:="yes"}"
IO_PRINT="${IO_PRINT:="yes"}"

SYSLOG_TAG="${SYSLOG_TAG:="$(${BASENAME_CMD} ${0})"}" # defaults to the name of the script

DEBUG=${DEBUG:='no'}

## 
# Private variables, do not overwrite them 
#

# The prefix to prepend to all messages 
_IO_MESSAGE_PREFIX="${_IO_MESSAGE_PREFIX:=""}"


# Sets the message prefix which will be prepended to all messages
#
# ioSetMessagePrefix prefix
function ioSetMessagePrefix ()
{
   export _IO_MESSAGE_PREFIX="${1} "
}


function logAndPrint ()
{
    local message="${1}"
    local tag="$2"
    local level="$3"
    local facility="$4"

    if [ "${message}" = '-' ]; then
        # Read from STDIN
        local message=''

        while read output; do
            message+="${output}"
        done

        # empty message, do not output anything.
        test -z "$message" && return 0
    fi

    local levelPrefix=''
    case $level in
        debug)
            levelPrefix="[DEBUG]"
            ;;

        info)
            levelPrefix="[INFO]"
            ;;

        warning)
            levelPrefix="[WARNING]"
            ;;

        err)
            levelPrefix="[ERROR]" 
            ;;

        emerg)
            levelPrefix="[DIE]"
            ;;

        *)
            levelPrefix="[???]"
            ;;
    esac
        
    message="${levelPrefix} ${_IO_MESSAGE_PREFIX}${message}"

    if [ -z "${tag}" ]; then
        local tag="${SYSLOG_TAG}"
    fi

    if [ "${IO_PRINT}" = 'yes' ]; then
        if [ "${level}" = 'err' ]; then
            # write to STDERR on messages with an error level
            echo "$message" >&2
        else
            echo "$message"
        fi
    fi

    if [ "${IO_LOG}" = 'yes' ]; then
        syslog "${message}" "${tag}" "${level}" "${facility}"
    fi
}


function info ()
{
    local message="$1"
    local tag="$2"

    logAndPrint "${message}" "$tag" 'info' 'user'
}

function warn ()
{
    local message="$1"
    local tag="$2"

    logAndPrint "${message}" "$tag" 'warning' 'user'
}


function error ()
{
    local message="$1"
    local tag="$2"

    logAndPrint "${message}" "$tag" 'err' 'user'
}

function die ()
{
    local message="$1"
    local tag="$2"

    logAndPrint "${message}" "$tag" 'emerg' 'user'
    exit 1
}

function debug ()
{
    local message="$1"
    local tag="$2"

    if [ "$DEBUG" != "yes" ]; then
        return 0
    fi

    logAndPrint "${FUNCNAME[1]}: ${message}" "$tag" 'debug' 'user'
}

# Reads user input into variable
#
# Prints an input prompt and reads the user input into a variable given by
# <VARIABLE-NAME>. Optionally, a default value can be passed or set in the
# global scope as IO_DEFAULT_<VARIABLE-NAME>.
# 
# ioReadInputVar <VARIABLE-NAME> [<PROMPT-PREFIX> [<DEFAULT-VALUE>]]
function ioReadInputVar() {
    local varName="${1}"
    local inputPrompt="${2}"
    local defaultVarName="IO_DEFAULT_${varName}"
    local defaultValue="${3:-${!defaultVarName}}"

    read -e -p "${inputPrompt}: " -i "${defaultValue}" "${varName}"
}
