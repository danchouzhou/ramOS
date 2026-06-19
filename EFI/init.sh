#!/bin/sh

echo "Copying rootfs.tar.gz ..."
cp /mnt/EFI/rootfs.tar.gz .
echo "Copying start.sh ..."
cp /mnt/EFI/start.sh .
chmod +x start.sh
echo "Unmount boot device ..."
umount /mnt
echo -n "Extracting from rootfs.tar.gz ..."
tar zxf rootfs.tar.gz --checkpoint=.5000
echo " done."
rm rootfs.tar.gz
