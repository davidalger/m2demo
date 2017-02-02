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

unless Vagrant.has_plugin? 'vagrant-hostmanager'
  raise "Error: please run `vagrant plugin install vagrant-hostmanager` and try again"
end

Vagrant.require_version '>= 1.7.4'
Vagrant.configure(2) do |conf|
  conf.hostmanager.enabled = true
  conf.hostmanager.manage_host = true
  conf.hostmanager.include_offline = true

  conf.vm.define :m2demo do |conf|
    conf.vm.hostname = CONF_VM_HOSTNAME

    # virtualbox specific configuration
    conf.vm.provider :virtualbox do |provider, conf|
      conf.vm.box = 'bento/centos-6.7'
      conf.vm.network :private_network, ip: '192.168.19.76'

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
      conf.name = 'bootstrap.sh'
      conf.inline = "
        export BOOTSTRAP_LOG=#{bootstrap_log}
        export HOST_ZONEINFO=#{File.readlink('/etc/localtime')}
        export GITHUB_TOKEN=#{GITHUB_TOKEN}
        export MAGENTO_KEY_USER=#{MAGENTO_KEY_USER}
        export MAGENTO_KEY_PASS=#{MAGENTO_KEY_PASS}
        
        /vagrant/lib/bootstrap.sh \
            > >(tee -a #{bootstrap_log} >(stdbuf -oL grep -E '^:: ') > /dev/null) \
           2> >(tee -a #{bootstrap_log} | stdbuf -oL grep -vE -f #{FILTERS_DIR}/bootstrap >&2)
      "
    end

    # magento2 install provisioner
    conf.vm.provision :shell do |conf|
      conf.name = "m2install.sh"
      conf.inline = "
        export DEMO_HOSTNAME=#{CONF_VM_HOSTNAME}
        export IS_ENTERPRISE=#{MAGENTO_IS_ENTERPRISE ? '1' : ''}
        /vagrant/lib/m2install.sh
      "
    end
  end
end
