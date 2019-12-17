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


#NEW_PATH="$HOME/newpi" # This is the RW directory, it is where the new image gets built from
NEW_PATH="$HOME/newpi$HOME/rawpi" # This is the RW directory, it is where the new image gets built from
RAW_PATH="$HOME/rawpi" # This is where the image gets mounted RO

mkdir -p $RAW_PATH
mkdir -p $NEW_PATH
sudo mount -o loop,offset=$NEW_OFFSET $IMG_PATH $RAW_PATH
sudo tar cf - $RAW_PATH | (cd $NEW_PATH; sudo tar xfp -)
# The filesystem in the iso is now RW at /$HOME/newpi/$HOMErawpi - ??? no but where actually is this


# This is necessary to get the mkisofs command to work at the end
cd $NEW_PATH
sudo mkdir isolinux
ISOLINUX_PATH="$(sudo find / -name isolinux.bin)"
echo "Found isolinux bin at $ISOLINUX_PATH"
sudo cp $ISOLINUX_PATH isolinux

# TODO remove this once the real stuff is working
echo "DOING THE FILE STUFF"
echo "talking about cats erryday"
if test -f ./etc/motd; then
  sudo rm ./etc/motd
fi
mkdir -p ./etc
sudo echo "cats are amazing" > ./etc/motd

# Copy all the files from ryngredients
# TODO this hasn't been tested yet because of Computers
function fix_perms {
  printf 'would fix perms of %s to match %s\n' "$2" "$1"
  # old file is $1, new file is $2
  OWNER=$(stat -c '%U' $1)
  GROUP=$(stat -c '%G' $1)
  PERMS=$(stat -c '%a' $1)
  printf 'new file %s should have owner %s group %s perms %s\n' "$2" "$OWNER" "$GROUP" "$PERMS"
  chown $OWNER:$GROUP $2
  chmod $PERMS $2
}

# this needs to be done *from* the rawpi directory?
# this currently finds /home/runner/work/ryngredients/ryngredients. which is *not* in rawpath?
# and that's fine but it needs to go *into* ryngredients
RYNGREDIENTS_PATH="$(sudo find / -name ryngredients -xdev | head -n 1)"
echo "Found ryngredients at $RYNGREDIENTS_PATH"
cd $RYNGREDIENTS_PATH/ryngredients
while IFS= read -d $'\0' -r FILE ; do
  if [[ -d $FILE ]]; then
    printf 'Directory found: %s\n' "$FILE"
    NEW_DIR=$(echo "$FILE" | sed "s@${RYNGREDIENTS_PATH}@${NEW_PATH}@g")
    printf 'would create new directory: %s\n' "$NEW_DIR"
    mkdir -p $NEW_DIR
    fix_perms $FILE $NEW_DIR
  elif [[ -f $FILE ]]; then
    printf 'File found: %s\n' "$FILE"
    NEW_FILE=$(echo "$FILE" | sed "s@${RYNGREDIENTS_PATH}@${NEW_PATH}@g")
    printf 'would copy file from %s to %s\n' "$FILE" "$NEW_FILE"
    cp $FILE $NEW_FILE
    # need to get owner of old file, otherwise it'll be all root and that's bad
    fix_perms $FILE $NEW_FILE
  fi
done < <(find $RYNGREDIENTS_PATH/* -print0)

echo "Baking the iso now..."
sudo mkisofs -quiet -o $HOME/bakedpi.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Homemade Rhubarb Pie" $NEW_PATH

echo "Baked some pi successfully!"

ISO_PATH="$(sudo find / -name bakedpi.iso -xdev)"
echo "Found the pi at $ISO_PATH"

# This is where GH actions expects it to be for the artifact upload
mv $ISO_PATH $RYNGREDIENTS_PATH/ryngredients/bakedpi.iso
echo "moved the iso"

ISO_PATH="$(sudo find / -name bakedpi.iso -xdev)"
echo "Found the pi at $ISO_PATH"