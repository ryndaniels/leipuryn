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

# This is necessary to get the mkisofs command to work
cd $HOME/newpi/home/travis/rawpi
sudo mkdir isolinux
sudo cp /usr/lib/syslinux/isolinux.bin isolinux

echo "DOING THE FILE STUFF"
echo "talking about cats erryday"
sudo rm ./etc/motd
sudo echo "cats are amazing" > ./etc/motd

# TODO - the real files
echo "WHEE"
pwd
echo "YEY"
sudo find / -name ryngredients
# probs gonna have a really bad for loop here

echo "Baking the iso now..."
sudo mkisofs -quiet -o $HOME/bakedpi.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Homemade Rhubarb Pie" .

echo "did a thing"
file $HOME/bakedpi.iso
