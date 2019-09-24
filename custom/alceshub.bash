set -x

curl -s https://raw.githubusercontent.com/alces-software/flight-appliance-menu/dev/vpn/support/build/appliance_chroot.sh | bash -sex dev/vpn

curl -s https://raw.githubusercontent.com/RuanEllis/wip/master/flight-gui.sh | bash -ex
