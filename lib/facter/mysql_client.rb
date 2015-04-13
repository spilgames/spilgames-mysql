# Check if a package providing mysql-client is already installed.
Facter.add('has_installed_mysql_client') do
    installed_version = Facter::Util::Resolution.exec('rpm -q --whatprovides mysql-client')
    ret_val = ( $?.exitstatus == 0 and ! installed_version.match(/^no package provides/)) ? true : nil
    setcode { ret_val }
end

