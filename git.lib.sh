#!/bin/bash
################################################################################
# git.lib.sh - Bash library functions related to Git
################################################################################
#
# Copyright (C) 2014 stepping stone GmbH
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

# The path to the git command
GIT_CMD="${GIT_CMD:="/usr/bin/git"}"

test -f "${GIT_CMD}" || die "Missing git command: '${GIT_CMD}'"


# Clones a Git repository into a new directory
#
# Returns the exit status of the git command.
#
# gitCheckoutBranch url directory
function gitCloneRepository ()
{
    local gitUrl="$1"
    local gitDir="$2"

    ${GIT_CMD} clone \
               "${gitUrl}" \
               "${gitDir}" 2> >(error -)

    return $?
}


# Checks out a given branch (default master) in a Git directory
#
# Returns the exit status of the git command.
#
# gitCheckoutBranch directory [branch]
function gitCheckoutBranch ()
{
    local gitDir="$1"
    local branch="${2:-"master"}"

    ${GIT_CMD} --git-dir "${gitDir}" \
               checkout "${branch}" 2> >(error -)
    
    return $?
}
