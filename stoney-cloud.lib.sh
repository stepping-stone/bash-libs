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

GREP_CMD="${GREP_CMD:="/bin/grep"}"


declare -A SC_VM_HOST_NAME
declare -A SC_VM_DOMAIN_NAME
declare -A SC_VM_NODE_NAME
declare -A SC_VM_MIGRATION_NODE_NAME
declare -A SC_VM_SPICE_PORT
declare -A SC_VM_MIGRATION_SPICE_PORT

declare -A SC_VM_OPERATING_SYSTEM
declare -A SC_VM_OPERATING_SYSTEM_TYPE
declare -A SC_VM_OPERATING_SYSTEM_VERSION

declare -A SC_VM_DHCP_HW_ADDRESS
declare -A SC_VM_DHCP_STATEMENTS
declare -A SC_VM_DHCP_IP_ADDRESS

declare -A SC_VM_NETWORK_INTERFACE_NAME
declare -A SC_VM_NETWORK_INTERFACE_MAC_ADDRESS
declare -A SC_VM_NETWORK_INTERFACE_MODEL_TYPE
declare -A SC_VM_NETWORK_INTERFACE_TYPE
declare -A SC_VM_NETWORK_INTERFACE_SOURCE_BRIDGE


## 
# Protected variables, only overwrite if necessary.
#
# Various LDAP subtrees
SC_LDAP_VIRTUAL_MACHINES_SUBTREE="${SC_LDAP_VIRTUAL_MACHINES_SUBTREE:-"ou=virtual machines,ou=virtualization,ou=services"}"
SC_LDAP_DHCP_CONFIG_SUBTREE="${SC_LDAP_DHCP_CONFIG_SUBTREE:-"cn=config-01,ou=dhcp,ou=networks,ou=virtualization,ou=services"}"


## 
# Private variables, do not overwrite them 
#
_SC_LDAP_VIRTUAL_MACHINES_BASE_DN=''
_SC_LDAP_DHCP_CONFIG_BASE_DN=''


# Set the stoney cloud related LDAP settings.
#
# scSetLdapSettings bindDn bindPasswordFile baseDn serverUri
function scSetLdapSettings ()
{
    local bindDn="${1:-"cn=Manager,dc=stoney-cloud,dc=org"}"
    local bindPasswordFile="${2:-"please-create-me.ldappass"}"
    local baseDn="${3:-"dc=stoney-cloud,dc=org"}"
    local serverUri="${4:-"ldap://localhost"}"

    ldapSetBindCredentials "${bindDn}" "${bindPasswordFile}"
    ldapSetBaseDn "${baseDn}"

    _SC_LDAP_VIRTUAL_MACHINES_BASE_DN="${SC_LDAP_VIRTUAL_MACHINES_SUBTREE},${baseDn}"
    _SC_LDAP_DHCP_CONFIG_BASE_DN="${SC_LDAP_DHCP_CONFIG_SUBTREE},${baseDn}"

    ldapSetServerUri "${serverUri}"
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

    ldapSearch "(sstVirtualMachine=${uuid})" \
               "${_SC_LDAP_VIRTUAL_MACHINES_BASE_DN}" \
               "one" \
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

    ldapSearch \
        "(ou=operating system)" \
        "sstVirtualMachine=${uuid},${_SC_LDAP_VIRTUAL_MACHINES_BASE_DN}" \
        "one" \
        "${@:2}"

    return $?
}

# Performs an LDAP search for a VMs DHCP configuration informations and prints
# the corresponding LDIF to STDOUT
#
# The desired LDAP attributes can be optionally passed, otherwise it returns
# all the attributes.
#
# scLdapGetVmOperatingSystemLdifByUuid \
#     <UUID> [<ATTRIBUTE-1>[ <ATTRIBUTE-2>[ <ATTRIBUTE-N>]]]
function scLdapGetVmDhcpConfigLdifByUuid ()
{
    local uuid="$1"

    ldapSearch \
        "(&(cn=${uuid})(objectClass=dhcpHost))" \
        "${_SC_LDAP_DHCP_CONFIG_BASE_DN}" \
        "sub" \
        "${@:2}"

    return $?
}

# Performs an LDAP search for a DHCP subnet by a given filter and prints the
# corresponding LDIF to STDOU
#
# The desired LDAP attributes can be optionally passed, otherwise it returns
# all the attributes.
#
# scLdapGetDhcpSubnetLdifByFilter \
#     <LDAP-FILTER> [<ATTRIBUTE-1>[ <ATTRIBUTE-2>[ <ATTRIBUTE-N>]]]
function scLdapGetDhcpSubnetLdifByFilter ()
{
    local filter="${1}"

    ldapSearch \
        "(&(${filter})(objectClass=dhcpSubnet))" \
        "${_SC_LDAP_DHCP_CONFIG_BASE_DN}" \
        "one" \
        "${@:2}"

    return $?
}

# Performs an LDAP search for a VMs network interface and prints
# the corresponding LDIF to STDOUT
#
# The  desired LDAP attributes can be optionally passed, otherwise it returns
# all the attributes.
#
# scLdapGetVmNetworkInterfaceDeviceLdifByUuidAndName \
#     <UUID> <INTERFACE-NAME> [<ATTRIBUTE-1>[ <ATTRIBUTE-2>[ <ATTRIBUTE-N>]]]
function scLdapGetVmNetworkInterfaceDeviceLdifByUuidAndName ()
{
    local uuid="$1"
    local interfaceName="$2"

    ldapSearch \
        "(sstInterface=${interfaceName})" \
        "ou=devices,sstVirtualMachine=${uuid},${_SC_LDAP_VIRTUAL_MACHINES_BASE_DN}" \
        "one" \
        "${@:3}"

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
        ldapGetAttributeValueFromLdif "sstNetworkHostname" false <<< "$ldif" )"

    SC_VM_DOMAIN_NAME[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstNetworkDomainName" false <<< "$ldif" )"

    SC_VM_NODE_NAME[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstNode" false <<< "$ldif" )"

    SC_VM_MIGRATION_NODE_NAME[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstMigrationNode" false <<< "$ldif" )"

    SC_VM_SPICE_PORT[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstSpicePort" false <<< "$ldif" )"

    SC_VM_MIGRATION_SPICE_PORT[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstMigrationSpicePort" false <<< "$ldif" )"

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

    debug "scLdapLoadVmOperatingSystemInfoByUuid LDIF:"
    debug "$ldif"

    SC_VM_OPERATING_SYSTEM[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstOperatingSystem" false <<< "$ldif" )"

    SC_VM_OPERATING_SYSTEM_TYPE[${uuid}]="$( ldapGetAttributeValueFromLdif \
            "sstOperatingSystemType" false <<< "$ldif" )"

    SC_VM_OPERATING_SYSTEM_VERSION[${uuid}]="$( ldapGetAttributeValueFromLdif \
            "sstOperatingSystemVersion" false <<< "$ldif" )"

    return 0
}


# Loads the VM related DHCP configuration informations, referenced by it's UUID
# from the LDAP directroy and populates the various SC_VM_* arrays which use
# the VM's UUID as the array key for referencing the value.
#
# scLdapLoadVmDhcpConfigInfoByUuid <UUID>
function scLdapLoadVmDhcpConfigInfoByUuid ()
{
    local uuid="$1"
    local attributes="dhcpHWAddress
                      dhcpStatements"

    local ldif
    ldif="$( scLdapGetVmDhcpConfigLdifByUuid "${uuid}" "${attributes}" 2>&1)"

    local returnValue="$?"

    if [ $returnValue -ne 0 ]; then
        error "LDAP search for VM UUID '${uuid}' failed: ${ldif}"
        return $returnValue
    fi

    debug "scLdapLoadVmDhcpConfigInfoByUuid LDIF:"
    debug "$ldif"

    SC_VM_DHCP_HW_ADDRESS[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "dhcpHWAddress" false <<< "$ldif" )"

    SC_VM_DHCP_STATEMENTS[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "dhcpStatements" <<< "$ldif" )"

    SC_VM_DHCP_IP_ADDRESS[${uuid}]=''

    debug "dhcpStatements: ${SC_VM_DHCP_STATEMENTS[${vmUuid}]}"

    local dhcpStatement=''
    while read dhcpStatement; do
        debug "dhcpStatement: ${dhcpStatement}"
        if ${GREP_CMD} -q -E '^fixed-address ' <<< "${dhcpStatement}"; then
            # Extract the IP address from the 'fixed-address 192.0.2.3' string.
            SC_VM_DHCP_IP_ADDRESS[${uuid}]="${dhcpStatement/* /}"
        fi
    done <<< "${SC_VM_DHCP_STATEMENTS[${vmUuid}]}"


    return 0
}

# Loads the VM related network interface device informations, referenced by 
# the VM's UUID and the network interface name from the LDAP directroy and
# populates the various SC_VM_* arrays which use the VM's UUID as the array
# key for referencing the value.
#
# scLdapLoadVmNetworkInterfaceDeviceInfoByUuidAndName <UUID> <INTERFACE-NAME>
function scLdapLoadVmNetworkInterfaceDeviceInfoByUuidAndName ()
{
    local uuid="$1"
    local interfaceName="$2"

    local attributes="sstInterface
                      sstMacAddress
                      sstModelType
                      sstSourceBridge
                      sstType"

    local ldif
    ldif="$( scLdapGetVmNetworkInterfaceDeviceLdifByUuidAndName \
                 "${uuid}" "${interfaceName}" "${attributes}" 2>&1)"

    local returnValue="$?"

    if [ $returnValue -ne 0 ]; then
        error "LDAP search for VM UUID '${uuid}' failed: ${ldif}"
        return $returnValue
    fi

    debug "scLdapLoadVmNetworkInterfaceDeviceInfoByUuidAndName LDIF:"
    debug "$ldif"

    SC_VM_NETWORK_INTERFACE_NAME[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstInterface" false <<< "$ldif" )"

    SC_VM_NETWORK_INTERFACE_MAC_ADDRESS[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstMacAddress" false <<< "$ldif" )"

    SC_VM_NETWORK_INTERFACE_MODEL_TYPE[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstModelType" false <<< "$ldif" )"

    SC_VM_NETWORK_INTERFACE_TYPE[${uuid}]="$( \
        ldapGetAttributeValueFromLdif "sstType" false <<< "$ldif" )"

    if [ "${SC_VM_NETWORK_INTERFACE_TYPE[${uuid}]}" == "bridge" ]; then
        SC_VM_NETWORK_INTERFACE_SOURCE_BRIDGE[${uuid}]="$( \
            ldapGetAttributeValueFromLdif "sstSourceBridge" false <<< "$ldif" )"
    fi

    return 0
}


# Get the netfilter interface alias (such as 'pub') which corresponds to a
# bridging device (such as 'vmbr0').
#
# scLdapGetNetFilterInterfaceAliasByBridgeName <BRIDGE-NAME>
function scLdapGetNetFilterInterfaceAliasByBridgeName ()
{
    local filter="sstSourceBridge=${1}"

    local attribut="sstNetfilterInterfaceAlias"

    local ldif
    ldif="$( scLdapGetDhcpSubnetLdifByFilter "${filter}" "${attribut}" 2>&1)"

    local returnValue="$?"

    if [ $returnValue -ne 0 ]; then
        error "LDAP search for source bridge '${1}' failed: ${ldif}"
        return $returnValue
    fi

    debug "${FUNCNAME} LDIF:"
    debug "$ldif"

    ldapGetAttributeValueFromLdif "${attribut}" false <<< "$ldif"
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
    return $?
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
    return $?
}


# Loads the VM related DHCP configuration informations, referenced by it's UUID
# and populates the various SC_VM_* arrays
#
# This function merely serves as a "database abstraction layer" without any
# logic at the moment. This allows one to implement different data storages
# in the future, without having to change the dependent code.
#
#  scLoadVmDhcpConfigInfoByUuid <UUID>
function scLoadVmDhcpConfigInfoByUuid
{
    scLdapLoadVmDhcpConfigInfoByUuid "$1"
    return $?
}


# Loads the VM related network interface device informations, referenced by it's UUID
# and populates the various SC_VM_* arrays
#
# This function merely serves as a "database abstraction layer" without any
# logic at the moment. This allows one to implement different data storages
# in the future, without having to change the dependent code.
#
#  scLdapLoadVmNetworkInterfaceDeviceInfoByUuidAndName <UUID> <INTERFACE-NAME>
function scLoadVmNetworkInterfaceDeviceInfoByUuidAndName
{
    scLdapLoadVmNetworkInterfaceDeviceInfoByUuidAndName "$1" "$2"
    return $?
}


# Get the netfilter interface alias (such as 'pub') which corresponds to a
# bridging device (such as 'vmbr0').
#
# This function merely serves as a "database abstraction layer" without any
# logic at the moment. This allows one to implement different data storages
# in the future, without having to change the dependent code.
#
# scGetNetFilterInterfaceAliasByBridgeName <BRIDGE-NAME>
function scGetNetFilterInterfaceAliasByBridgeName ()
{
    scLdapGetNetFilterInterfaceAliasByBridgeName "$1"
    return $?
}
