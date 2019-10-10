#!/bin/bash

# Author:       Vasu Mahalingam
# Email:        vasu.uky@gmail.com
# Date:         2019-10-09
# 
# Quick and dirty help script for creating and 
# cleaning sr evpn resources


. ~/openstack-configs/openrc

function get_sr_net_from_base_index()
{
   local __resultvar=$1
   local __base=$2
   local __index=$3

   eval $__resultvar=network_testx-$(( $__base + $__index ))
}

function get_subnet_name_from_base_index()
{
   local __resultvar=$1
   local __base=$2
   local __index=$3

   eval $__resultvar=subnet_testx-$(( $__base + $__index ))
}

function get_sec_group_name_from_base_index()
{
   local __resultvar=$1
   local __base=$2
   local __index=$3

   eval $__resultvar=sec_group_testx-$(( $__base + $__index ))
}

function get_server_name_from_base_index()
{
   local __resultvar=$1
   local __base=$2
   local __index=$3

   eval $__resultvar=server_testx-$(( $__base + $__index ))
}

function get_flavor_name()
{
    local __resultvar=$1
    eval $__resultvar="network_testx_flavor"
}

function get_image_name()
{
    local __resultvar=$1
    eval $__resultvar="network_testx_image"
}

function get_all_network_ids()
{
    local __id
    local __arr=()
    local __list=$(openstack network list -f value -c ID)
    for __id in $__list
    do
        __arr+=($id)
    done
    all_net_ids=${__arr[@]}
}

function get_all_sr_network_ids()
{
    local __id
    local __arr=()
    local __match=$1
    local __list=$(openstack network list -f value -c ID -c Name | \
        grep $__match | cut -d ' ' -f1)
    for __id in $__list
    do
        __arr+=($__id)
    done
    all_sr_net_ids=${__arr[@]}
}

function get_subnet_id()
{
    local __resultvar=$1
    local __network_name=$2
    eval $__resultvar=$(openstack network list -f value -c Name -c Subnets | \
        grep $__network_name | cut -d ' ' -f2)
}

function get_sr_network_id()
{
    local __resultvar=$1
    local __network_name=$2
    eval $__resultvar=$(openstack network list -f value -c ID -c Name | \
        grep $__network_name | cut -d ' ' -f1)
}

function get_sr_network_subnet_id()
{
    local __resultvar=$1
    local __network_name=$2
    eval $__resultvar=$(openstack network list -f value -c Name -c Subnets | \
        grep $__network_name | cut -d ' ' -f2)
}

function is_elem_in_array()
{
    local __resultvar=$1
    local __arr=$2
    local __val=$3
    local __i

    eval $__resultvar="false"
    for __i in $__arr
    do
        if [ $__i == $__val ] ; then
            eval $__resultvar="true"
        fi
    done
}

function create_sr_network()
{
    local __base=$1
    local __index=$2
    local __net_name
    get_sr_net_from_base_index __net_name $__base $__index
    echo "openstack network create --provider-physical-network physnet1 "\
         "--provider-segment $(( $__base + $__index )) "\
         "--provider-network-type sr-evpn $__net_name" | bash -
}

function create_sr_subnet()
{
    local __base=$1
    local __index=$2
    local __net_name
    local __subnet_name
    get_sr_net_from_base_index __net_name $__base $__index
    get_subnet_name_from_base_index __subnet_name $__base $__index
    echo "openstack subnet create --network $__net_name"\
         "--subnet-range $(( 10 * $__index )).$(( 10 * $__index )).$(( 10 * $__index )).0/24 "\
         "$__subnet_name" | bash -
}

function list_all_sr_networks()
{
    local __id
    get_all_sr_network_ids network_testx
    for __id in $all_sr_net_ids
    do
        eval "openstack network show $__id"
    done
}

function create_subnet()
{
   local __base=$1
   local __index=$2
   local __net_name
   local __subnet_name

   get_sr_net_from_base_index __net_name $__base $__index
   get_subnet_name_from_base_index __subnet_name $__base $__index
   get_subnet_id subnet $__net_name
   if [[ -z $subnet ]] ; then
       create_sr_subnet $__base $__index
   else
       echo "Subnet $__subnet_name for $__net_name already exists"
   fi
}

function create_subnets()
{
    local __base=$1
    local __range=$2
    for (( x = 1; x <= $__range; x++ ))
    do
        create_subnet $__base $x
    done
}

function create_sr_net()
{
    local __base=$1
    local __index=$2
    local __name
    get_sr_net_from_base_index __name $__base $__index
    get_sr_network_id net $__name
    if [ -z $net ] ; then
        create_sr_network $__base $__index
    else
        echo "Network with $__name already exists"
    fi
}

function create_sr_nets()
{
    local __base=$1
    local __range=$2
    for (( x = 1; x <= $__range; x++ ))
    do
        create_sr_net $__base $x
    done
}

function create_srmpls_network()
{
    local __base=$1
    local __index=$2
    create_sr_net $__base $__index
    create_subnet $__base $__index
}

function create_srmpls_networks()
{
    local __base=$1
    local __range=$2
    create_sr_nets $__base $__range
    create_subnets $__base $__range
}

function clean_srmpls_networks()
{
    get_all_sr_network_ids "network_test"
    for __id in $all_sr_net_ids
    do
        eval "openstack network delete $__id"
    done
}

function get_sec_group_id()
{
    local __resultvar=$1
    local __name=$2
    eval $__resultvar=$(openstack security group list -f value -c ID -c Name | grep $__name | cut -d ' ' -f1)
}

function add_sec_group()
{
    local __name=$1
    eval 'openstack security group create $__name'
    eval 'openstack security group rule create $__name --protocol tcp --dst-port 1:65000 --remote-ip 0.0.0.0/0'
    eval 'openstack security group rule create $__name --protocol udp --dst-port 1:65000 --remote-ip 0.0.0.0/0'
    eval 'openstack security group rule create $__name --protocol icmp --remote-ip 0.0.0.0/0'
    eval 'openstack security group rule create $__name --protocol tcp --dst-port 1:65000 --remote-ip 0.0.0.0/0 --egress'
    eval 'openstack security group rule create $__name --protocol udp --dst-port 1:65000 --remote-ip 0.0.0.0/0 --egress'
    eval 'openstack security group rule create $__name --protocol icmp --remote-ip 0.0.0.0/0 --egress'
}

function create_sec_group()
{
    local __base=$1
    local __index=$2
    local __id
    local __name
    get_sec_group_name_from_base_index __name $__base $__index
    get_sec_group_id __id $__name
    if [[ -z $__id ]] ; then
        add_sec_group $__name
    else
        echo "Security group $__name already exists"
        #echo "openstack security group show $__id" | bash -
    fi
}

function get_flavor_id()
{
    local __resultvar=$1
    local __name=$2
    eval $__resultvar=$(openstack flavor list -f value -c ID -c Name | grep $__name | cut -d ' ' -f1)
}

function add_flavor()
{
    local __name=$1
    echo "openstack flavor create $__name --id 2 --ram 2048 --disk 20 \
        --vcpus 1" | bash -
    echo "nova flavor-key $__name set hw:cpu_policy=dedicated hw:mem_page_size=2048 \
         hw:numa_nodes=1" | bash -
}

function get_image_id()
{
    local __resultvar=$1
    local __name=$2
    eval $__resultvar=$(openstack image list -f value -c ID -c Name | grep $__name | cut -d ' ' -f1)
}

function add_image()
{
    local __name=$1
    local __file=$2
    echo "openstack image create $__name --file $__file" | bash -
}

function create_flavor()
{
    local __id
    local __name

    get_flavor_name __name
    get_flavor_id __id $__name
    if [[ -z $__id ]] ; then
        add_flavor $__name
    else
        echo "Flavor $__name already exists"
    fi
}

function create_image()
{
    local __id
    local __name
    local __file=$1

    if [[ -f $__file ]] ; then
        get_image_name __name
        get_image_id __id $__name
        if [[ -z $__id ]] ; then
            add_image $__name $__file
        else
            echo "Image $__name already exists"
        fi
    else
        echo -e "\n\e[1;31mFile $__file doesn't exist!\e[0m\n"
        help
    fi
}


function get_server_id()
{
    local __resultvar=$1
    local __name=$2
    eval $__resultvar=$(openstack server list -f value -c ID -c Name | grep $__name | cut -d ' ' -f1)
}

function add_server()
{
    local __base=$1
    local __index=$2
    local __server_name
    local __sec_group_name
    local __net_name
    local __flavor_name
    local __image_name
    local __server_id

    get_server_name_from_base_index __server_name $__base $__index
    get_sec_group_name_from_base_index __sec_group_name $__base $__index
    get_sr_net_from_base_index __net_name $__base $__index
    get_flavor_name __flavor_name
    get_image_name  __image_name

    create_sec_group $__base $__index
    create_srmpls_network $__base $__index
    get_server_id __server_id $__server_name
    get_sr_network_id __net_id $__net_name

    if [[ -z $__server_id ]] ; then
        echo "openstack server create --flavor $__flavor_name --image $__image_name --nic net-id=$__net_id "\
            "--security-group $__sec_group_name $__server_name" | bash -
    else
        echo "Server $__server_name for $__net_name already exists"
    fi
}

function create_server()
{
    local __base=$1
    local __index=$2
    add_server $__base $__index
}

function create_servers()
{
    local __base=$1
    local __range=$2
    for (( x = 1; x <= $__range; x++ ))
    do
        create_server $__base $x
    done
}

function get_all_my_server_ids()
{
    local __id
    local __arr=()
    local __match=$1
    local __list=$(openstack server list -f value -c ID -c Name | \
        grep $__match | cut -d ' ' -f1)
    for __id in $__list
    do
        __arr+=($__id)
    done
    all_my_server_ids=${__arr[@]}
}

function cleanup_my_server()
{
    local __base=$1
    local __index=$2
    local __server_name
    local __server_id

    get_server_name_from_base_index __server_name $__base $__index
    get_server_id __server_id $__server_name
    if [[ -z $__server_id ]] ; then
        echo "Server $__server_name not found"
    else
        echo "openstack server delete $__server_id" | bash -
    fi
}

function cleanup_my_servers()
{
    local __id
    get_all_my_server_ids "server_testx"
    echo $all_my_server_ids
    for __id in $all_my_server_ids
    do
        echo "openstack server delete $__id" | bash -
    done
}

help() {
  echo "-------------------------------------------------------------------------"
  echo "                      Available commands                                -"
  echo "-------------------------------------------------------------------------"
  echo "   > ./script.sh create_flavor           Name: network_testx_flavor      "
  echo "   > ./script.sh list_all_sr_networks    List all sr provider networks   "
  echo "   > ./script.sh clean_srmpls_networks   Clean all srmpls networks       "
  echo "   > ./script.sh cleanup_my_servers      Clean all the servers           "
  echo "   > ./script.sh cleanup_my_server       [args]  - arg0: base arg1: index"
  echo "   > ./script.sh create_sec_group        [args]  - arg0: base arg1: index"
  echo "   > ./script.sh create_srmpls_network   [args]  - arg0: base arg1: index"
  echo "   > ./script.sh create_srmpls_networks  [args]  - arg0: base arg1: range"
  echo "   > ./script.sh create_server           [args]  - arg0: base arg1: index"
  echo "   > ./script.sh create_servers          [args]  - arg0: base arg1: range"
  echo "   > help                                Display this help              "
  echo "-------------------------------------------------------------------------"
}

$*
