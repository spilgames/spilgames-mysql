# == Class: spil_mysql::install
#
# Class to manage MySQL related packages directories.
#
# Creates MySQL directories including creating physical volumes, volume groups,
# logical volumes filesystem and mounts. For the actual server install see
# spil_mysql::server.
#
# === Parameters
#
# [*mysql_config_file*]
#
# Path to mysql config file.
#
# [*volume_group*]
#
# Name of the volume group to create for the disk containing mysql data dir.
# String. E.g. vg_0
#
# [*physical_volumes*]
#
# Paths to physical volumes underlying volume group. Array. E.g. [/dev/vdb]
#
# [*logical_volumes*]
#
# List of logical volumes to create on top of the volume group. Hash. E.g.
# lv_mysql
#   volume_group: vg_0
#   size: 5G
#   mountpath: /mnt/data
#
# [*mount_point*]
#
# Mount point for file system containing mysql datadirectory. Must be a
# mountpath from one of the logical volume definitions. String. E.g. Seggin
# $mount_point to /mnt/data will cause the actual mysql data directory to be
# /mnt/data/mysql.
#
# [*one_disk_install*]
#
# If set to true, installation does not require the host to have an extra
# volume to be attached for mysql datadir.
#
## === Authors
#
# Jaakko Pesonen <jaakko.pesonen@spilgames.com>
#
# === Copyright
#
# Copyright 2014 Spilgames


class spil_mysql::server::install (
  $mysql_config_file  = $spil_mysql::params::config_file,
  $volume_group       = $spil_mysql::params::volume_group,
  $physical_volumes   = $spil_mysql::params::physical_volumes,
  $logical_volumes    = $spil_mysql::params::logical_volumes,
  $mount_point        = $spil_mysql::params::mount_point,
  $one_disk_install   = $spil_mysql::params::one_disk_install,
  )inherits ::spil_mysql::params{

  package{['percona-xtrabackup', 'sharutils', 'nc', 'mysqlsla', 'mysqlreport']:
    ensure => installed,
  }

  package{'percona-toolkit':
    # Later versions of Percona toolkit do not have visual explain
    # functionality needed by Anemometer.
    ensure => '2.1.10-1'
  }

  # MySQL admin tools, utilities and miscellaneous scripts.
  #
  file{'mysql_purge':
    path    => '/opt/admin/scripts/mysql_purge',
    owner   => 'root',
    group   => 'admin',
    mode    => '0750',
    content => template("${module_name}/mysql_purge.erb")
  }

  group{'mysql':
    ensure => present,
    system => true
  }

  user{'mysql':
    ensure  => present,
    gid     => 'mysql',
    system  => true,
    require => Group['mysql']
  }

  # Do pv, vg, lv, fs creation and mount only if we actually have second volume
  # attached.
  if ! $one_disk_install {

    if inline_template('<%= bds = @blockdevices.split(",").map{ |bd| "/dev/" + bd }; @physical_volumes.all?{ |pv| bds.member?(pv) } ? "true" : "false" %>') != 'true' {
        $pv_str = join($physical_volumes, ',')
        fail("\$physical_volumes parameter (${pv_str}) contains a volume, that does not exist on host. Host has these volumes: ${::blockdevices}.")
    }

    package { 'lvm2':
      ensure => 'installed',
    }

    physical_volume { $physical_volumes:
      ensure    => present,
      unless_vg => $volume_group
    }

    volume_group { $volume_group:
      ensure           => present,
      physical_volumes => $physical_volumes,
      createonly       => true
    }

    Physical_volume[$physical_volumes] -> Volume_group[$volume_group]

    $lvs_defaults = {
      ensure => present,
      tag    => 'mysql_lvm'
    }
    create_resources(lvm::logical_volume, $logical_volumes, $lvs_defaults)

    Volume_group[$volume_group] -> Lvm::Logical_volume<|tag == 'mysql_lvm'|>

    $real_mysql_dir = "${mount_point}/mysql"

    file{$real_mysql_dir:
      ensure  => directory,
      owner   => 'mysql',
      group   => 'mysql',
      mode    => '0775',
      replace => false,
      require => User['mysql']
    }

    Lvm::Logical_volume<|tag == 'mysql_lvm'|> -> File[$real_mysql_dir]

    file{'/var/lib/mysql':
      ensure  => link,
      target  => $real_mysql_dir,
      owner   => 'mysql',
      group   => 'mysql',
      replace => false,
      require => File[$real_mysql_dir]
    }
  }

  # Common schema
  file{'common-schema-file':
    ensure => file,
    path   => '/var/local/common_schema-2.2.sql',
    owner  => 'root',
    group  => 'admin',
    mode   => '0644',
    source => "puppet:///modules/${module_name}/common_schema-2.2.sql",
  }
}
