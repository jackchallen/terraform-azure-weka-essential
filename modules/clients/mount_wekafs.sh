INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH
cd $INSTALLATION_PATH

IFS=" " read -ra ips <<< "${backend_ips}"
backend_ip="$${ips[RANDOM % $${#ips[@]}]}"
# install weka using random backend ip from ips list
function retry_weka_install {
  retry_max=60
  retry_sleep=30
  count=$retry_max

  while [ $count -gt 0 ]; do
      curl --fail -o install_script.sh $backend_ip:14000/dist/v1/install && break
      count=$(($count - 1))
      backend_ip="$${ips[RANDOM % $${#ips[@]}]}"
      echo "Retrying weka install from $backend_ip in $retry_sleep seconds..."
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "weka install failed after $retry_max attempts"
      return 1
  }
  chmod +x install_script.sh && ./install_script.sh
  return 0
}

retry_weka_install

FILESYSTEM_NAME=default # replace with a different filesystem at need
MOUNT_POINT=/mnt/weka # replace with a different mount point at need
mkdir -p $MOUNT_POINT

weka local stop && weka local rm -f --all

gateways="${all_gateways}"
subnets="${all_subnets}"
NICS_NUM="${nics_num}"
eth0=$(ifconfig | grep eth0 -C2 | grep 'inet ' | awk '{print $2}')

mount_command="mount -t wekafs -o net=udp $backend_ip/$FILESYSTEM_NAME $MOUNT_POINT"
if [[ ${mount_clients_dpdk} == true ]]; then
  getNetStrForDpdk $(($NICS_NUM-1)) $(($NICS_NUM)) "$gateways" "$subnets" "-o net="
  mount_command="mount -t wekafs $net -o num_cores=1 -o mgmt_ip=$eth0 $backend_ip/$FILESYSTEM_NAME $MOUNT_POINT"
fi

retry 60 30 $mount_command

rm -rf $INSTALLATION_PATH
