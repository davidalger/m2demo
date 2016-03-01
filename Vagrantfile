##
 # Copyright © 2016 by David Alger. All rights reserved
 # 
 # Licensed under the Open Software License 3.0 (OSL-3.0)
 # See included LICENSE file for full text of OSL-3.0
 # 
 # http://davidalger.com/contact/
 ##

require_relative 'etc/config.rb'

Vagrant.require_version '>= 1.7.4'
Vagrant.configure(2) do |conf|
  conf.vm.define :m2demo do |conf|
    conf.vm.box = 'bento/centos-6.7'
    conf.vm.hostname = CONF_VM_HOSTNAME

    conf.vm.provider :digital_ocean do |provider, override|
      provider.token = CONF_DO_TOKEN
      provider.image = 'centos-6-5-x64' # this is really CentOS 6.7 x64
      provider.region = 'nyc2'
      provider.size = '4gb'
      
      if defined? CONF_DO_PK_NAME
        provider.ssh_key_name = CONF_DO_PK_NAME
      end
      if defined? CONF_DO_PK_PATH
        override.ssh.private_key_path = CONF_DO_PK_PATH
      end
      
      provider.backups_enabled = true

      override.vm.box = 'digital_ocean'
      override.vm.box_url = 'https://github.com/smdahlen/vagrant-digitalocean/raw/master/box/digital_ocean.box'
    end

    # configure machine provisioner script
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
      conf.inline = "#{exports}\n/vagrant/lib/bootstrap.sh \
         > >(tee -a #{bootstrap_log} > /dev/null) / \
        2> >(tee -a #{bootstrap_log} | grep -vE -f /vagrant/etc/filters/bootstrap >&2)
      "
    end

    service conf, { start: ['redis', 'mysqld', 'httpd', 'varnish', 'nginx'], reload: ['sshd'] }

    conf.vm.provision :shell do |conf|
      admin_user = 'admin'
      admin_pass = SecureRandom.base64 12

      exports = generate_exports ({
        db_host: 'localhost',
        db_name: 'magento2',
        install_dir: '/var/www/magento2',
        admin_pass: admin_pass
      })
      conf.name = "m2setup.sh"
      conf.inline = "#{exports}\n m2setup.sh -d --hostname=#{CONF_VM_HOSTNAME} --admin-user=#{admin_user}"
    end

    conf.vm.provision :shell do |conf|
      exports = generate_exports ({install_dir: '/var/www/magento2' })
      conf.name = "m2config.sh"
      conf.inline = "#{exports}\n /vagrant/lib/m2config.sh"
    end
  end
end

def service (conf, calls)
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

def generate_exports (env = {})
  exports = ''
  env.each do |key, val|
    exports = %-#{exports}\nexport #{key.upcase}="#{val}";-
  end
  return exports
end
