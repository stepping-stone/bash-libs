#!/bin/bash
################################################################################
# stoney-cloud.lib.sh - Bash library functions related to the stoney cloud
################################################################################
#
# Copyright (C) 2013 stepping stone GmbH
#                    Switzerland
#                    http://www.stepping-stone.ch
#                    support@stepping-stone.ch
#
# Authors:
#  Christian Affolter <christian.affolter@stepping-stone.ch>
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
################################################################################

# The path to the lib directory.
# The default value only works if not sourced or executed from within $PATH
LIB_DIR=${LIB_DIR:="$(readlink -f ${0%/*})"}

source "${LIB_DIR}/ldap.lib.sh"

SC_LDAP_BIND_DN="${SC_LDAP_BIND_DN-"cn=Manager,dc=foss-cloud,dc=org"}"
SC_LDAP_BIND_PASSWORD_FILE="${SC_LDAP_BIND_PASSWORD_FILE-"please-create-me.ldappass"}"
SC_LDAP_BASE_DN="${SC_LDAP_BASE_DN-"dc=foss-cloud,dc=org"}"
SC_LDAP_URI="${SC_LDAP_URI-"ldap://localhost"}"
SC_LDAP_VIRTUAL_MACHINES_SUBTREE="${SC_LDAP_VIRTUAL_MACHINES_SUBTREE-"ou=virtual machines,ou=virtualization,ou=services"}"

declare -A SC_VM_HOST_NAME
declare -A SC_VM_DOMAIN_NAME
declare -A SC_VM_NODE_NAME
declare -A SC_VM_MIGRATION_NODE_NAME
declare -A SC_VM_SPICE_PORT
declare -A SC_VM_MIGRATION_SPICE_PORT


# Performs an LDAP search and prints the LDIF output to STDOUT.
# 
# The bind DN, the bind password file and the LDAP URI have to be specified
# once within the global SC_LDAP_BIND_DN, SC_LDAP_BIND_PASSWORD_FILE and
# SC_LDAP_URI variables.
# The desired LDAP search scope, filter and attributes can optionally be passed,
# otherwise it returns all leafs with an objectClass=* and scope sub.
#
# scLdapSearch <BASE-DN> [<SCOPE> [<FILTER>] [<ATTRIBUTE-1>[ <ATTRIBUTE-N>]]]
function scLdapSearch ()
{
    local baseDn="${1-"${SC_LDAP_BASE_DN}"}"
    local scope="${2-"sub"}"
    local filter="${3:-"(objectClass=*)"}"
    local attributes="${4}"

    ldapSearch "${baseDn}" \
               "${scope}" \
               "${SC_LDAP_BIND_DN}" \
               "${SC_LDAP_BIND_PASSWORD_FILE}" \
               "${SC_LDAP_URI}" \
               "${filter}" \
               "${attributes}"
    
    return $?

}


# Performs an LDAP search for a VMs UUID and prints the corresponding LDIF to
# STDOUT
#
# The desired LDAP attributes can be optionally passed, otherwise it returns
# all the attributes.
#
# scLdapGetVmLdifByUuid <UUID> [<ATTRIBUTE-1>[ <ATTRIBUTE-2>[ <ATTRIBUTE-N>]]]
function scLdapGetVmLdifByUuid ()
{
    local uuid="$1"

    scLdapSearch "${SC_LDAP_VIRTUAL_MACHINES_SUBTREE},${SC_LDAP_BASE_DN}" \
                 "one" \
                 "(sstVirtualMachine=${uuid})" \
                 "${@:2}"

    return $?

}


# Performs an LDAP search for a VMs operating system informations and prints
# the corresponding LDIF to STDOUT
#
# The desired LDAP attributes can be optionally passed, otherwise it returns
# all the attributes.
#
# scLdapGetVmOperatingSystemLdifByUuid \
#     <UUID> [<ATTRIBUTE-1>[ <ATTRIBUTE-2>[ <ATTRIBUTE-N>]]]
function scLdapGetVmOperatingSystemLdifByUuid ()
{
    local uuid="$1"
    local baseDn="${SC_LDAP_VIRTUAL_MACHINES_SUBTREE},${SC_LDAP_BASE_DN}"

    scLdapSearch \
        "sstVirtualMachine=${uuid},${baseDn}" \
        "one" \
        "(ou=operating system)" \
        "${@:2}"

    return $?
}


# Loads the VM related informations, referenced by it's UUID from the LDAP
# directroy and populates the various SC_VM_* arrays which use the VM's UUID
# as the array key for referencing the value.
#
# scLdapLoadVmInfoByUuid <UUID>
function scLdapLoadVmInfoByUuid ()
{
    local uuid="$1"
    local attributes="sstNetworkHostname     sstNetworkDomainName
                      sstNode                sstMigrationNode
                      sstSpicePort           sstMigrationSpicePort"

    local ldif
    ldif="$( scLdapGetVmLdifByUuid "${uuid}" "${attributes}" 2>&1)"
    
    local returnValue="$?"

    if [ $returnValue -ne 0 ]; then
        error "LDAP search for VM UUID '${uuid}' failed: ${ldif}"
        return $returnValue
    fi

    SC_VM_HOST_NAME[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstNetworkHostname" <<< "$ldif" )"

    SC_VM_DOMAIN_NAME[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstNetworkDomainName" <<< "$ldif" )"

    SC_VM_NODE_NAME[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstNode" <<< "$ldif" )"

    SC_VM_MIGRATION_NODE_NAME[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstMigrationNode" <<< "$ldif" )"

    SC_VM_SPICE_PORT[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstSpicePort" <<< "$ldif" )"

    SC_VM_MIGRATION_SPICE_PORT[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstMigrationSpicePort" <<< "$ldif" )"

    return 0
}


# Loads the VM related operating system informations, referenced by it's UUID
# from the LDAP directroy and populates the various SC_VM_* arrays which use
# the VM's UUID as the array key for referencing the value.
#
# scLdapLoadVmOperatingSystemInfoByUuid <UUID>
function scLdapLoadVmOperatingSystemInfoByUuid ()
{
    local uuid="$1"
    local attributes="sstOperatingSystem
                      sstOperatingSystemType
                      sstOperatingSystemVersion"

    local ldif
    ldif="$( scLdapGetVmOperatingSystemLdifByUuid "${uuid}" "${attributes}" 2>&1)"

    local returnValue="$?"

    if [ $returnValue -ne 0 ]; then
        error "LDAP search for VM UUID '${uuid}' failed: ${ldif}"
        return $returnValue
    fi

    SC_VM_OPERATING_SYSTEM[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstOperatingSystem" <<< "$ldif" )"

    SC_VM_OPERATING_SYSTEM_TYPE[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstOperatingSystemType" <<< "$ldif" )"

    SC_VM_OPERATING_SYSTEM_VERSION[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstOperatingSystemVersion" <<< "$ldif" )"

    return 0
}


# Loads the VM related informations, referenced by it's UUID and populates
# the various SC_VM_* arrays
#
# This function merely serves as a "database abstraction layer" without any
# logic at the moment. This allows one to implement different data storages
# in the future, without having to change the dependent code.
#
# scLoadVmInfoByUuid <UUID>
function scLoadVmInfoByUuid ()
{
    scLdapLoadVmInfoByUuid "$1"
}


# Loads the VM related operating system informations, referenced by it's UUID
# and populates the various SC_VM_* arrays
#
# This function merely serves as a "database abstraction layer" without any
# logic at the moment. This allows one to implement different data storages
# in the future, without having to change the dependent code.
#
# scLoadVmOperatingSystemInfoByUuid <UUID>
function scLoadVmOperatingSystemInfoByUuid
{
    scLdapLoadVmOperatingSystemInfoByUuid "$1"
}
