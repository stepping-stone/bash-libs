#!/bin/bash
################################################################################
# input-validation.lib.sh - Bash library functions related to input validation
################################################################################
#
# Copyright (C) 2015 stepping stone GmbH
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
source "${LIB_DIR}/validation.lib.sh"


# Reads user input and validates it agains a given regular expression.
#
# See ioReadInputVar and validationRegex
#
# inputValidationRegex \
#     <VARIABLE-NAME> <PROMPT-PREFIX> <REGEX> [<ERROR-MESSAGE> [<DEFAULT-VALUE>]]
function inputValidationRegex() {
    local varName="${1}"
    local inputPrompt="${2}"
    local regex="${3}"
    local errorMessage="${4:-"${inputPrompt} is invalid"}"
    local defaultValue="${5}"

    # Read input until the regex matches.
    while test -z "${!varName}"; do
        ioReadInputVar "${varName}" "${inputPrompt}" "${defaultValue}"
        if ! validationRegex "${!varName}" "${regex}" "${errorMessage}"; then
            unset $varName
        fi
    done
}


# Reads user input and checks if the user has entered yes or no
#
# Returns 0 on yes input an 1 on no input
#
# inputValidationYes [<PROMPT-PREFIX> [<ERROR-MESSAGE> [<DEFAULT-VALUE>]]]
function inputValidationYes() {
    local inputPrompt="${1:-"yes or no?"}"
    local errorMessage="${2:-"Please enter yes or no"}"
    local defaultValue="${3}"

    local yesRegex='(yes|YES|Yes|y|Y)'
    local noRegex='(no|NO|No|n|N)'

    local regex="^(${yesRegex}|${noRegex})$"

    local input=""

    inputValidationRegex \
        "input" "${inputPrompt}" "${regex}" "${errorMessage}" "${defaultValue}"

    validationRegex "${input}" "${yesRegex}"
    return $?
}
