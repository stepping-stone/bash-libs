#!/bin/bash
################################################################################
# config.lib.sh - Bash library functions related to config validation
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

source "${LIB_DIR}/input-output.lib.sh"


function configLoadConfig ()
{
    local configPath="$1"

    if [ ! -f "${configPath}" ]; then
        die "Missing config file: ${configPath}"
    fi

    if [ ! -r "${configPath}" ]; then
        die "Not enough permissions to read config file: ${configPath}"
    fi

    source "${configPath}"
}

function configIsParameterValuePresent ()
{
    local parameterName="$1"
    local parameterValue="$( eval echo \$${parameterName} )"

    test -n "$parameterValue"
    return $?
}

function configDieIfValueNotPresent ()
{
    local parameterName="$1"

    if ! configIsParameterValuePresent "${parameterName}"; then
        die "Missing config parameter '${parameterName}', unable to proceed"
    fi
}
