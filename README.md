# ramOS: Boot Debian into RAM
This project boots and runs Debian entirely inside RAM. All changes are temporary within memory, users still able to made permanent changes through the `init.sh` and `start.sh` script. This made x86-64 computers act like embedded devices, enabling them to survive sudden power outages or being unplugged at any time without the risk of filesystem corruption. As the successor to [ramfs](https://github.com/danchouzhou/ramfs), ramOS features the following major changes:
- **Build the root filesystem with** `debootstrap`: This allow user to build the boot files with Raspberry Pi, WSL or any Linux environment, instead of physical x86-64 machine or VM
- **Save RAM**: Reduce the file size to 33% of ramfs
- **Gracefully, properly**: Override the mount point and execute `init.sh` via `local-bottom` script
## Clone the project
```
git clone git@github.com:danchouzhou/ramOS.git
```
## Executing shell script
```
cd ramOS
chmod +x mkbootfiles.sh

# Build CLI only
sudo ./mkbootfiles.sh

# To build the Xfce desktop environment
sudo ./mkbootfiles.sh --desktop
```
## Make a boot disk
### For UEFI environment
- Simply copy the `./EFI` directory to a disk formatted with FAT32, and the disk is ready to boot!
### For Legacy BIOS
- Assume that your boot partition is `/dev/sdb1`
- Copy ./EFI to the disk
- Install GRUB (`i386-pc`)
```
sudo mount /dev/sdb1 /mnt
sudo grub-install --target=i386-pc --boot-directory=/mnt/EFI /dev/sdb
sudo umount /mnt
```
## Validation
- A8-7600 / F2A88XM-HD3 / DDR3 16 GB / Secure Boot **PASS**
