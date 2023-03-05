# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   proxmox::lxc::create { 'namevar': }

# Paramters:
#   [*pmx_node*]          - The Proxmox node to create the lxc container on.
#   [*os_template*]       - Name of LXC template 
#   [*lxc_name*]           - OPTIONAL: The name of the new VM. (default: $title)
#   [*newid*]             - OPTIONAL: The ID for the new Virtual Machine. If unassigned, the next available ID will be used.
#
#   [*cpu_cores*]         - OPTIONAL: The number of CPU cores to be assigned to the new VM.
#   [*memory*]            - OPTIONAL: The amount of memory to be assigned to the new VM, in Megabytes (2GB = 2048).
#   [*swap*]              - OPTIONAL: The amount of swap to be assigned to the new VM, in Megabytes (2GB = 2048).
#   [*protected*]         - OPTIONAL: If true, it will protect the new VM from accidental deletion.
#   [*unprivileged*]      - OPTIONAL: If true, the new container is unprivileged (security feature).
#   [*onboot*]            - OPTIONAL: Boolean. Specifies whether a container will be started during system bootup.
#
#   [*disk_size*]         - OPTIONAL: The size of the new VM disk. If undefined, the default value of 4GB is used.
#   [*disk_target]        - OPTIONAL: The storage location for the new VM disk. If undefined, will default to the Templates volume.
#   [*description*]       - OPTIONAL: - Currently disabled 
#
#   [*net_name*]          - OPTIONAL: Name of network interface
#   [*net_mac_addr*]      - OPTIONAL: Mac address of network interface
#   [*net_bridge*]        - OPTIONAL: Name of network bridge
#   [*ipv4_static]        - Boolean. If true, you must define the CIDR and Gateway values.
#   [*ipv4_static_cidr*]  - OPTIONAL: If ipv4_static is true, this value must be in the format '192.168.1.20/24'.
#   [*ipv4_static_gw*]    - OPTIONAL: If ipv4_static is true, this value must be in the format '192.168.1.1'.
#
#   [*fuse*]              - OPTIONAL: Boolean. If true, feature "fuse" is defined
#   [*mknod*]             - OPTIONAL: Boolean. If true, feature "mknod" is defined
#   [*nfs*]               - OPTIONAL: Boolean. If true, feature "nfs" is defined
#   [*cifs*]              - OPTIONAL: Boolean. If true, feature "cifs" is defined
#   [*nesting*]           - OPTIONAL: Boolean. If true, feature "nesting" is defined 
#   [*keyctl*]            - OPTIONAL: Boolean. If true, feature "keyctl" is defined 
#
define proxmox::lxc::create (

  ## Default Settings
  String[1]           $pmx_node,
  String[1]           $os_template,
  Optional[String[1]] $lxc_name               = $title,
  Optional[Integer]   $newid                  = Integer($facts['proxmox_cluster_nextid']),

  ## VM Settings
  Integer $cpu_cores                          = 1,
  Integer $memory                             = 512,
  Integer $swap                               = 512,
  Boolean $protected                          = false,
  Boolean $unprivileged                       = true,    ## default of Proxmox
  Boolean $onboot                             = false,

  ## Disk settings and Description
  # Optional[String]  $disk_size              = undef,
  Optional[Integer]  $disk_size               = undef,   ## Maybe switch back in the future
  String $disk_target                         = local,
  # Optional[String]  $description             = undef,

  ## Network Settings
  String $net_name                            = 'eth0',
  Optional[String]  $net_mac_addr             = undef,
  Optional[String]  $net_bridge               = undef,
  Boolean $ipv4_static                        = false,
  Optional[String]  $ipv4_static_cidr         = undef, # Needs to be in the format '192.168.1.20/24'
  Optional[String]  $ipv4_static_gw           = undef, # Needs to be in the format '192.168.1.1'
  # Optional[String]  $ci_sshkey               = '',  # Commented out; difficulties below.
  Optional[String] $searchdomain              = undef,
  Optional[String] $nameserver                = undef,

  ## Feature Settings
  Boolean $fuse                               = false,
  Boolean $mknod                              = false,
  Boolean $nfs                                = false,
  Boolean $cifs                               = false,
  Boolean $nesting                            = false,
  Boolean $keyctl                             = false,
) {

  # Get and parse the facts for VMs, Storage, and Nodes.
  $proxmox_qemu    = parsejson($facts['proxmox_qemu'])
  $proxmox_storage = parsejson($facts['proxmox_storage'])
  $proxmox_nodes   = parsejson($facts['proxmox_nodes'])

  # Generate a list of VMIDS
  $vmids = $proxmox_qemu.map|$hash| { $hash['vmid'] }
  # Generate a list of VMIDS
  $vmnames = $proxmox_qemu.map|$hash| { $hash['name'] }

  # Generate a list of all Proxmox Nodes
  $nodes = $proxmox_qemu.map|$hash| { $hash['node'] }

  # Generate a list of all storage mediums on the specified node
  $disk_targets = $proxmox_storage.map|$hash| {
    if $hash['node'] == $pmx_node {
      $hash['storage']
    }
  }

  # Evaluate variables to make sure we're safe to continue.
  # Confirm that the Clone ID is not the same as the New ID.
  if ! ($lxc_name in $vmnames) {

    ## dirty hack, if no vmid is defined we can just create one vm during puppet run
    ## this is because "proxmox_cluster_nextid" just give one new id during run
    if ! defined(Exec["create_${newid}"]) {

      # Confirm that the New ID is not in the list of existing VMIDs.
      # If the New ID is in the list, simply don't attempt to create/overwrite it.
      if ! ($newid in $vmids) {

        ## comment: need to check - you can define it but not shown on webgui
        #    # Evaluate if there's a Description string.
        #    if ($description != undef) {
        #      $if_description = "--description='${description}'"
        #    }

        # Evaluate if there's a Disk Target String.
        if $disk_target {
          if $disk_target in $disk_targets {
            $if_disk_target = "--storage='${disk_target}'"
          } else {
            fail('The disk target cannot be found.')
          }
        }

        ## Set size of root fs
        if $disk_size {
          #if ! $disk_target {
          #  fail('disk_target not set but is required to set disk_size.')
          # } else {
            ## Found with try-and-error! Maybe not working on later versions
            $if_disk_size = "--rootfs=\"volume=${disk_target}:${disk_size}\""
          # }
        }

        # Evaluate if the VM should be unprivileged
        if ($unprivileged == true) {
          $if_unprivileged = '--unprivileged 1'
        }

        # Evaluate if the VM should be protected
        if ($protected == true) {
          $if_protection = '--protection 1'
        }

        # Evaluate if the VM should be autostart on boot
        if ($onboot == true) {
          $if_onboot = '--onboot 1'
        }

        # Evaluate if searchdomain is defined
        if $searchdomain {
          $if_searchdomain = "--searchdomain ${searchdomain}"
        }

        # Evaluate if nameserver is defined
        if $nameserver {
          if (($nameserver =~ Stdlib::IP::Address::V4) == false) {
            fail('Nameserver is in the wrong format or undefined. MUST be a valid IPv4 address')
          }
          # If the above checks pass, set the ip settings
          $if_nameserver = "--nameserver ${nameserver}"
        }

        ## Evaluate the features
        if ($fuse) or ($mknod) or ($nfs) or ($cifs) or ($nesting) {
          if ($fuse == true) {
            $if_fuse = ',fuse=1'
          }
          if ($mknod == true) {
            $if_mknod = ',mknod=1'
          }
          if ($nesting == true) {
            $if_nesting = ',nesting=1'
          }
          if ($keyctl == true) {
            $if_keyctl = ',keyctl=1'
          }
          ## Evaluate mount-features
          if ($nfs) or ($cifs) {
            if ($nfs == true) and ($cifs == true) {
              $if_mounts = ',mount="nfs;cifs"'
            } elsif ($cifs == true) {
              $if_mounts = ',mount="cifs"'
            } else {
              $if_mounts = ',mount="nfs"'
            }
          }

          ## remove first character (,)
          $features_string = "${if_fuse}${if_mknod}${if_nesting}${if_keyctl}${if_mounts}"
          $features = regsubst("${features_string}", '^.(.*)$', '\1')
          $if_features="--features=\"${features}\""
        }

        # Check if there's a custom Cloud-Init SSH Key, and URI encodes it
        # Commented out, having immense difficulty figuring out the correct string format.
        # if ($ci_sshkey != '') {
        #   $uriencodedsshkey = uriescape($ci_sshkey)
        #   $if_cisshkey = "--sshkeys=${uriencodedsshkey}"
        # }

        if $net_name {
          ## Check if there are custom network requirements
          if $ipv4_static == true {
            if (($ipv4_static_cidr =~ Stdlib::IP::Address::V4) == false) and ($ipv4_static_cidr != '') {
              fail('IP address is in the wrong format or undefined.')
            }
            if (($ipv4_static_gw =~ Stdlib::IP::Address::V4) == false) and ($ipv4_static_gw != '') {
              fail('Gateway address is in the wrong format or undefined.')
            }
            # If the above checks pass, set the ip settings
            $if_nondhcp = ",ip=${ipv4_static_cidr},gw=${ipv4_static_gw}"
          } else {
            $if_nondhcp = ',ip=dhcp'
          }

          ## definde network brige and warn is not defined
          if ! $net_bridge {
            ## How to print real warning? warning() not working anymore
            notify { 'WARN: Network bridge undefined.': }
          } else {
            $if_net_bridge = ",bridge=${net_bridge}"
          }

          ## mac address
          if $net_mac_addr {
            if (($net_mac_addr =~ /^([0-9a-fA-F]{2}\:){5}([0-9a-fA-F]{2})$/) == false) {
              fail('MAC address is in the wrong format or undefined.')
            } else {
              $if_net_mac_addr = ",hwaddr=${net_mac_addr}"
            }
          }

          ## set network config
          $if_net_config = "--net0=\'name=${net_name}${if_nondhcp}${if_net_bridge}${if_net_mac_addr}\'"
        }

        # Create the VM
        exec { "create_${newid}":
          command => "/usr/bin/pvesh create /nodes/${pmx_node}/lxc --vmid=${newid} --ostemplate local:vztmpl/${os_template}\
          --hostname=${lxc_name} ${if_disk_target} --cores=${cpu_cores} --memory=${memory} --swap=${swap} ${if_protection} ${if_unprivileged} ${$if_onboot} ${if_net_config} ${if_features} ${if_disk_size} ${if_searchdomain} ${if_nameserver
}",
        }
      }
    }
  }
}
