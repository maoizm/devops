#!/bin/sh -eux

#
# common/metadata section
#

mkdir -p /etc;
cp /tmp/$METADATA /etc/$METADATA;
chmod 0444 /etc/$METADATA;
rm -f /tmp/$METADATA;


#
# ubuntu/update section
#

ubuntu_version="`lsb_release -r | awk '{print $2}'`";
ubuntu_major_version="`echo $ubuntu_version | awk -F. '{print $1}'`";

# Update the package list
apt-get update;

# Upgrade all installed packages incl. kernel and kernel headers
apt-get -y upgrade linux-generic;

# ensure the correct kernel headers are installed
apt-get -y install linux-headers-`uname -r`;

# update package index on boot
cat <<EOF >/etc/init/refresh-apt.conf;
description "update package index"
start on networking
task
exec /usr/bin/apt-get update
EOF


#
# common/sshd section
#

SSHD_CONFIG="/etc/ssh/sshd_config"

# ensure that there is a trailing newline before attempting to concatenate
sed -i -e '$a\' "$SSHD_CONFIG"

USEDNS="UseDNS no"
if grep -q -E "^[[:space:]]*UseDNS" "$SSHD_CONFIG"; then
    sed -i "s/^\s*UseDNS.*/${USEDNS}/" "$SSHD_CONFIG"
else
    echo "$USEDNS" >>"$SSHD_CONFIG"
fi

GSSAPI="GSSAPIAuthentication no"
if grep -q -E "^[[:space:]]*GSSAPIAuthentication" "$SSHD_CONFIG"; then
    sed -i "s/^\s*GSSAPIAuthentication.*/${GSSAPI}/" "$SSHD_CONFIG"
else
    echo "$GSSAPI" >>"$SSHD_CONFIG"
fi


#
# ubuntu/networking section
#

# Disable automatic udev rules for network interfaces in Ubuntu,
# source: http://6.ptmc.org/164/
rm -f /etc/udev/rules.d/70-persistent-net.rules;
mkdir -p /etc/udev/rules.d/70-persistent-net.rules;
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules;
rm -rf /dev/.udev/ /var/lib/dhcp3/* /var/lib/dhcp/*;

# Adding a 2 sec delay to the interface up, to make the dhclient happy
echo "pre-up sleep 2" >>/etc/network/interfaces;


#
# ubuntu/sudoers section
#

sed -i -e '/Defaults\s\+env_reset/a Defaults\texempt_group=sudo' /etc/sudoers;
sed -i -e 's/%sudo\s*ALL=(ALL:ALL) ALL/%sudo\tALL=(ALL) NOPASSWD:ALL/g' /etc/sudoers;


#
# ubuntu/vagrant section
#

pubkey_url="https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub";
mkdir -p $HOME_DIR/.ssh;
if command -v wget >/dev/null 2>&1; then
    wget --no-check-certificate "$pubkey_url" -O $HOME_DIR/.ssh/authorized_keys;
elif command -v curl >/dev/null 2>&1; then
    curl --insecure --location "$pubkey_url" > $HOME_DIR/.ssh/authorized_keys;
else
    echo "Cannot download vagrant public key";
    exit 1;
fi
chown -R vagrant $HOME_DIR/.ssh;
chmod -R go-rwsx $HOME_DIR/.ssh;


#
# common/vmtools section
#

# set a default HOME_DIR environment variable if not set
HOME_DIR="${HOME_DIR:-/home/vagrant}";

case "$PACKER_BUILDER_TYPE" in

virtualbox-iso|virtualbox-ovf)
    mkdir -p /tmp/vbox;
    ver="`cat /home/vagrant/.vbox_version`";
    mount -o loop $HOME_DIR/VBoxGuestAdditions_${ver}.iso /tmp/vbox;
    sh /tmp/vbox/VBoxLinuxAdditions.run \
        || echo "VBoxLinuxAdditions.run exited $? and is suppressed." \
            "For more read https://www.virtualbox.org/ticket/12479";
    umount /tmp/vbox;
    rm -rf /tmp/vbox;
    rm -f $HOME_DIR/*.iso;
    ;;

vmware-iso|vmware-vmx)
    mkdir -p /tmp/vmfusion;
    mkdir -p /tmp/vmfusion-archive;
    mount -o loop $HOME_DIR/linux.iso /tmp/vmfusion;
    tar xzf /tmp/vmfusion/VMwareTools-*.tar.gz -C /tmp/vmfusion-archive;
    /tmp/vmfusion-archive/vmware-tools-distrib/vmware-install.pl --force-install;
    umount /tmp/vmfusion;
    rm -rf  /tmp/vmfusion;
    rm -rf  /tmp/vmfusion-archive;
    rm -f $HOME_DIR/*.iso;
    ;;

*)
    echo "Unknown Packer Builder Type >>$PACKER_BUILDER_TYPE<< selected.";
    echo "Known are virtualbox-iso|virtualbox-ovf|vmware-iso|vmware-vmx|parallels-iso|parallels-pvm.";
    ;;

esac


#
# ubuntu/cleanup section
#

# Delete all Linux headers
dpkg --list \
  | awk '{ print $2 }' \
  | grep 'linux-headers' \
  | xargs apt-get -y purge;

# Remove specific Linux kernels, such as linux-image-3.11.0-15-generic but
# keeps the current kernel and does not touch the virtual packages,
# e.g. 'linux-image-generic', etc.
dpkg --list \
    | awk '{ print $2 }' \
    | grep 'linux-image-3.*-generic' \
    | grep -v `uname -r` \
    | xargs apt-get -y purge;

# Delete Linux source
dpkg --list \
    | awk '{ print $2 }' \
    | grep linux-source \
    | xargs apt-get -y purge;

# Delete development packages
dpkg --list \
    | awk '{ print $2 }' \
    | grep -- '-dev$' \
    | xargs apt-get -y purge;

# Delete X11 libraries
apt-get -y purge libx11-data xauth libxmuu1 libxcb1 libx11-6 libxext6;

# Delete obsolete networking
apt-get -y purge ppp pppconfig pppoeconf;

# Delete oddities
apt-get -y purge popularity-contest;

apt-get -y autoremove;
apt-get -y clean;

rm -f VBoxGuestAdditions_*.iso VBoxGuestAdditions_*.iso.?;
