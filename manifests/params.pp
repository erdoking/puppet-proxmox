# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include proxmox::params
class proxmox::params {

  ## puppet
  $puppetversion = 7
  $puppetserver_binary = '/opt/puppetlabs/server/bin/puppetserver'
  $puppetclient_binary = '/opt/puppetlabs/bin/puppet'

  ## path
  $pvesh_path = '/usr/bin/pvesh'
  
}
