#!/bin/bash
################################################################################
# syslog.lib.sh - Bash library functions related to syslog
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

LOGGER_CMD="${LOGGER_CMD:="/usr/bin/logger"}"

if ! test -x "${LOGGER_CMD}"; then
    LOGGER_CMD="/bin/logger"

    if ! test -x "${LOGGER_CMD}"; then
        echo "Missing logger command: '${LOGGER_CMD}'" >&2
        exit 1
    fi
fi


function syslog ()
{
    local message="$1"
    local tag="$2"
    local level="$3"
    local facility="$4"

    if [ -z "$tag" ]; then
        tag="$0" # default to script name
    fi

    if [ -z "$level" ]; then
        level='info'
    fi

    if [ -z "${facility}" ]; then
        facility='user'
    fi

    ${LOGGER_CMD} -t "${tag}" -p "${facility}.${level}" "$message"
}
