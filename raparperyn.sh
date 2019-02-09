#!/usr/bin/env bash
set -e

# First, find the most recent .img file
IMG_PATH="$(ls -lr *.img | head -n 1 | awk '{ print $9 }')"

OFFSET="$(fdisk -l $IMG_PATH | grep img2 | awk '{ print $2 }')"
SECTOR_SIZE="$(fdisk -l $IMG_PATH | grep Sector | awk '{ print $4 }')"
NEW_OFFSET="$(($OFFSET * $SECTOR_SIZE))"

echo "Going to mount $IMG_PATH with offset $NEW_OFFSET"
mkdir -p /tmp/rawpi
echo "mount -o loop,offset=$NEW_OFFSET $IMG_PATH /tmp/rawpi"
mount -o loop,offset=$NEW_OFFSET $IMG_PATH /tmp/rawpi # it's RO now
mkdir -p /tmp/newpi
tar cf - /tmp/rawpi | (cd /tmp/newpi; sudo tar xfp -)
# the filesystem in the iso is now RW at /tmp/newpi/tmp/rawpi

echo "DOING THE FILE STUFF"
mkdir ./etc
cd /tmp/newpi/tmp/rawpi
echo "cats are amazing" > ./etc/motd
# TODO
# probs gonna have a really bad for loop here

echo "Done with that, baking the iso now"
mkisofs -o $HOME/bakedpi.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Homemade Rhubarb Pie" /tmp/newpi/tmp/rawpi .

echo "did a thing"
file $HOME/bakedpi.iso
