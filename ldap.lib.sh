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

LDAPSEARCH_CMD="${LDAPSEARCH_CMD:="/usr/bin/ldapsearch"}"
test -f "${LDAPSEARCH_CMD}" || \
    die "Missing ldapsearch command: '${LDAPSEARCH_CMD}'"

GREP_CMD="${GREP_CMD:="/bin/grep"}"


## 
# Private variables, do not overwrite them 
#
# Default LDAP server URI
_LDAP_URI="ldap://localhost"

# Default base DN
_LDAP_BASE_DN="dc=example,dc=com"

# Default bind DN and password file for binding.
_LDAP_BIND_DN="cn=Manager,${_LDAP_BASE_DN}"
_LDAP_BIND_PASSWORD_FILE="~/.ldappasswd"

# Default search scope
_LDAP_SEARCH_SCOPE="sub"

# Default LDAP search filter
_LDAP_SEARCH_FILTER='(objectClass=*)'


# Set default LDAP server URI
#
# ldapSetServerUri uri
function ldapSetServerUri()
{
    _LDAP_URI="${1}"
}


# Set default LDAP base DN
#
# ldapSetBaseDn baseDn
function ldapSetBaseDn()
{
    _LDAP_BASE_DN="${1}"
}


# Set default DN and password file to use for binding.
#
# ldapSetBindCredentials bindDn bindPasswordFile
function ldapSetBindCredentials()
{
    _LDAP_BIND_DN="${1}"
    _LDAP_BIND_PASSWORD_FILE="${2}"

    test -f "${_LDAP_BIND_PASSWORD_FILE}" || \
        die "Missing LDAP password file: '${_LDAP_BIND_PASSWORD_FILE}'"
}


# Set default LDAP search scope
#
# Scope is one of 'base', 'one' or 'sub' and defaults to 'sub'.
#
# ldapSetSearchScope scope
function ldapSetSearchScope()
{
    _LDAP_SEARCH_SCOPE="${1}"
}


# Set default LDAP search filter
#
# Defaults to '(objectclass=*)'.
#
# ldapSetSearchFilter filter
function ldapSetSearchFilter()
{
    _LDAP_SEARCH_FILTER="${1}"
}


# Simplified ldapsearch wrapper.
#
# All arguments are optional and have global default values set.
# See the following function descriptions in order to set the global defaults:
# - ldapSetServerUri()
# - ldapSetBaseDn()
# - ldapSetBindCredentials()
# - ldapSetSearchScope()
# - ldapSetSearchFilter()
# 
# The bind password is expected to be in a file (in order to hide it from the
# process list), see ldapSetBindCredentials().
#
# ldapSearch \
#     [filter [baseDn [scope [attributes [bindDn [bindPasswordFile [uri]]]]]]]
function ldapSearch ()
{
    local filter="${1:-"${_LDAP_SEARCH_FILTER}"}"
    local baseDn="${2:-"${_LDAP_BASE_DN}"}"
    local scope="${3:-"${_LDAP_SEARCH_SCOPE}"}"
    local attributes="${4}"
    local bindDn="${5:-"${_LDAP_BIND_DN}"}"
    local bindPasswordFile="${6:-"${_LDAP_BIND_PASSWORD_FILE}"}"
    local uri="${7:-"${_LDAP_URI}"}"

    ${LDAPSEARCH_CMD} -b "${baseDn}" \
                      -LLL \
                      -s "${scope}" \
                      -D "${bindDn}" \
                      -y "${bindPasswordFile}" \
                      -H "${uri}" \
                      -W \
                      -x \
                      "${filter}" \
                      ${attributes} 2>&1 | logCommandOutputOnError
          
    return $?
}


# Gets the value of a specific attribute out of an LDIF string read from STDIN
#
# Multi-line values and multi-valued attributes aware.
#
# ldapGetAttributeValueFromLdif LdapAttribute [(TRUE|false)]
function ldapGetAttributeValueFromLdif ()
{
    local attribute="${1:-"dn"}"
    local lookForMultiValuedAttribute=${2:-true}

    local lookForAttributeLine=true
    local lookForMultiLineValue=false
    local ldifLine=""
    local value=""

    while true; do
        while $lookForAttributeLine; do
            # Check if it's a line starting with the desired attribute
            if ${GREP_CMD} -E -q "^${attribute}: " <<< "$ldifLine"; then
                # strip off the leading attribute name, for example: 'cn: '
                value="${ldifLine/${attribute}: /}"

                lookForMultiLineValue=true 
                lookForAttributeLine=false
                break # do not read again
            fi
            
            # Read must be done after the attribute check, otherwise a
            # (possible) existing ldifLine from the multi-line value loop
            # below will be overwritten.
            if ! read; then
                # end of input reached
                break 2 # exit
            fi

            # No <NAME> was provided to the above read builtin, this prevents
            # word-splitting, which would remove the trailing white space on
            # multi-lined values. The current line is available in $REPLY.
            ldifLine="$REPLY"
        done

        while $lookForMultiLineValue; do
            if ! read; then
                # end of input reached
                if test -n "${value}"; then
                    echo "${value}"
                    value=""
                fi
                
                break 2 # exit
            fi

            ldifLine="$REPLY"

            # Check for multi-line value (a line starting with a space) 
            if [ "${ldifLine:0:1}" == " " ]; then
                # Append it to the previous line without the trailing whitespace
                value+="${ldifLine:1}"
            else
                # Either no multi-line value or the last line of it.
                echo "${value}"
                value=''
                lookForMultiLineValue=false
                lookForAttributeLine=true

                if ! $lookForMultiValuedAttribute; then
                    break 2 # exit, no multi-valued attributes expected
                fi
            fi
        done
    done
}
