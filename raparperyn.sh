#!/usr/bin/env bash

# First, find the most recent .img file
IMG_PATH="$(ls -lr *.img | head -n 1 | awk '{ print $9 }')"

if [[ "$OSTYPE" == "linux-gnu" ]]; then
  OFFSET="$(fdisk -l $IMG_PATH | grep img2 | awk '{ print $2 }')"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OFFSET="$(fdisk $IMG_PATH | grep files | awk '{ print $11 }')"
fi

mkdir -p /tmp/rawpi
mount -o loop,offset=$OFFSET raw_pi_dough.img /tmp/rawpi # it's RO now
mkdir -p /tmp/newpi
tar cf - /tmp/rawpi | (cd /tmp/newpi; sudo tar xfp -)
# the filesystem in the iso is now RW at /tmp/newpi/tmp/rawpi

echo "DOING THE FILE STUFF"
cd /tmp/newpi/tmp/rawpi
cat "cats are amazing" > ./etc/motd
# TODO
# probs gonna have a really bad for loop here

echo "Done with that, baking the iso now"
mkisofs -o $HOME/bakedpi.iso -b isolinux/isolinux.bin -c isolinux/boot.cat
-no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Homemade Rhubarb Pie" /tmp/newpi/tmp/rawpi
