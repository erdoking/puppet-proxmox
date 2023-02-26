# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include proxmox
class proxmox (
  Integer $puppetserver_id  = $proxmox::puppetserver_id,
  String $puppetserver_name = $proxmox::puppetserver_name,
) inherits proxmox::params {
}
