# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "4096"]
  end
  config.vm.synced_folder ".", "/vagrant"
  config.vm.provision "shell", inline: <<-SHELL
    curl -sL https://deb.nodesource.com/setup_6.x | bash -
    apt-get update -qq
    apt-get install -qq nodejs unzip gcc libevent-dev libssl-dev --no-install-recommends
  SHELL
end
