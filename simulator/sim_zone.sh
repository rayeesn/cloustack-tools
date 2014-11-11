#!/bin/bash


# Script to set up infra - zone, pod, cluster, host, VMs

mgmtServer=$1
podCount=$2
delay=120

zone_query="GET  http://$mgmtServer/client/?command=createZone&networktype=Advanced&securitygroupenabled=false&name=zone1&dns1=4.2.2.2&internaldns1=4.2.2.2&vlan=1-100&guestcidraddress=10.1.1.0%2F24	HTTP/1.0\n\n"
createzone_out=$(echo -e $zone_query | nc -v -w 120 $mgmtServer 8096)
echo $createzone_out
zoneid=$(echo $createzone_out | sed 's/\(.*<id>\)\(.*\)\(<\/id>.*\)/\2/g')

physicalNetwork_query="GET http://$mgmtServer/client/?command=createPhysicalNetwork&zoneid=$zoneid&name=Physical_Network_1 HTTP/1.0\n\n"
physicalNetwork_out=$(echo -e $physicalNetwork_query | nc -v -w $delay $mgmtServer 8096)
echo $physicalNetwork_out
phynetworkid=$(echo $physicalNetwork_out | sed 's/\(.*<id>\)\(.*\)\(<\/id>.*\)/\2/g')

addmgmttraffictype_query="GET http://$mgmtServer/client/?command=addTrafficType&trafficType=Management&physicalnetworkid=$phynetworkid HTTP/1.0\n\n"
echo -e $addmgmttraffictype_query | nc -v -w $delay $mgmtServer 8096

addguesttraffictype_query="GET http://$mgmtServer/client/?command=addTrafficType&trafficType=Guest&physicalnetworkid=$phynetworkid HTTP/1.0\n\n"
echo -e $addguesttraffictype_query | nc -v -w $delay $mgmtServer 8096

addpublictraffictype_query="GET http://$mgmtServer/client/?command=addTrafficType&trafficType=Public&physicalnetworkid=$phynetworkid HTTP/1.0\n\n"
echo -e $addpublictraffictype_query | nc -v -w $delay $mgmtServer 8096

update_physicalNetwork_query="GET http://$mgmtServer/client/?command=updatePhysicalNetwork&state=Enabled&vlan=1-100&id=$phynetworkid HTTP/1.0\n\n"
echo -e $update_physicalNetwork_query | nc -v -w $delay $mgmtServer 8096

listNetworkServiceProviders_query="GET http://$mgmtServer/client/?command=listNetworkServiceProviders&name=VirtualRouter&physicalNetworkId=$phynetworkid HTTP/1.0\n\n"
echo $listNetworkServiceProviders_query
listNetworkServiceProviders_out=$(echo -e $listNetworkServiceProviders_query  | nc -v -w $delay $mgmtServer 8096)
echo $listNetworkServiceProviders_out
nsp_id=$(echo $listNetworkServiceProviders_out | sed 's/\(.*<id>\)\(.*\)\(<\/id>.*\)/\2/g')

listVirtualRouterElements_query="GET http://$mgmtServer/client/?command=listVirtualRouterElements&nspid=$nsp_id HTTP/1.0\n\n"
echo $listVirtualRouterElements_query
listVirtualRouterElements_out=$(echo -e $listVirtualRouterElements_query  | nc -v -w $delay $mgmtServer 8096)
echo $listVirtualRouterElements_out
vr_id=$(echo $listVirtualRouterElements_out | sed 's/\(.*<id>\)\(.*\)\(<\/id>.*\)/\2/g')

configureVirtualRouterElement_query="GET http://$mgmtServer/client/?command=configureVirtualRouterElement&enabled=true&id=$vr_id HTTP/1.0\n\n"
echo -e $configureVirtualRouterElement_query | nc -v -w $delay $mgmtServer 8096

updateNetworkServiceProvider_vr_query="GET http://$mgmtServer/client/?command=updateNetworkServiceProvider&state=Enabled&id=$nsp_id HTTP/1.0\n\n"
echo -e $updateNetworkServiceProvider_vr_query | nc -v -w $delay $mgmtServer 8096

listNetworkServiceProviders_query="GET http://$mgmtServer/client/?command=listNetworkServiceProviders&name=SecurityGroupProvider&physicalNetworkId=$phynetworkid HTTP/1.0\n\n"
echo $listNetworkServiceProviders_query
listNetworkServiceProviders_out=$(echo -e $listNetworkServiceProviders_query  | nc -v -w $delay $mgmtServer 8096)
echo $listNetworkServiceProviders_out
nsp_id=$(echo $listNetworkServiceProviders_out | sed 's/\(.*<id>\)\(.*\)\(<\/id>.*\)/\2/g')

updateNetworkServiceProvider_sg_query="GET http://$mgmtServer/client/?command=updateNetworkServiceProvider&state=Enabled&id=$nsp_id HTTP/1.0\n\n"
echo -e $updateNetworkServiceProvider_sg_query | nc -v -w $delay $mgmtServer 8096

updateZone_query="GET http://$mgmtServer/client/?command=updateZone&allocationstate=Enabled&id=$zoneid HTTP/1.0\n\n"
echo -e $updateZone_query | nc -v -w $delay $mgmtServer 8096


#Add Secondary Storage
sstor_query="GET  http://$mgmtServer/client/?command=addSecondaryStorage&zoneid=$zoneid&url=nfs://172.16.15.32/export/share/secondary  HTTP/1.0\n\n"
echo -e $sstor_query | nc -v -w 120 $mgmtServer 8096

vlan_query="GET http://$mgmtServer/client/?command=createVlanIpRange&forVirtualNetwork=true&zoneId=$zoneid&vlan=untagged&gateway=172.120.1.1&netmask=255.255.0.0&startip=172.120.1.2&endip=172.120.255.254	HTTP/1.0\n\n"
echo -e $vlan_query | nc -v -w 300 $mgmtServer 8096

x=1
for name in `seq 1 $podCount`
do
    pod_query="GET  http://$mgmtServer/client/?command=createPod&zoneId=$zoneid&name=BLRPod$x&netmask=255.255.255.0&startIp=172.$x.255.2&endIp=172.$x.255.252&gateway=172.$x.255.1	HTTP/1.0\n\n"
    pod_out=$(echo -e $pod_query | nc -v -w 300 $mgmtServer 8096)
    pod_id=$(echo $pod_out | sed 's/\(.*<id>\)\(.*\)\(<\/id>.*\)/\2/g')
    for k in `seq 1 2`
    do
	cluster_query="GET http://$mgmtServer/client/?command=addCluster&hypervisor=Simulator&clustertype=CloudManaged&zoneId=$zoneid&podId=$pod_id&clustername=CS-$name-$k	HTTP/1.0\n\n"
	cluster_out=$(echo -e $cluster_query | nc -v -w 300 $mgmtServer 8096)
        cluster_id=$(echo $cluster_out | sed 's/\(.*<id>\)\(.*\)\(<\/id>.*\)/\2/g')
	for j in `seq 1 2`
	do
		host_query="GET	http://$mgmtServer/client/?command=addHost&zoneId=$zoneid&podId=$pod_id&clusterid=$cluster_id&hypervisor=Simulator&clustertype=CloudManaged&hosttags=&username=sim&password=sim&url=http%3A%2F%2Fsim	HTTP/1.0\n\n"
		echo -e $host_query | nc -v -w 300 $mgmtServer 8096
	done
    	spool_query="GET http://$mgmtServer/client/?command=createStoragePool&zoneId=$zoneid&podId=$pod_id&clusterid=$cluster_id&name=SPOOL$name$k&url=nfs://172.1.25.$k/export/share/$name$k   HTTP/1.0\n\n"
    	echo -e $spool_query | nc -v -w 300 $mgmtServer 8096
    done
    let x+=1
done
