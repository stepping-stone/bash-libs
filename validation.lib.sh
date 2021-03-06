#!/bin/bash
################################################################################
# validation.lib.sh - Bash library functions related to validation
################################################################################
#
# Copyright (C) 2014 - 2015 stepping stone GmbH
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

source "${LIB_DIR}/input-output.lib.sh"

function validationDieIfCommandMissing ()
{
    local cmdPath="${1}"
    local cmdName="$( basename "${cmdPath}" )"

    debug "Checking ${cmdPath}"
    test -x "${cmdPath}" || die "Missing ${cmdName} command at '${cmdPath}'"
}

# Checks if a given value matches a given regular expression.
#
# Returns 0 on match, otherwise 1
# Prints an error message if passed.
#
# validationRegex <VALUE> <REGEX> [<ERROR-MESSAGE>]
function validationRegex() {
    local value="${1}"
    local regex="${2}"
    local errorMessage="${3}"

    if ! [[ "${value}" =~ $regex ]]; then
        if test -n "$errorMessage"; then
            error "$errorMessage"
        fi
        return 1
    fi

    return 0
}
