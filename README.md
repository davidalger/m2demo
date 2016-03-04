# Vagrant Magento 2 Demo

A complete demo environment powered by Vagrant using either Digital Ocean or Virtual Box as a provider.

## The Stack
This builds a virtual machine running Cent OS 6.7, MySql 5.6, PHP 7.0, Nginx 1.8, Apache 2.2 and Varnish 4.1 and installs Magento 2.0 complete with sample data. By default, Community Edition is installed, but this can be changed to install Enterprise Edition in the config.rb file for those who have access.

## Requirements

* Vagrant 1.7.4 or higher ([installation instructions](https://www.vagrantup.com/docs/installation/))
* Virtual Box (if used as provider)
* Digital Ocean API access (if used as provider)
* Magento Marketplace [access credentials](http://devdocs.magento.com/guides/v2.0/install-gde/prereq/connect-auth.html#auth-get)

## Installation / Usage

1. Verify you have all the required dependencies as listed above
2. Clone this repository
3. Copy the `etc/config.rb.sample` file to `etc/config.rb` and update the placeholder values (values may be left unchanged for providers you do not plan on utilizing)
4. If you have Enterprise Edition access, set `MAGENTO_IS_ENTERPRISE` to `true` in `etc/config.rb`
4. Run `vagrant up` to kick off virtual machine provisioning and install Magento 2. By default, Virtual Box is used as a provider. To use Digital Ocean, run `vagrant up --provider digital_ocean` instead
5. Add an entry to your `/etc/hosts` file using the IP address and hostname output near end of `vagrant up` run
6. Load up your new demo site in a browser!

## Known Issues

* There is currently no support for SSL, but it's configured in the Magento 2 installation limiting access to the admin.
