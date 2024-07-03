Vagrant.configure("2") do |config|
  config.vm.box = "archlinux/archlinux"
  config.vm.network "forwarded_port", guest: 3080, host: 3080, guest_ip: "0.0.0.0"
  config.ssh.forward_agent = true
  config.ssh.forward_x11 = true

  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.cpus = 8
    vb.memory = "8000"
  end

  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    pacman -Syu --noconfirm fish wireshark-cli xorg-xauth docker ttf-dejavu
    chsh -s /bin/fish vagrant
    usermod -ag docker vagrant
    # for yay
    pacman -Syu --noconfirm --needed base-devel git
    # for x11 forwarding
    echo "X11Forwarding yes" >> /etc/ssh/sshd_config
    systemctl restart sshd
    systemctl start docker
  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    # install yay
    git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm
    # install gns3
    yay -S --noconfirm qemu docker vpcs dynamips libvirt ubridge inetutils
    yay -S --noconfirm gns3-server gns3-gui
    # run gns3server (exposed on host at http://localhost:3080)
    gns3server --daemon --log /tmp/gns3.log
  SHELL
end
