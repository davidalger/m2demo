##
 # Copyright © 2016 by David Alger. All rights reserved
 # 
 # Licensed under the Open Software License 3.0 (OSL-3.0)
 # See included LICENSE file for full text of OSL-3.0
 # 
 # http://davidalger.com/contact/
 ##

CACHE_ROOT = File.dirname(__FILE__) + '/.cache'
FILTERS_DIR = '/vagrant/etc/filters'

require_relative 'etc/config.rb'

Vagrant.require_version '>= 1.7.4'
Vagrant.configure(2) do |conf|
  conf.vm.define :m2demo do |conf|
    conf.vm.hostname = CONF_VM_HOSTNAME

    # virtualbox specific configuration
    conf.vm.provider :virtualbox do |provider, conf|
      conf.vm.box = 'bento/centos-6.7'
      conf.vm.network :private_network, type: 'dhcp'

      provider.memory = 4096
      provider.cpus = 2
      
      FileUtils.mkdir_p CACHE_ROOT + '/composer'
      conf.vm.synced_folder CACHE_ROOT + '/composer', '/var/cache/composer'

      FileUtils.mkdir_p CACHE_ROOT + '/yum'
      conf.vm.synced_folder CACHE_ROOT + '/yum', '/var/cache/yum'

      FileUtils.mkdir_p CACHE_ROOT + '/npm'
      conf.vm.synced_folder CACHE_ROOT + '/npm', '/var/cache/npm'
    end

    # digital ocean specific configuration
    conf.vm.provider :digital_ocean do |provider, conf|
      provider.token = CONF_DO_TOKEN
      provider.image = 'centos-6-5-x64' # this is really CentOS 6.7 x64
      provider.region = 'nyc2'
      provider.size = '4gb'
      provider.backups_enabled = true

      if defined? CONF_DO_PK_NAME
        provider.ssh_key_name = CONF_DO_PK_NAME
      end
      if defined? CONF_DO_PK_PATH
        conf.ssh.private_key_path = CONF_DO_PK_PATH
      end

      conf.vm.box = 'digital_ocean'
      conf.vm.box_url = 'https://github.com/smdahlen/vagrant-digitalocean/raw/master/box/digital_ocean.box'
    end

    # generic node configuration
    conf.ssh.forward_agent = false
    conf.vm.synced_folder '.', '/vagrant', type: 'rsync', rsync__exclude: '.cache/'

    # primary node provisioner
    conf.vm.provision :shell do |conf|
      bootstrap_log = '/var/log/bootstrap.log'
      exports = generate_exports ({
        bootstrap_log: bootstrap_log,
        host_zoneinfo: File.readlink('/etc/localtime'),
        github_token: GITHUB_TOKEN,
        magento_key_user: MAGENTO_KEY_USER,
        magento_key_pass: MAGENTO_KEY_PASS
      })

      conf.name = 'bootstrap.sh'
      conf.inline = "#{exports}\n /vagrant/lib/bootstrap.sh \
         > >(tee -a #{bootstrap_log} >(stdbuf -oL grep -E '^:: ') > /dev/null) \
        2> >(tee -a #{bootstrap_log} | stdbuf -oL grep -vE -f #{FILTERS_DIR}/bootstrap >&2)
      "
    end

    # service state provisioner
    service conf, { start: ['redis', 'mysqld', 'httpd', 'varnish', 'nginx'], reload: ['sshd'] }

    # magento2 install provisioner
    conf.vm.provision :shell do |conf|
      exports = generate_exports ({
        demo_hostname: CONF_VM_HOSTNAME,
        is_enterprise: MAGENTO_IS_ENTERPRISE ? '1' : ''
      })
      conf.name = "m2install.sh"
      conf.inline = "#{exports}\n /vagrant/lib/m2install.sh"
    end
    
    # always output guest machine information on load
    conf.vm.provision :shell, run: 'always' do |conf|
      conf.name = "vm-info"
      conf.inline = "
        # use info from eth1 if available, otherwise eth0
        interface=$(ifconfig eth1 | grep 'inet addr' > /dev/null 2>&1 && echo eth1 || echo eth0)
        ip_address=$(ifconfig $interface | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}')
        printf 'ip address: %s\nhostname: %s\n' \"$ip_address\" \"$(hostname)\"
      "
    end
  end
end

def service conf, calls
  service_sh = ""
  calls.each do | key, val |
    val.each do | val |
      service_sh = "#{service_sh}\nservice #{val} #{key}"
    end
  end

  conf.vm.provision :shell, run: 'always' do |conf|
    conf.name = "service_sh"
    conf.inline = service_sh
  end
end

def generate_exports env = {}
  exports = ''
  env.each do |key, val|
    exports = %-#{exports}\nexport #{key.upcase}="#{val}";-
  end
  return exports
end
