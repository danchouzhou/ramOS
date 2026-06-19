#!/bin/bash

# exit if there is any error
set -e

ARC=amd64
COM=main
DIS=trixie
DIR=./rootfs
URL=http://deb.debian.org/debian

# additional packages
PKG=linux-image-${ARC},initramfs-tools,busybox,zstd,locales,dosfstools,tar # essential stuff
PKG+=,sudo,nftables,openssh-server
PKG+=,network-manager,dbus-broker
PKG+=,htop,screen,nano,wget,bash-completion,eject,mdadm,lvm2,net-tools # basic utils
PKG+=,ntfs-3g,exfat-fuse # file system support

HOSTNAME=debian

rm -rf ${DIR} # remove previous files
mkdir -p ${DIR}

echo "Start debootstrap ..."
debootstrap --arch ${ARC} --components=${COM} --include=${PKG} trixie ${DIR} ${URL}
rm ${DIR}/var/cache/apt/archives/*.deb

echo "Configure hostname ..."
echo "${HOSTNAME}" > ${DIR}/etc/hostname
echo "127.0.1.1 ${HOSTNAME}" >> ${DIR}/etc/hosts

echo "Configure locale ..."
sed -i '/en_US.UTF-8 UTF-8/s/^# //g' ${DIR}/etc/locale.gen
chroot ${DIR} locale-gen
chroot ${DIR} update-locale LANG=en_US.UTF-8

echo "Configure fstab ..."
echo "tmpfs / tmpfs defaults 0 0" > ${DIR}/etc/fstab

echo "Create startup.service ..."
cat << EOF > ${DIR}/etc/systemd/system/startup.service
[Unit]
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "/start.sh && chmod -x /start.sh"

[Install]
WantedBy=multi-user.target
EOF
ln -s ${DIR}/etc/systemd/system/startup.service ${DIR}/etc/systemd/system/multi-user.target.wants/startup.service

echo "Customizing initramfs script ..."
cat << EOF > ${DIR}/etc/initramfs-tools/scripts/local-bottom/mv_root
#!/bin/sh
PREREQ=""
prereqs() {	echo "\$PREREQ"; }
case \$1 in prereqs) prereqs; exit 0;; esac

echo "Moving mount point ..."
mkdir /mnt
mount --move \${rootmnt} /mnt
echo "Mounting tmpfs ..."
mount -t tmpfs tmpfs \${rootmnt}
cd \${rootmnt}
echo "Find and execute init.sh ..."
if test -f /mnt/init.sh; then
	cp /mnt/init.sh .
elif test -f /mnt/EFI/init.sh; then
	cp /mnt/EFI/init.sh .
else
	find /mnt -name init.sh -exec cp {} . \;
fi
chmod +x init.sh
./init.sh
rm init.sh
EOF
chmod +x ${DIR}/etc/initramfs-tools/scripts/local-bottom/mv_root

echo "Adding kernel modules to initramfs ..."
ls ${DIR}/lib/modules/*/kernel/fs/fat/ | cut -f1 -d '.' | tee -a ${DIR}/etc/initramfs-tools/modules
ls ${DIR}/lib/modules/*/kernel/fs/exfat/ | cut -f1 -d '.' | tee -a ${DIR}/etc/initramfs-tools/modules
ls ${DIR}/lib/modules/*/kernel/fs/nls/ | cut -f1 -d '.' | tee -a ${DIR}/etc/initramfs-tools/modules

echo "Adding tar binary to initramfs ..."
cat << EOF > ${DIR}/usr/share/initramfs-tools/hooks/tar
#!/bin/sh
PREREQ=""
prereqs() {	echo "\$PREREQ"; }
case \$1 in prereqs) prereqs; exit 0;; esac

. /usr/share/initramfs-tools/hook-functions
rm -f \${DESTDIR}/bin/tar
copy_exec /usr/bin/tar /bin/tar
EOF
chmod +x ${DIR}/usr/share/initramfs-tools/hooks/tar

echo "Generating initramfs ..."
chroot ${DIR} update-initramfs -u

echo -n "Packing rootfs ..."
rm -f ./EFI/rootfs.tar.gz ./EFI/initrd.img* ./EFI/vmlinuz* # remove previous files
tar zcf ./EFI/rootfs.tar.gz -C ${DIR} . --checkpoint=.5000
echo " done."

echo "Copying boot files ..."
LIN=$(cd ./rootfs/boot/ && ls vmlinuz*)
INIT=$(cd ./rootfs/boot/ && ls initrd.img*)
cp ${DIR}/boot/${LIN} ./EFI/${LIN}
cp ${DIR}/boot/${INIT} ./EFI/${INIT}

echo "Create GRUB boot menu ..."
rm -rf ./EFI/BOOT ./EFI/grub # remove previous files
grub-install --target=x86_64-efi --removable --efi-directory=./ --boot-directory=./EFI --force
cat << EOF > ./EFI/BOOT/grub.cfg
serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
terminal_input console serial
terminal_output console serial
set timeout=5
probe -u \$root --set=boot_uuid
menuentry "Debian" {
	linux	/EFI/${LIN} root=UUID=\$boot_uuid ro console=ttyS0,115200 console=tty0
	initrd	/EFI/${INIT}
}
if [ "\$grub_platform" = "efi" ]; then
menuentry 'UEFI Firmware Settings' {
	fwsetup
}
fi
menuentry "Reboot" {
	reboot
}
menuentry "Shutdown" {
	halt
}
menuentry "Exit GRUB" {
	exit
}
EOF

echo "File size: "
du -sh ${DIR} ./EFI/rootfs.tar.gz ./EFI/${LIN} ./EFI/${INIT}
