#!/bin/bash
################################################################################
# ldap.lib.sh - Bash library functions related to LDAP searches
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

LDAPSEARCH_CMD=${LDAPSEARCH_CMD:='/usr/bin/ldapsearch'}
GREP_CMD=${GREP_CMD:='/bin/grep'}


# Simplified ldapsearch wrapper, which expects a bind dn and the corresponding
# password within a file (in order to hide it from the process list)
#
# ldapSearch baseDN scope bindDN bindPasswordFile LdapUri [filter [attributes]]
function ldapSearch ()
{
    local baseDn="$1"
    local scope="$2"
    local bindDn="$3"
    local bindPasswordFile="$4"
    local uri="$5"
    local filter="${6:-"(objectClass=*)"}"
    local attributes="${7}"

    ${LDAPSEARCH_CMD} -b "${baseDn}" \
                      -LLL \
                      -s "${scope}" \
                      -D "${bindDn}" \
                      -y "${bindPasswordFile}" \
                      -H "${uri}" \
                      -W \
                      -x \
                      "${filter}" \
                      ${attributes}
          
    return $?
}


# Gets the value of a specific attribute out of an LDIF string read from STDIN
#
# Multi-line values and multi-valued attributes aware.
#
# ldapGetAttributeValueFromLdif LdapAttribute
function ldapGetAttributeValueFromLdif ()
{
    local attribute="${1:-"dn"}"
    local value=""

    while read; do
        # No <NAME> was provided to the above read builtin, this prevents
        # word-splitting, which would remove the trailing white space on
        # multi-lined values
        local ldifLine="$REPLY"

        if [ "${value}" != "" ]; then

            # Check for multi-line value (starting with a space) 
            if [ "${ldifLine:0:1}" == " " ]; then
                # Append it to the previous line without the trailing whitespace
                local value+="${ldifLine:1}"
            else
               # We got the whole value, echo & reset it for multi-valued
               # attributes
               echo ${value}
               local value=""
            fi

        # Check if it's a line starting with an attribute
        elif echo "${ldifLine}" | ${GREP_CMD} -E -q "^${attribute}: "; then

            # strip off the trailing attribute name, for example: 'cn: '
            local value="${ldifLine/${attribute}: /}"
        fi
    done

    # If the attribute was found on the last LDIF line the above while loop
    # has already terminated before the value was echoed
    if [ "${value}" != "" ]; then
        echo $value
    fi
}
