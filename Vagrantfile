Vagrant.configure("2") do |config|
  config.vm.box = "archlinux/archlinux"
  config.vm.network "forwarded_port", guest: 3080, host: 3080, guest_ip: "0.0.0.0"

  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.cpus = 8
    vb.memory = "8000"
  end

  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    pacman -Syu --noconfirm fish wireshark-cli
    chsh -s /bin/fish vagrant
    # for yay
    pacman -Syu --noconfirm --needed base-devel git
  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    # install yay
    git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm
    # install gns3
    yay -S --noconfirm qemu docker vpcs dynamips libvirt ubridge inetutils
    yay -S --noconfirm gns3-server gns3-gui
    gns3server &
  SHELL
end
