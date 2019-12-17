#!/usr/bin/env bash
set -e

# First, find the most recent .img file, then find the offset.
IMG_PATH="$(ls -lr *.img | head -n 1 | awk '{ print $9 }')"
OFFSET="$(fdisk -l $IMG_PATH | grep img2 | awk '{ print $2 }')"
echo "Initial offset is $OFFSET"
SECTOR_SIZE="$(fdisk -l $IMG_PATH | grep Sector | grep -v Device | awk '{ print $4 }')"
echo "Sector size is $SECTOR_SIZE"
NEW_OFFSET="$(($OFFSET * $SECTOR_SIZE))"
echo "Going to mount $IMG_PATH with offset $NEW_OFFSET"

RAW_PATH="$HOME/rawpi" # This is where the image gets mounted RO
NEW_PATH="$HOME/newpi" # This is the RW directory, it is where the new image gets built from

mkdir -p $RAW_PATH
mkdir -p $NEW_PATH
sudo mount -o loop,offset=$NEW_OFFSET $IMG_PATH $RAW_PATH
sudo tar cf - $RAW_PATH | (cd $NEW_PATH; sudo tar xfp -)
# The filesystem in the iso is now RW at /$HOME/newpi/$HOME/rawpi. Yes, really.
NEW_PATH=$NEW_PATH/home/runner/rawpi

# This is necessary to get the mkisofs command to work at the end
cd $NEW_PATH
sudo mkdir isolinux
ISOLINUX_PATH="$(sudo find / -name isolinux.bin)"
echo "Found isolinux bin at $ISOLINUX_PATH"
sudo cp $ISOLINUX_PATH isolinux

RYNGREDIENTS_PATH="$(sudo find /  -xdev -path '*ryngredients/files')"
echo "Found ryngredients at $RYNGREDIENTS_PATH"

echo "Rsyncing the ryngredients..."
sudo rsync -a $RYNGREDIENTS_PATH/ $NEW_PATH/

cd $RYNGREDIENTS_PATH

echo "Baking the iso now..."
sudo mkisofs -quiet -o $HOME/bakedpi.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Homemade Rhubarb Pie" $NEW_PATH

echo "Baked some pi successfully!"

ISO_PATH="$(sudo find / -name bakedpi.iso -xdev)"
echo "Found the pi at $ISO_PATH"

# This is where GH actions expects it to be for the artifact upload
echo "Copying the iso to where Actions wants it to be..."
cp $ISO_PATH $HOME/work/ryngredients/ryngredients/bakedpi.iso
cd $HOME
echo "Congration we did it."