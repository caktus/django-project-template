Vagrant.configure("2") do |config|
    # Every Vagrant virtual environment requires a box to build off of.
    config.vm.box = "precise32"
    config.vm.box_url = "http://files.vagrantup.com/precise32.box"
    config.vm.network :forwarded_port, guest: 80, host: 8090
    config.vm.network :forwarded_port, guest: 443, host: 8089
    config.vm.network :private_network, ip: "33.33.33.10"
end
