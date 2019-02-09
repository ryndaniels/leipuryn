#!/usr/bin/env bash
set -e

# First, find the most recent .img file, then find the offset.
IMG_PATH="$(ls -lr *.img | head -n 1 | awk '{ print $9 }')"
OFFSET="$(fdisk -l $IMG_PATH | grep img2 | awk '{ print $2 }')"
SECTOR_SIZE="$(fdisk -l $IMG_PATH | grep Sector | awk '{ print $4 }')"
NEW_OFFSET="$(($OFFSET * $SECTOR_SIZE))"

echo "Going to mount $IMG_PATH with offset $NEW_OFFSET"
mkdir -p $HOME/rawpi
mount -o loop,offset=$NEW_OFFSET $IMG_PATH $HOME/rawpi # it's RO now
mkdir -p $HOME/newpi
sudo tar cf - $HOME/rawpi | (cd $HOME/newpi; sudo tar xfp -)
# the filesystem in the iso is now RW at /$HOME/newpi/rawpi
# it is also all owned by root. it is unclear if it was that way in the img or if that's an artifact of having to be root to mount it.

echo "DOING THE FILE STUFF"
cd $HOME/newpi/home/travis/rawpi
sudo mkdir isolinux
echo "copying the isolinux file"
sudo cp /usr/lib/syslinux/isolinux.bin isolinux
echo "talking about cats erryday"
sudo rm ./etc/motd
sudo echo "cats are amazing" > ./etc/motd

# TODO - the real files
echo "ls the real shit"
ls $HOME
# probs gonna have a really bad for loop here

echo "doing me an ls"
ls -al | head -n 3
echo "Done with that, baking the iso now"
sudo mkisofs -o $HOME/bakedpi.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Homemade Rhubarb Pie" .

echo "did a thing"
file $HOME/bakedpi.iso
