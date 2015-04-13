# == Class: spil_mysql::server
#
# Class to set up MySQL servers Spil style. Uses mysql::server from Puppetlbas
# mysql module to do most of the heavy lifting.
#
# === Parameters
#
# [*override_options*]
#   MySQL server configuration options. Passed on to mysql::server class as
#   override_options parameter. Looked up from hiera as
#   mysql::server::override_options. Hash. Default {}.
#
# [*users*]
#   MySQL server users. Passed on to mysql::server class as users parameter.
#   Looked up from hiera as mysql::server::users. Hash. Default {}.
#
# [*grants*]
#   MySQL server grants. Passed on to mysql::server class as
#   grants parameter. Looked up from hiera as mysql::server::grants. Hash.
#   Default {}.
#
# [*databases*]
#   Databases to create during MySQL server install. Passed on to mysql::server
#   class as databases parameter. Looked up from hiera as
#   mysql::server::databases. Hash. Default {}.
#
# [*mysql::server parameters*]
#   Not really parameters for this class, but just a reminder, that all
#   mysql::server parameters not listed above are automatically looked up from
#   hiera.
#
# [*cluster_type*]
#   Type of the cluster to set up. Possible values are 'galera' and 'mha'.
#   Using any other value will lead to setting up a standalone mysql host.
#   Galera cluster_type is also implicitly inferred from MySQL server name.
#   Cluster type is also assumed to be Galera, if no 'mha' is specified and
#   cluster has more than one memeber.
#
# [*mysql_config_file*]
#   Path to mysql config file. Evil breaking of best practices by defaulting to
#   mysql::server::config_file from hiera.
#
# [*volume_group*]
#   Name of the volume group to create for the disk containing mysql data dir.
#   String. E.g. vg_0
#
# [*physical_volumes*]
#   Paths to physical volumes underlying volume group. Array. E.g. [/dev/vdb]
#
# [*logical_volumes*]
#   List of logical volumes to create on top of the volume group. Hash. E.g.
#   lv_mysql
#       volume_group: vg_0
#       size: 5G
#       mountpath: /mnt/data
#
# [*mount_point*]
#   Mount point for file system containing mysql datadirectory. Must be a
#   mountpath from one of the logical volume definitions. String. E.g. Seggin
#   $mount_point to /mnt/data will cause the actual mysql data directory to be
#   /mnt/data/mysql.
#
# [*one_disk_install*]
#   If set to true, installation does not require the host to have an extra
#   volume to be attached for mysql datadir.
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
# [*galera_bootstrap_cmd*]
#   Command to use for bootstrapping Galera cluster.
#
# [*mysqlstatsd_enabled*]
#   Wether to enable mysql statsd collector on the server.
#
# [*mysqlstatsd_password*]
#   Passowrd mysql statsd uses for connecting to mysql server.
#
# === Authors
#
# Jaakko Pesonen <jaakko.pesonen@spilgames.com>
#
# === Copyright
#
# Copyright 2014 Spilgames


class spil_mysql::server(
  $override_options     = hiera_hash('mysql::server::override_options', {}),
  $users                = hiera_hash('mysql::server::users', {}),
  $grants               = hiera_hash('mysql::server::grants', {}),
  $databases            = hiera_hash('mysql::server::databases', {}),
  $cluster_type         = $spil_mysql::params::cluster_type,
  $mysql_config_file    = hiera('mysql::server::config_file', $spil_mysql::params::config_file),
  $volume_group         = $spil_mysql::params::volume_group,
  $physical_volumes     = $spil_mysql::params::physical_volumes,
  $logical_volumes      = $spil_mysql::params::logical_volumes,
  $mount_point          = $spil_mysql::params::mount_point,
  $one_disk_install     = $spil_mysql::params::one_disk_install,
  $is_big               = $spil_mysql::params::is_big,
  $set_scheduler_noop   = $spil_mysql::params::set_scheduler_noop,
  $dd_sysfs_path        = $spil_mysql::params::datadir_sysfs_path,
  $galera_bootstrap_cmd = $spil_mysql::params::galera_bootstrap_cmd,
  $mysqlstatsd_enabled  = $spil_mysql::params::mysqlstatsd_enabled,
  $mysqlstatsd_password = $spil_mysql::params::mysqlstatsd_password,
)inherits ::spil_mysql::params{

  class {'spil_mysql::server::install':
    mysql_config_file => $mysql_config_file,
    volume_group      => $volume_group,
    physical_volumes  => $physical_volumes,
    logical_volumes   => $logical_volumes,
    mount_point       => $mount_point,
    one_disk_install  => $one_disk_install,
  }
  contain spil_mysql::server::install
  class {'spil_mysql::server::configure':
    is_big             => $is_big,
    dd_sysfs_path      => $dd_sysfs_path,
    set_scheduler_noop => $set_scheduler_noop,
  }
  contain spil_mysql::server::configure
  Class['spil_mysql::server::install'] -> Class['spil_mysql::server::configure']
  if $mysqlstatsd_enabled {
    class {'spil_mysql::server::mysqlstatsd':
      mysqlstatsd_password => $mysqlstatsd_password
    }
    Class['spil_mysql::server::configure'] -> Class['spil_mysql::server::mysqlstatsd']
  }

  file {'/etc/my.cnf':
    ensure => absent,
  }

  $cm = get_servers_by_role($::cluster, 'cluster')
  if count($cm) == 0 {
    $cluster_members = [$::fqdn]
  } else {
    $cluster_members = $cm
  }

  # Black magic warning: having more than one member in a cluster or
  # installing a known Galera package makes this module to set up a galera
  # cluster unless $cluster_type is specified, when calling this class.
  $server_package = hiera('mysql::server::package_name', 'unknown')
  if $cluster_type == 'unknown' and (count($cluster_members) > 1 or $server_package =~ /XtraDB|galera/) {
    $ct = 'galera'
  }

  $galera_options = {
    'wsrep_slave_threads'   => $::processorcount * 2,
    'wsrep_cluster_address' => inline_template('<%= "gcomm://" + @cluster_members.join(",") %>'),
  }

  if $ct == 'galera' {
    $default_options = {
      'mysqld' => merge($spil_mysql::params::base_options, $galera_options)
    }
  } else {
    $default_options = {
      'mysqld' => $spil_mysql::params::base_options
    }
  }

  $options = mysql_deepmerge($default_options, $override_options)

  class{'mysql::server':
    override_options => $options,
    users            => $users,
    grants           => $grants,
    databases        => $databases,
  }
  contain 'mysql::server'

  if $ct == 'galera' {
    if has_key($override_options, 'mysqld') and has_key($override_options['mysqld'], 'wsrep_group_comm_port') {
      $wsrep_group_comm_port = $override_options['mysqld']['wsrep_group_comm_port']
    } else {
      $wsrep_group_comm_port = 4567
    }
    $server_list = join($cluster_members, ' ')
    exec { 'boostrap_galera_cluster':
      command  => $galera_bootstrap_cmd,
      onlyif   => "ret=1; for i in ${server_list}; do nc -z \$i ${wsrep_group_comm_port}; if [ \"\$?\" = \"0\" ]; then ret=0; fi; done; /bin/echo \$ret | /bin/grep 1 -q",
      require  => Class['mysql::server::config'],
      before   => [Class['mysql::server::service'], Service['mysqld']],
      provider => shell,
      path     => '/usr/bin:/bin:/usr/sbin:/sbin'
    }

    # Hack to cope with the fact that Galera STT also changes the password on
    # second and later nodes on cluster.
    exec { 'root_my.cnf':
      command  => "echo \"[client]\nuser=root\nhost=localhost\npassword=${::mysql::server::root_password}\" > /root/.my.cnf",
      # Only run, if this is not the first node in cluster. Opposite of
      # bootstrap_galera_clusters check. Also do not run if there already is
      # .my.cnf for root.
      unless   => "ret=1; for i in ${server_list}; do nc -z \$i ${wsrep_group_comm_port}; if [ \"\$?\" = \"0\" ]; then ret=0; fi; done; /bin/echo \$ret | /bin/grep 1 -q",
      creates  => '/root/.my.cnf',
      before   => Class['mysql::server::root_password'],
      provider => shell,
      path     => '/usr/bin:/bin:/usr/sbin:/sbin'
    }
  } elsif $ct == 'mha' {
    class{ '::mha::node':}
  }

  exec {'import_common_schema':
    command  => '/usr/bin/mysql --defaults-extra-file=/root/.my.cnf -u root < /var/local/common_schema-2.2.sql',
    unless   => '/usr/bin/mysql --defaults-extra-file=/root/.my.cnf -u root -e "select * from information_schema.schemata where SCHEMA_NAME = \'common_schema\'"|grep -q common_schema',
    provider => shell,
    require  => [Class['mysql::server'], File['common-schema-file']],
    path     => '/usr/bin:/bin:/usr/sbin:/sbin'
  }
}
