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

RYNGREDIENTS_PATH="$(sudo find / -name ryngredients | head -n 1)"
echo "Found ryngredients at $RYNGREDIENTS_PATH"

OLD_PATH="$RYNGREDIENTS_PATH"
#NEWPATH="$HOME/newpi/$USER/rawpi"
NEW_PATH="$HOME/newpi"
RAW_PATH="$HOME/rawpi"

#mkdir -p $HOME/rawpi
mkdir -p $RAW_PATH
sudo mount -o loop,offset=$NEW_OFFSET $IMG_PATH $RAW_PATH # it's RO now
mkdir -p $NEW_PATH
sudo tar cf - $RAW_PATH | (cd $NEW_PATH; sudo tar xfp -)
# The filesystem in the iso is now RW at /$HOME/newpi/rawpi - ???

echo "there should be a file system set up now at $NEW_PATH"
ls $NEW_PATH
echo "ok done echoing"

# This is necessary to get the mkisofs command to work
#mkdir -p $NEWPATH
cd $NEWPATH
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

# TODO tomorrow - error happening with the NEWDIR sed command
while IFS= read -d $'\0' -r FILE ; do
  if [[ -d $FILE ]]; then
    printf 'Directory found: %s\n' "$FILE"
    NEW_DIR=$(echo "$FILE" | sed "s/${OLD_PATH}/${NEW_PATH}/g")
    printf 'would create new directory: %s\n' "$NEW_DIR"
    mkdir -p $NEW_DIR
    fix_perms $FILE $NEW_DIR
  elif [[ -f $FILE ]]; then
    printf 'File found: %s\n' "$FILE"
    NEW_FILE=$(echo "$FILE" | sed "s/${OLD_PATH}/${NEW_PATH}/g")
    printf 'would copy file from %s to %s\n' "$FILE" "$NEW_FILE"
    cp $FILE $NEW_FILE
    # need to get owner of old file, otherwise it'll be all root and that's bad
    fix_perms $FILE $NEWFILE
  fi
done < <(find $OLDPATH/* -print0)

echo "Baking the iso now..."
# TODO this should probably be an absolute path
#sudo mkisofs -quiet -o $HOME/bakedpi.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Homemade Rhubarb Pie" .
sudo mkisofs -quiet -o $HOME/bakedpi.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Homemade Rhubarb Pie" $NEW_PATH

echo "Baked some pi successfully!"

ISO_PATH="$(sudo find / -name bakedpi.iso)"
echo "Found the pi at $ISO_PATH"

# This is where GH actions expects it to be for the artifact upload
mv $ISO_PATH $RYNGREDIENTS_PATH/ryngredients/bakedpi.iso
echo "moved the iso"

ISO_PATH="$(sudo find / -name bakedpi.iso)"
echo "Found the pi at $ISO_PATH"