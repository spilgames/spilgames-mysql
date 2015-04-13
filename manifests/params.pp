# == Class: spil_mysql::params
#
# Default parameter values for Spil MySQL setups.
#
# === Parameters
#
# None
#
# === Variables
#
# None
#
# === Authors
#
# Jaakko Pesonen <jaakko.pesonen@spilgames.com>
#
# === Copyright
#
# Copyright 2014 Spilgames

class spil_mysql::params {

  $innodb_bp_size       = inline_template('<%= (@memorysize_mb.to_f * 0.6).to_i %>')
  $server_id            = inline_template('<%= /^[[:alpha:]]+([[:digit:]]+)/.match(@hostname)[1] %>')
  $cluster_type         = 'unknown'
  $one_disk_install     = false
  $galera_bootstrap_cmd = '/etc/init.d/mysql bootstrap-pxc'
  $base_options = {
    'innodb_thread_concurrency' => $::processorcount * 2,
    'innodb_buffer_pool_size'   => "${innodb_bp_size}M",
    'server_id'                 => $server_id,
  }

  # Variables for mysql statsd
  $mysqlstatsd_enabled  = false
  $mysqlstatsd_password = 'bogus_changeme'

  # spil_mysql::install params
  $config_file      = hiera('mysql::server::config_file', '/etc/my.cnf')
  $volume_group     = 'vg_0'
  $physical_volumes = ['/dev/vdb']
  $logical_volumes  = ['lv_mysql']
  $mount_point      = '/mnt/data'

  # spil_mysql::configure params
  $is_big             = false
  $datadir_sysfs_path = '/sys/block/sdb'
  $set_scheduler_noop = false
}
