VCSIM_USERNAME="user"
VCSIM_PASSWORD="pass"
CLUSTER_NAME_PREFIX="DC0_C"
pline="\n=====================================\n"
ip="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
echo -e "$pline host_name of vc simulator : $ip $pline"
echo -e "$pline cluster count: $1 $pline"
echo -e "$pline node count per cluster: $2 $pline"
echo -e "$pline vm count per node: $3 $pline"
echo -e "$pline killing existing vcsim proc $pline"
pkill vcsim
/go/bin/vcsim -l $ip:8989 -username $VCSIM_USERNAME -password $VCSIM_PASSWORD &
# shellcheck disable=SC2006
newpid=`ps -aef | grep vcsim | grep -v sh | grep -v grep | awk '{print $2}'`
export GOVC_URL=https://$VCSIM_USERNAME:$VCSIM_PASSWORD@$ip:8989/sdk GOVC_SIM_PID=$newpid
echo "export GOVC_URL=https://$VCSIM_USERNAME:$VCSIM_PASSWORD@$ip:8989/sdk GOVC_SIM_PID=$newpid"  >> ~/.bash_profile
echo "export GOVC_INSECURE=1" >> ~/.bash_profile
echo -e "$pline export GOVC_INSECURE=1 $pline"
export GOVC_INSECURE=1
sleep 5
echo -e "$pline Creating $1 Clusters $pline"
for ((cluster=1; cluster<=$1; cluster++))
do
  cluster_name="${CLUSTER_NAME_PREFIX}${cluster}_${ip}"
  echo -e "$pline Creating $cluster_name $pline"
  /go/bin/govc cluster.create $cluster_name
  for ((node=1; node<=$2; node++))
  do
    host_name=$(printf "%d.%d.%d.%d\n" "$((RANDOM % 256 ))" "$((RANDOM % 256 ))" "$((RANDOM % 256 ))" "$((RANDOM % 256 ))")
    echo -e "$pline Adding host $host_name in $cluster_name $pline"
    /go/bin/govc cluster.add -cluster=$cluster_name -hostname $host_name -username $VCSIM_USERNAME -password $VCSIM_PASSWORD -k=true
    datastore_name="LocalDS_$host_name"
    echo -e "$pline Creating $datastore_name for $host_name $pline"
    /go/bin/govc datastore.create -type local -name $datastore_name -path /var/local $host_name
    echo -e "$pline Adding host $host_name to DVS0 $pline"
    /go/bin/govc dvs.add -dvs=/DC0/network/DVS0 -k=true $host_name
    for ((vm=1; vm<=$3; vm++))
    do
      vm_name="${host_name}_VM_${vm}"
      echo -e "$pline Creating $vm_name $pline"
      /go/bin/govc vm.create -ds $datastore_name -pool=/DC0/host/$cluster_name/Resources -host $host_name -net="VM Network" -on=false $vm_name
      vm_ip=$(printf "%d.%d.%d.%d\n" "$((RANDOM % 256 ))" "$((RANDOM % 256 ))" "$((RANDOM % 256 ))" "$((RANDOM % 256 ))")
      vm_mac=$(printf "00:60:2f$(od -txC -An -N3 /dev/random|tr \  :)")
      /go/bin/govc vm.customize -vm $vm_name -mac $vm_mac -ip $vm_ip -netmask 255.255.255.0
      /go/bin/govc vm.power -on $vm_name
    done
  done
done
