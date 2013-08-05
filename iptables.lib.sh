#!/bin/bash
################################################################################
# iptables.lib.sh - Bash library functions related to iptables/netfilter
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
#
################################################################################

# The path to the lib directory.
# The default value only works if not sourced or executed from within $PATH
LIB_DIR=${LIB_DIR:="$(readlink -f ${0%/*})"}

IPTABLES_CMD="${IPTABLES_CMD:="/sbin/iptables"}"
DATE_CMD="${DATE_CMD:="/bin/date"}"
GREP_CMD="${GREP_CMD:="/bin/grep"}"

HASHLIMIT_PROC_DIR="/proc/net/ipt_hashlimit"


source "${LIB_DIR}/input-output.lib.sh"

if test ${BASH_VERSINFO[0]} -lt 4 -o ${BASH_VERSINFO[1]} -lt 1; then
  die "Bash version $BASH_VERSION is too old, require >= 4.1"
fi


# iptablesLog $chain $log_prefix
function iptablesLog()
{
    local chain=$1
    local log_prefix=$2
   
    local hashlimit_name=$chain

    if (( ${#hashlimit_name} > 15 )); then
        # hashlimit name is too long, let's use a pseudo (almost) unique ID.
        local hashlimit_name=`${DATE_CMD} +%s$RANDOM`

        # use another name if already present
        while test -e $HASHLIMIT_PROC_DIR/$hashlimit_name; do
            local hashlimit_name=`${DATE_CMD} +%s$RANDOM`
        done
   
        # enable for debugging purposes
        #echo "original hashlimit name '$chain' was too long"
        #echo "using '$hashlimit_name' instead"
    fi
   
    $IPTABLES_CMD -A $chain \
              -m hashlimit \
                  --hashlimit 1/min \
                  --hashlimit-mode dstip,srcip \
                  --hashlimit-burst 3 \
                  --hashlimit-name $hashlimit_name \
              -j ULOG \
              --ulog-prefix "$chain $log_prefix:"
}  

function iptablesLogAndDrop()
{
    local chain=$1
    local log_prefix=$2

    iptablesLog "$chain" "$log_prefix"
    $IPTABLES_CMD -A $chain -j DROP
}

function iptablesLogAndReject()
{
    local chain=$1
    local log_prefix=$2
    local reject_type=${3:=icmp-port-unreachable}

    iptablesLog "$chain" "$log_prefix"
    $IPTABLES_CMD -A $chain -j REJECT --reject-with $reject_type
}

function iptablesOpenPortIn() {
    local protocol=$1
    local chain=$2
    local sourceAddress=$3
    local destinationPort=$4
    local sourcePort=$5

    if [ "$sourcePort" = "" ]; then
        sourcePort="1024:65535"
    fi


    for address in $sourceAddress; do
            $IPTABLES_CMD -A $chain -p $protocol \
                -s $address \
                --sport $sourcePort \
                --dport $destinationPort \
                -m conntrack --ctstate NEW \
                -j ACCEPT
    done
}

function iptablesOpenPortOut() {
    local protocol=$1
    local chain=$2
    local destinationAddress=$3
    local destinationPort=$4
    local sourcePort=$5

    if [ "$sourcePort" = "" ]; then
        sourcePort="1024:65535"
    fi


    for address in $destinationAddress; do
            $IPTABLES_CMD -A $chain -p $protocol \
                -d $address \
                --sport $sourcePort \
                --dport $destinationPort \
                -m conntrack --ctstate NEW \
                -j ACCEPT
    done
}

# iptablesOpenTcpPortIn $chain $sourceIP $destinationPort [$sourcePort]
function iptablesOpenTcpPortIn() {
    iptablesOpenPortIn "tcp" "$1" "$2" "$3" "$4"
}

# iptablesOpenUdpPortIn $chain $sourceIP $destinationPort [$sourcePort]
function iptablesOpenUdpPortIn() {
    iptablesOpenPortIn "udp" "$1" "$2" "$3" "$4"
}

# iptablesOpenTcpPortOut $chain $destinationIP $destinationPort [$sourcePort]
function iptablesOpenTcpPortOut() {
    iptablesOpenPortOut "tcp" "$1" "$2" "$3" "$4"
}

# iptablesOpenUdpPortOut $chain $destinationIP $destinationPort [$sourcePort]
function iptablesOpenUdpPortOut() {
    iptablesOpenPortOut "udp" "$1" "$2" "$3" "$4"
}

function iptablesOpenIcmpIn() {
    local chain=$1
    local sourceAddress=$2
    local icmpType=$3
    local icmpCode=$4

    if [ "$icmpCode" = "" ]; then
        icmpCode="0"
    fi

    for address in $sourceAddress; do
            $IPTABLES_CMD -A $chain -p icmp \
                -s $address \
                --icmp-type $icmpType/$icmpCode \
                -m conntrack --ctstate NEW \
                -j ACCEPT
    done
}

function iptablesOpenIcmpOut() {
    local chain=$1
    local destinationAddress=$2
    local icmpType=$3
    local icmpCode=$4

    if [ "$icmpCode" = "" ]; then
        icmpCode="0"
    fi

    for address in $destinationAddress; do
            $IPTABLES_CMD -A $chain -p icmp \
                -d $address \
                --icmp-type $icmpType/$icmpCode \
                -m conntrack --ctstate NEW \
                -j ACCEPT
    done
}

function iptablesOpenEspIn() {
    local chain=$1
    local sourceAddress=$2

    for address in $sourceAddress; do
            $IPTABLES_CMD -A $chain -p esp \
                -s $address \
                -m conntrack --ctstate NEW \
                -j ACCEPT
    done
}

function iptablesOpenEspOut() {
    local chain=$1
    local destinationAddress=$2

    for address in $destinationAddress; do
            $IPTABLES_CMD -A $chain -p esp \
                -d $address \
                -m conntrack --ctstate NEW \
                -j ACCEPT
    done
}

function iptablesOpenIPsecTunneledIn() {
    local chain=$1
    local ipSecProtocol=$2
    local tunnelSourceAddress=$3
    local tunnelDestinationAddress=$4
    local destinationAddress=$5
    local destinationChain=$6

    for address in $destinationAddress; do
            $IPTABLES_CMD -A $chain \
                -m policy \
                  --dir in \
                  --pol ipsec \
                  --strict \
                  --proto "$ipSecProtocol" \
                  --mode tunnel \
                  --tunnel-src $tunnelSourceAddress \
                  --tunnel-dst $tunnelDestinationAddress \
                -m conntrack --ctstate NEW \
                -d $destinationAddress \
                -j "$destinationChain"
    done
}

function iptablesOpenIPsecTunneledOut() {
    local chain=$1
    local ipSecProtocol=$2
    local tunnelSourceAddress=$3
    local tunnelDestinationAddress=$4
    local sourceAddress=$5
    local destinationChain=$6

    for address in $sourceAddress; do
            $IPTABLES_CMD -A $chain \
                -m policy \
                  --dir out \
                  --pol ipsec \
                  --strict \
                  --proto "$ipSecProtocol" \
                  --mode tunnel \
                  --tunnel-src $tunnelSourceAddress \
                  --tunnel-dst $tunnelDestinationAddress \
                -s $sourceAddress \
                -m conntrack --ctstate NEW \
                -j "$destinationChain"
    done
}

# iptablesOpenIPsecEspTunneledIn chain tunnelSourceAddress tunnelDestinationAddress destinationAddress destinationChain
function iptablesOpenIPsecEspTunneledIn() {
    iptablesOpenIPsecTunneledIn "$1" "esp" "$2" "$3" "$4" "$5"
}

# iptablesOpenIPsecAhTunneledIn chain tunnelSourceAddress tunnelDestinationAddress destinationAddress destinationChain
function iptablesOpenIPsecAhTunneledIn() {
    iptablesOpenIPsecTunneledIn "$1" "ah" "$2" "$3" "$4" "$5"
}

# iptablesOpenIPsecEspTunneledOut chain tunnelSourceAddress tunnelDestinationAddress sourceAddress destinationChain
function iptablesOpenIPsecEspTunneledOut() {
    iptablesOpenIPsecTunneledOut "$1" "esp" "$2" "$3" "$4" "$5"
}

# iptablesOpenIPsecAhTunneledOut chain tunnelSourceAddress tunnelDestinationAddress sourceAddress destinationChain
function iptablesOpenIPsecAhTunneledOut() {
    iptablesOpenIPsecTunneledOut "$1" "ah" "$2" "$3" "$4" "$5"
}

function iptablesDnat() {
    local chain=$1 # PREROUTING
    local protocol=$2
    local destinationAddress=$3
    local destinationPort=$4
    local toDestinationAddress=$5
    local toDestinationPort=$6

    $IPTABLES_CMD -t nat -A $chain \
              -p $protocol \
              --dst $destinationAddress \
              --dport $destinationPort \
              -j DNAT \
              --to-destination $toDestinationAddress:$toDestinationPort
}

function iptablesSnat() {
    local chain="$1"
    local sourceAddress="$2"
    local toSourceAddress="$3"
    local condition="$4"

    $IPTABLES_CMD -t nat -A $chain \
              -s $sourceAddress \
              $condition \
              -j SNAT \
              --to-source $toSourceAddress

    return $?
}

# iptablesDnatPortForwarding $chain $protocol $destinationAddress $destinationPort $forwardingPort
function iptablesDnatPortForwarding() {
    iptablesDnat "$1" "$2" "$3" "$4" "$3" "$5"
}

#iptablesDnatTcpPortForwarding $chain $destinationAddress $destinationPort $forwardingPort
function iptablesDnatTcpPortForwarding() {
    iptablesDnatPortForwarding "$1" "tcp" "$2" "$3" "$4"
}

#iptablesDnatUdpPortForwarding $chain $destinationAddress $destinationPort $forwardingPort
function iptablesDnatUdpPortForwarding() {
    iptablesDnatPortForwarding "$1" "udp" "$2" "$3" "$4"
}

#checks if NAT is available within netfilter
function iptablesIsNatAvailable() {
    $IPTABLES_CMD -L -t nat > /dev/null 2>&1
    return $?
}

# insert a rule into a given chain, if it's not already present
# iptablesInsertRuleIfNotPresent "test_chain" "-s 10.1.1.1 -j test_chain2"
function iptablesInsertRuleIfNotPresent() {
    local chain=$1
    local rule=$2
    local table=$3

    if [ "$table" == "" ]; then
        local table="filter"
    fi

    # Check if the rule is already present
    # Note that the appending whitespace befor the line ending is intentional
    # as the IPTABLES_CMD -S output appends it.
    # This might change with further iptable versions :(
    # ^-A $chain $rule $"
    #                ^^^
    # The above isn't true for kernel >= 3.0
    # @ToDo: Check for kernel version and decide if a whitespace is required
    if ! $IPTABLES_CMD -t $table -S $chain | ${GREP_CMD} -q -E -- "^-A $chain $rule$";
    then
        # do not put $rule into surrounding quotes
        $IPTABLES_CMD -t $table -I $chain $rule
        return $?
    fi

    return 0
}

# append a rule into a given chain, if it's not already present
# iptablesAppendRuleIfNotPresent "test_chain" "-s 10.1.1.1 -j test_chain2"
function iptablesAppendRuleIfNotPresent() {
    local chain=$1
    local rule=$2
    local table=$3

    if [ "$table" == "" ]; then
        local table="filter"
    fi

    # Check if the rule is already present
    # Note that the appending whitespace befor the line ending is intentional
    # as the IPTABLES_CMD -S output appends it.
    # This might change with further iptable versions :(
    # ^-A $chain $rule $"
    #                ^^^
    # The above isn't true for kernel >= 3.0
    # @ToDo: Check for kernel version and decide if a whitespace is required
    if ! $IPTABLES_CMD -t $table -S $chain | ${GREP_CMD} -q -E -- "^-A $chain $rule$";
    then
        # do not put $rule into surrounding quotes
        $IPTABLES_CMD -t $table -A $chain $rule
        return $?
    fi

    return 0
}

# Removes a rule from a given chain, if it exists
# iptablesDeleteRuleIfPresent "test_chain" "-s 10.1.1.1 -j test_chain2"
function iptablesDeleteRuleIfPresent() {
    local chain=$1
    local rule=$2
    local table=$3

    if [ "$table" == "" ]; then
        local table="filter"
    fi

    # Check if the rule is already present
    # Note that the appending whitespace befor the line ending is intentional
    # as the IPTABLES_CMD -S output appends it.
    # This might change with further iptable versions :(
    # ^-A $chain $rule $"
    #                ^^^
    # The above isn't true for kernel >= 3.0
    # @ToDo: Check for kernel version and decide if a whitespace is required
    if $IPTABLES_CMD -t "$table" -S "$chain" | ${GREP_CMD} -q -E -- "^-A $chain $rule$";
    then
        # do not put $rule into surrounding quotes
        $IPTABLES_CMD --table "$table" --delete "$chain" $rule
        return $?
    fi

    return 0
}

# checks if a given chain is present/created
# iptablesIsChainPresent "test_chain"
function iptablesIsChainPresent() {
    local chain="$1"
    local table="$2"

    if [ "$table" == "" ]; then
        local table="filter"
    fi

    $IPTABLES_CMD -t $table --list $chain --numeric > /dev/null 2>&1
    return $?
}

# flushes and deletes a given chain if it exists
# iptablesRemoveChainIfPresent "my_chain"
function iptablesRemoveChainIfPresent() {
    local chain="$1"
    local table="$2"

    if [ "$table" == "" ]; then
        local table="filter"
    fi

    if ! iptablesIsChainPresent "$chain" "$table"; then
        return 0
    fi

    $IPTABLES_CMD --table "$table" --flush "$chain"        > /dev/null 2>&1
    $IPTABLES_CMD --table "$table" --delete-chain "$chain" > /dev/null 2>&1

    return $?
}

# Creates a given chain if it doesn't exist yet
function iptablesCreateChainIfNotPresent()
{
    local chain="$1"
    local table="$2"

    if [ "$table" == "" ]; then
        local table="filter"
    fi

    if ! iptablesIsChainPresent "$chain" "$table"; then
        $IPTABLES_CMD --table "$table" --new-chain "$chain" > /dev/null 2>&1
    fi

    return $?
}

# Creates a given chain if it doesn't exist yet, or flushes all rules within
# an existing one
function iptablesCreateOrFlushChain()
{
    local chain="$1"
    local table="$2"

    if [ "$table" == "" ]; then
        local table="filter"
    fi

    iptablesCreateChainIfNotPresent "${chain}" "${table}"
    $IPTABLES_CMD --table "$table" --flush "$chain" > /dev/null 2>&1

    return $?
}
