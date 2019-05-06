# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV["LC_ALL"] = "en_US.UTF-8"

Vagrant.configure(2) do |config|
  config.vm.box = "debian/contrib-stretch64"

  config.vm.define "debian", primary: true do |debian|
    debian.vm.hostname = "debian"
    debian.vm.provision :shell, inline: "apt-get install --yes python"
    debian.vm.provision :ansible do |ansible|
      ansible.playbook = "mailserver.yml"
      ansible.extra_vars = { vagrant: true }
      ansible.compatibility_mode = "2.0"
    end
  end
end
