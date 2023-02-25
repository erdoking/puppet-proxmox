# Install and register puppet agent in LXC container
# need to run on proxmox server directly
#
# Paramters:
#   [*lxc_id*]            - id of new lxc container
#   [*puppetserver_id*]   - OPTIONAL: id of puppetmaster lxc container if given we will try to clean and sign the new vm
#   [*puppetserver_name*] - OPTIONAL: name of puppetmaster for agent config
#   [*certname*]          - OPTIONAL: certname of new vm if given we will try to clean and sign the new vm
#   [*checkcmd*]          - OPTIONAL: how to check if puppet agent allready installed
#   [*puppetversion*]     - OPTIONAL: for other versions, default to 7
#
define proxmox::lxc::puppetagent (
  ## Default Settings
  Integer[1] $lxc_id,
  Optional[Integer] $puppetserver_id    = $proxmox::puppetserver_id,
  Optional[String] $puppetserver_name   = $proxmox::puppetserver_name,
  Optional[String] $puppetserver_binary = $proxmox::puppetserver_binary,
  Optional[String] $puppetclient_binary = $proxmox::puppetclient_binary,

  Optional[String] $certname,
  Optional[Integer] $puppetversion      = $proxmox::puppetversion,
) {

  ## defaults
  Exec {
    path    => ["/usr/bin","/usr/sbin", "/bin"],
  }

  exec { 'apt update':
    ## hack if repos switch to oldstable (returncode 100)
    command => "pct exec ${lxc_id} -- apt update --allow-releaseinfo-change",
    returns => [0, 100],
  }

  exec { 'install dependencies':
    command => "pct exec ${lxc_id} -- apt install wget lsb-release -y",
  }

  exec { 'download puppet':
    ## eg: wget -O /tmp/puppet7-release-buster.deb https://apt.puppet.com/puppet7-release-buster.deb 
    command => "pct exec ${lxc_id} -- bash -c 'wget -O /tmp/puppet${puppetversion}-release-`lsb_release -cs`.deb https://apt.puppet.com/puppet${puppetversion}-release-`lsb_release -cs`.deb'",
  }

  exec { 'install puppet':
    command => "pct exec ${lxc_id} -- bash -c 'dpkg -i /tmp/puppet${puppetversion}-release-`lsb_release -cs`.deb'",
  }

  exec { 'apt update 2':
    command => "pct exec ${lxc_id} -- apt update",
  }

  exec { 'apt upgrade':
    command => "pct exec ${lxc_id} -- apt upgrade -y",
    timeout => 0,
  }

  if ($puppetserver_id) and ($puppetserver_id != 0) and ($certname) {
    exec { 'ca clean on puppetmaster':
      command => "pct exec ${puppetserver_id} -- ${puppetserver_binary} ca clean --certname ${certname.downcase()}",
      returns => [0, 1],
    }
  }

  exec { 'install puppet agent':
    command => "pct exec ${lxc_id} -- apt install puppet-agent -y",
  }

  if ($puppetserver_name != '') {
    exec { 'set puppet master':
      command => "pct exec ${lxc_id} -- ${puppetclient_binary} config set server \'${puppetserver_name}\' --section main",
    }

    exec { 'run puppet agent':
      command => "pct exec ${lxc_id} -- ${puppetclient_binary} agent -t",
      returns => 1,
    }
  }

  if ($puppetserver_id != 0) and ($puppetserver_name != '') {
    ## necessary step on puppermaster
    exec { 'sign puppet agent':
      command => "pct exec ${puppetserver_id} -- ${puppetserver_binary} ca sign --certname ${certname.downcase()}"
    }

    exec { 'start puppet agent':
      command => "pct exec ${puppetserver_id} -- systemctl start puppet"
    }

#    notify { "The next step can running for a long time! Timout disabled ...": }
#
#    exec { 'run puppet agent 2':
#      command => "pct exec ${lxc_id} -- ${puppetclient_binary} agent -t",
#      timeout  => 0,
#      returns => [0, 2],
#    }

  }
}
