#!/bin/bash
################################################################################
# input-output.lib.sh - Bash library functions related to in- and output
################################################################################
#
# Copyright (C) 2013 stepping stone GmbH
#                    Bern, Switzerland
#                    http://www.stepping-stone.ch
#                    support@stepping-stone.ch
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

SYSLOG_TAG="${SYSLOG_TAG:="$(${BASENAME_CMD} ${0})"}" # defaults to the name of the script

DEBUG=${DEBUG:='no'}


function logAndPrint ()
{
    local message="$1"
    local tag="$2"
    local level="$3"
    local facility="$4"

    if [ "${level}" = 'err' ]; then
        # write to STDERR on messages with an error level
        echo "$message" >&2
    else
        echo "$message"
    fi

    syslog "${message}" "${tag}" "${level}" "${facility}"
}


function info ()
{
    local message="$1"
    local tag="$2"

    if [ -z "${tag}" ]; then
        local tag="${SYSLOG_TAG}"
    fi

    logAndPrint "[INFO] ${message}" "$tag" 'info' 'user'
}

function error ()
{
    local message="$1"
    local tag="$2"

    if [ -z "${tag}" ]; then
        local tag="${SYSLOG_TAG}"
    fi

    logAndPrint "[ERROR] ${message}" "$tag" 'err' 'user'

}

function die ()
{
    local message="$1"
    local tag="$2"

    if [ -z "${tag}" ]; then
        local tag="${SYSLOG_TAG}"
    fi

    logAndPrint "[DIE] ${message}" "$tag" 'emerg' 'user'
    exit 1
}

function debug ()
{
    local message="$1"
    local tag="$2"

    if [ "$DEBUG" != "yes" ]; then
        return 0
    fi

    if [ -z "${tag}" ]; then
        local tag="${SYSLOG_TAG}"
    fi

    logAndPrint "[DEBUG] ${message}" "$tag" 'debug' 'user'
}