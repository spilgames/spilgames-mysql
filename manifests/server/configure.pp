# == Class: spil_mysql::configure
#
# Class to configure environment for MySQL. For the actual server configuration
# see spil_mysql::server.
#
# === Parameters
#
# [*is_big*]
#   Boolean. If set to true, sysctl variables suitable for big instance get
#   set.
#
# [*set_scheduler_noop*]
#   Boolean. If set to true, I/O scheduler gets set to true for
#   *dd_sysfs_path*. Defaults to false.
#
# [*dd_sysfs_path*]
#   Path of the block device on sysfs for the filesystem MySQL datadir is on.
#   Defaults to '/sys/block/sdb'.
#
# === Variables
#
# [*override_options*]
#   MySQL options from hiera key mysql::server::override_options. Used to see,
#   to what 'max_connections' is set.
#
# === Authors
#
# Jaakko Pesonen <jaakko.pesonen@spilgames.com>
#
# === Copyright
#
# Copyright 2014 Spilgames

class spil_mysql::server::configure(
  $is_big             = $spil_mysql::params::is_big,
  $dd_sysfs_path      = $spil_mysql::params::datadir_sysfs_path,
  $set_scheduler_noop = $spil_mysql::params::set_scheduler_noop,
)inherits ::spil_mysql::params{

  # Set sysctl variables for ALL hosts having is_big set to true.
  if $is_big {
    # Try to avoid dropped TCP packets
    include sysctl
    sysctl::conf {
      'net.ipv4.tcp_max_syn_backlog':     value => 10000;
      'net.core.netdev_max_backlog':      value => 30000;
      'net.core.rmem_max':                value => 16777216;
      'net.core.wmem_max':                value => 16777216;
      'net.ipv4.tcp_congestion_control':  value => 'htcp';
      'net.ipv4.tcp_rmem':                value => '4096 87380 16777216';
      'net.ipv4.tcp_wmem':                value => '4096 65536 16777216';
      'net.ipv4.tcp_max_tw_buckets':      value => 400000;
      'net.core.somaxconn':               value => 4096;
    }
  }

  # Use noop scheduler on datadir
  if $set_scheduler_noop {
    exec{"/bin/echo noop > ${dd_sysfs_path}/queue/scheduler":
      unless => "/bin/cat ${dd_sysfs_path}/queue/scheduler | /bin/grep -q '\\[noop\\]' 2>/dev/null"
    }
  }

  file{'mysql_cron':
    path   => '/etc/cron.d/SPI-mysql.cron',
    owner  => 'root',
    group  => 'admin',
    mode   => '0640',
    source => "puppet:///modules/${module_name}/SPI-mysql.cron"
  }

  #Override the default process limit of 1024 to what it is configured to be by RH
  #See also: http://www.percona.com/blog/2013/02/04/cant_create_thread_errno_11/
  $override_options = hiera_hash('mysql::server::override_options', {})
  if has_key($override_options, 'mysqld') and has_key($override_options['mysqld'], 'max_connections') {
    #Safest would be 1024 plus the double of the configured amount of connecitons. This would not
    #make it exessively high when set to a high number of connections and enough headroom for root
    $mysql_proc_limit = 1024 + ( $override_options['mysqld']['max_connections'] * 2)
  }
  else {
    $mysql_proc_limit = 2048
  }

  file{'91-mysql_conf':
    path    => '/etc/security/limits.d/91-mysql.conf',
    owner   => 'root',
    group   => 'admin',
    mode    => '0640',
    content => template("${module_name}/91-mysql.conf.erb")
  }
}

