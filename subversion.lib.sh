#!/bin/bash
################################################################################
# subversion.lib.sh - Bash library functions related to Subversion
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

# The path to the svn command
SVN_CMD="${SVN_CMD:="/usr/bin/svn"}"


## 
# Private variables, do not overwrite them 
#
# Default user and password for authentication
_SVN_USER=""
_SVN_PASSWORD=""

# Default automatic conflict resolution action,
# see subversionSetConflictResolutionAction()
_SVN_CONFLICT_RESOLUTION_ACTION="postpone"


# Set default user and password to use for authentication
#
# subversionSetCredentials user password
function subversionSetCredentials()
{
    _SVN_USER="${1}"
    _SVN_PASSWORD="${2}"
}


# Set default conflict resolution action
#
# see http://svnbook.red-bean.com/en/1.7/svn.ref.svn.html#svn.ref.svn.sw.accept
# for a list of allowed actions.
#
# subversionSetConflictResolutionAction action
function subversionSetConflictResolutionAction()
{
    _SVN_CONFLICT_RESOLUTION_ACTION="${1}"
}


# svn update
#
# Performs an svn update on the given path(s).
#
# If not given, uses default values for conflict resolution, user and password,
# see subversionSetConflictResolutionAction() and subversionSetCredentials().
# Returns the exit status of the svn command.
#
# subversionUpdate path [conflictResolutionAction [user [password]]]]
function subversionUpdate()
{
    local path="${1}"
    local conflictResolutionAction="${2:-"${_SVN_CONFLICT_RESOLUTION_ACTION}"}"
    local user="${3:-"${_SVN_USER}"}"
    local password="${4:-"${_SVN_PASSWORD}"}"

    ${SVN_CMD} update \
        --username "${user}" \
        --password "${password}" \
        --no-auth-cache \
        --non-interactive \
        --accept "${conflictResolutionAction}" \
        ${path}

    return $?
}


# svn add
#
# Performs an svn add on the given path(s).
# Returns the exit status of the svn command.
#
# subversionAdd path
function subversionAdd()
{
    local path="${1}"

    ${SVN_CMD} add \
        --non-interactive \
        ${path}

    return $?
}


# svn propset
#
# Performs an svn propset on the given path(s).
# Returns the exit status of the svn command.
#
# subversionPropset path property value
function subversionPropset()
{
    local path="${1}"
    local property="${2}"
    local value="${3}"

    ${SVN_CMD} propset \
        --non-interactive \
        "${property}" "${value}" \
        ${path}

    return $?
}


# svn propset svn:keywords
#
# Performs an svn propset with the svn:keywords property on the given path(s).
# Sets Id and Revision as the default keywords.
# Returns the exit status of the svn command.
#
# subversionAddKeywords path [keywords]
function subversionAddKeywords()
{
    local path="${1}"
    local keywords="${2:-"Id Revision"}"

    local property="svn:keywords"

    subversionPropset "${path}" "${property}" "${keywords}"
    return $?
}


# svn commit
#
# Performs an svn commit on the given path(s).
#
# If not given, uses default values for user and password,  see
# subversionSetCredentials().
# Returns the exit status of the svn command.
#
# subversionCommit path message [user [password]]
function subversionCommit()
{
    local path="${1}"
    local message="${2}"
    local user="${3:-"${_SVN_USER}"}"
    local password="${4:-"${_SVN_PASSWORD}"}"

    ${SVN_CMD} commit \
        --username "${user}" \
        --password "${password}" \
        --no-auth-cache \
        --non-interactive \
        --message "${message}" \
        ${path}

    return $?
}
