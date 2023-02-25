# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   proxmox::lxc::startstop { 'namevar': }
define proxmox::lxc::startstop (
  $lxc_name                                   = $title,
  Optional[Integer] $lxc_vmid,
  String[1] $pmx_node,
  Optional[Enum['running', 'stopped']] $state = 'running',
  Integer $boot_wait_time                     = 10,
  Optional[String] $pvesh_path                = $proxmox::pvesh_path,
) {

  # The base class must be included first because it is used by parameter defaults
  if ! defined(Class['proxmox']) {
    fail('You must include the proxmox base class before using any proxmox defined resources')
  }

  $proxmox_qemu = parsejson($facts['proxmox_qemu'])

  if ($lxc_vmid) {
    ## Evaluation Error: Error while evaluating a Resource Statement, Evaluation Error: Cannot reassign variable '$lxc_vmid
    $vmid = $lxc_vmid
  } else {
  
    ## get lxc vmid as hash
    $lxc_vmid_hash = $proxmox_qemu.map|$hash|{
      if $hash['name'] == $lxc_name {
        $hash['vmid']
      }
    }

    ## remove empty entries
    $lxc_vmid_filtered = $lxc_vmid_hash.filter |$x| { $x =~ NotUndef }

    ## convert to integer
    if $lxc_vmid_filtered =~ NotUndef {
      $vmid = Integer("${lxc_vmid_filtered[0]}")
    }
  }

  ## get vm state
  $vm_status = $proxmox_qemu.map|$hash|{
    if $hash['vmid'] == $vmid {
      $hash['status']
    }
  }

  ## if $lxc_vmid not allready in state ...
  if ! ($state in $vm_status) {

    if ( $state == 'running' ) {
       $set_state = 'start'
    } else {
      $set_state = 'shutdown'
    } 

    ## start/stop lxc 
    exec{"make sure ${lxc_name}[${vmid}] is ${state}":
      command => "${pvesh_path} create /nodes/${pmx_node}/lxc/${vmid}/status/${set_state}",
    }

    ## wait some seconds for booting up
    exec { "wait ${boot_wait_time} seconds for ${lxc_name}[${vmid}] to $set_state":
      command => "sleep ${boot_wait_time}",
      path    => ["/usr/bin", "/usr/sbin", "/bin"],
    }
  }
}
