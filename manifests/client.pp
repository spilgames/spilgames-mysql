# == Class: spil_mysql
#
# Class to wrap mysql::client.
#
# === Parameters
#
# [*no_install*]
#
# If true, do nothing. Boolean. Default is from hiera mysql::client::no_install or
# false if undefined.
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

class spil_mysql::client (
  $no_install = hiera('mysql::client::no_install', false)
){
  if ! $no_install {
    # Ugly, secret check to cope with the fact, that Percona mysql packages can
    # not handle automatically upgrading from 51 to 55.
    if ! $::has_installed_mysql_client {
      include ::mysql::client
    }
  } else {
      notify{'No_install specified. Skipping install of mysql::client.': }
  }

}
