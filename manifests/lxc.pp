# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
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
#   [*puppetserver_id*]      - OPTIONAL: lxc id of puppet master
#   [*puppetserver_name*]    - OPTIONAL: Name of Puppetserver
#   [*puppetversion*]        - OPTIONAL: version of puppet
#   [*install_puppet_agent*] - OPTIONAL: Boolean. If true, puppet agent will be installed automatic
#
define proxmox::lxc (

  ## Default Settings
  String[1] $pmx_node,
  String[1] $os_template,
  String[1] $lxc_name                 = $title,
  Integer $newid                      = Integer($facts['proxmox_cluster_nextid']),
  Enum['running', 'stopped'] $ensure  = 'running',

  ## VM Settings
  Integer $cpu_cores                  = 1,
  Integer $memory                     = 512,
  Integer $swap                       = 512,
  Boolean $protected                  = false,
  Boolean $unprivileged               = true,    ## default of Proxmox
  Boolean $onboot                     = false,

  ## Disk settings and Description
  # Optional[String]  $disk_size      = undef,
  Optional[Integer]  $disk_size       = undef,   ## Maybe switch back in the future
  String $disk_target                 = local,
  # Optional[String]  $description    = undef,

  ## Network Settings
  String $net_name                    = 'eth0',
  Optional[String]  $net_mac_addr     = undef,
  Optional[String]  $net_bridge       = undef,
  Boolean $ipv4_static                = false,
  Optional[String]  $ipv4_static_cidr = undef, # Needs to be in the format '192.168.1.20/24'
  Optional[String]  $ipv4_static_gw   = undef, # Needs to be in the format '192.168.1.1'
  # Optional[String]  $ci_sshkey      = '',  # Commented out; difficulties below.
  Optional[String] $searchdomain      = undef,
  Optional[String] $nameserver        = undef,

  ## Feature Settings
  Boolean $fuse                       = false,
  Boolean $mknod                      = false,
  Boolean $nfs                        = false,
  Boolean $cifs                       = false,
  Boolean $nesting                    = false,
  Boolean $keyctl                     = false,

  ## custom script
  Optional[String] $custom_script     = undef,

  ## puppet master
  Integer $puppetserver_id            = $proxmox::puppetserver_id,
  String $puppetserver_name           = $proxmox::puppetserver_name,
  Integer $puppetversion              = $proxmox::puppetversion,

  Boolean $install_puppet_agent       = true,

  Integer $boot_wait_time             = 10
) {

  # The base class must be included first because it is used by parameter defaults
  if ! defined(Class['proxmox']) {
    fail('You must include the proxmox base class before using any proxmox defined resources')
  }

  #################################################
  ### parse facts
  #################################################
  # Get and parse the facts for VMs, Storage, and Nodes.
  $proxmox_qemu     = parsejson($facts['proxmox_qemu'])
  $proxmox_storage  = parsejson($facts['proxmox_storage'])
  $proxmox_nodes    = parsejson($facts['proxmox_nodes'])

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

  #################################################
  ### create lxc
  #################################################
  # Evaluate variables to make sure we're safe to continue.
  # Confirm that the Clone ID is not the same as the New ID.
  if ! ($lxc_name in $vmnames) {

    ## marker
    $lxc_create_new = true
    $lxc_vmid = $newid

    proxmox::lxc::create { $lxc_name:
      pmx_node         => $pmx_node,
      os_template      => $os_template,
      lxc_name         => $lxc_name,
      newid            => $newid,

      ## VM Settings
      cpu_cores        => $cpu_cores,
      memory           => $memory,
      swap             => $swap,
      protected        => $protected,
      unprivileged     => $unprivileged,
      onboot           => $onboot,

      ## Disk settings and Description
      disk_size        => $disk_size,
      disk_target      => $disk_target,
#      description      => $description,

      ## Network Settings
      net_name         => $net_name,
      net_mac_addr     => $net_mac_addr,
      net_bridge       => $net_bridge,
      ipv4_static      => $ipv4_static,
      ipv4_static_cidr => $ipv4_static_cidr,
      ipv4_static_gw   => $ipv4_static_gw,
#      ci_sshkey        => $ci_sshkey,
      searchdomain     => $searchdomain,
      nameserver       => $nameserver,

      ## Feature Settings
      fuse             => $fuse,
      mknod            => $mknod,
      nfs              => $nfs,
      cifs             => $cifs,
      nesting          => $nesting,
      keyctl           => $keyctl,
    }
  } else {

    #################################################
    ### get lxc id from facts
    #################################################
    ## get lxc vmid as hash
    $lxc_vmid_hash = $proxmox_qemu.map|$hash| {
      if $hash['name'] == $lxc_name {
        $hash['vmid']
      }
    }

    ## remove empty entries
    $lxc_vmid_filtered = $lxc_vmid_hash.filter |$x| { $x =~ NotUndef }

    ## convert to integer
    if $lxc_vmid_filtered =~ NotUndef {
      $lxc_vmid = Integer("${lxc_vmid_filtered[0]}")
    }
  }

  #################################################
  ### start / stop
  #################################################
  if ($lxc_name in $vmnames) or ( $lxc_create_new == true) {
    ## ensure state
    proxmox::lxc::startstop { $lxc_name:
      pmx_node       => $pmx_node,
      ensure         => $ensure,
      boot_wait_time => $boot_wait_time,
      lxc_vmid       => $lxc_vmid,
    }
  }

  #################################################
  ### custom script
  #################################################
  if ($custom_script) and ($lxc_create_new == true) {
    exec { 'run_custom_script':
      command => "${custom_script} ${newid} ${lxc_name} ${ensure} ${puppetserver_id} ${puppetserver_name} ${searchdomain} ${puppetversion},",
      path    => ['/usr/bin','/usr/sbin', '/bin'],
      timeout => 0,
    }
  }

  #################################################
  ### install puppet agent
  #################################################
  if ($install_puppet_agent) and ( $lxc_create_new == true) {
    proxmox::lxc::puppetagent { "$lxc_vmid":
      lxc_id            => $lxc_vmid,
      puppetserver_id   => $puppetserver_id,
      puppetserver_name => $puppetserver_name,
      certname          => "${lxc_name}.${searchdomain}",
      puppetversion     => $puppetversion,
    }
  }

}
