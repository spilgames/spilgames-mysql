=====

Puppet module to wrap Puppetlabs mysql module for Spil specific things that can
not be accomplished using mysql module.

Not really usable as-is. Best used as inspiration for your own Puppet stuff.

1) Puppetlabs mysql module relies heavily on being configurable through
   automatic class parameter fetching from Hiera. Parameter fetching uses
   'priority' method, so always returns the most specific value. This is a
   problem for us mainly with override_options hash. We don't want to redefine
   every single variable for all of our hosts.
2) We want to make sure some packages and files are installed on all our db
   systems.
3) Support for setting up Galera clusters, without manual intervention
