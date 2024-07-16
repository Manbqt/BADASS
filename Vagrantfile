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
    pacman -Syu --noconfirm fish docker wireshark-qt xorg-xauth ttf-dejavu xterm unzip bash-completion zip vim terminator
    chsh -s /bin/fish vagrant
    usermod -aG docker vagrant
    usermod -aG wireshark vagrant
    sudo systemctl enable docker.service

    # for yay
    pacman -Syu --noconfirm --needed base-devel git

    # x11 forwarding
    echo "X11Forwarding yes" >> /etc/ssh/sshd_config
    systemctl restart sshd

  SHELL

  config.vm.provision :shell do |shell|
    shell.privileged = true
    shell.inline = 'echo Rebooting for docker...'
    shell.reboot = true
  end

  config.vm.provision "shell", privileged: false, env: {"HOST_USER" => ENV['USER']}, inline: <<-SHELL
    # Set USER_HOST to global
    fish -c "set -Ux HOST_USER $HOST_USER"

    # install yay
    git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm

    # install gns3
    yay -S --noconfirm qemu vpcs dynamips libvirt ubridge inetutils
    yay -S --noconfirm gns3-server gns3-gui

    # import config for gns3 gui
    cp /vagrant/config/gns3_gui.conf /home/vagrant/.config/GNS3/2.2/

    # run gns3server (exposed on host at http://localhost:3080)
    gns3server --daemon --log /tmp/gns3.log

    # build docker images
    docker build -t "host:$HOST_USER" -f /vagrant/p1/Dockerfile.host .
    docker build -t "router:$HOST_USER" -f /vagrant/p1/Dockerfile.router .

    # import templates
    sed "s/user/$HOST_USER/g" /vagrant/p1/router_user.json | \
      curl  -X 'POST' 'http://localhost:3080/v2/templates' \
            -H 'accept: application/json' -H 'Content-Type: application/json' \
            -d "@-"
    sed "s/user/$HOST_USER/g" /vagrant/p1/host_user.json | \
      curl  -X 'POST' 'http://localhost:3080/v2/templates' \
            -H 'accept: application/json' -H 'Content-Type: application/json' \
            -d "@-"

    # import projects
    # p1
    unzip -d /tmp/p1 /vagrant/p1/p1.gns3project
    find /tmp/p1 -type f -exec sed -i -e "s/user/$HOST_USER/g" {} \\;
    cd /tmp/p1/; zip -r /home/vagrant/p1.gns3project *
    curl  -X POST "http://localhost:3080/v2/projects/$(uuidgen)/import?name=p1" \
          --data-binary '@/home/vagrant/p1.gns3project'

    # p2
    unzip -d /tmp/p2 /vagrant/p2/p2.gns3project
    find /tmp/p2 -type f -exec sed -i -e "s/user/$HOST_USER/g" {} \\;
    cd /tmp/p2/; zip -r /home/vagrant/p2.gns3project *
    curl  -X POST "http://localhost:3080/v2/projects/$(uuidgen)/import?name=p2" \
          --data-binary '@/home/vagrant/p2.gns3project'
    # p3
    # unzip -d /tmp/p3 /vagrant/p3/p3.gns3project
    # find /tmp/p3 -type f -exec sed -i -e "s/user/$HOST_USER/g" {} \\;
    # cd /tmp/p3/; zip -r /home/vagrant/p3.gns3project *
    # curl  -X POST "http://localhost:3080/v2/projects/$(uuidgen)/import?name=p3" \
    #       --data-binary '@/home/vagrant/p3.gns3project'
  SHELL
end
