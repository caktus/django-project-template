Vagrant.require_version ">= 1.8.7"

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.network :private_network, ip: "33.33.33.10"
  config.vm.provider :virtualbox do |vbox|
    vbox.customize ["modifyvm", :id, "--memory", "2048"]
  end
end
