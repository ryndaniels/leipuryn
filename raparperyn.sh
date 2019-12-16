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

mkdir -p $HOME/rawpi
sudo mount -o loop,offset=$NEW_OFFSET $IMG_PATH $HOME/rawpi # it's RO now
mkdir -p $HOME/newpi
sudo tar cf - $HOME/rawpi | (cd $HOME/newpi; sudo tar xfp -)
# The filesystem in the iso is now RW at /$HOME/newpi/rawpi

OLDPATH="$HOME/build/ryndaniels/ryngredients"
NEWPATH="$HOME/newpi/$USER/rawpi"

# This is necessary to get the mkisofs command to work
mkdir -p $NEWPATH
cd $NEWPATH
sudo mkdir isolinux
ISOLINUX_PATH="$(sudo find / -name isolinux.bin)"
echo "Found isolinux bin at $ISOLINUX_PATH"
sudo cp $ISOLINUX_PATH isolinux

# TODO remove this once the real stuff is working
echo "DOING THE FILE STUFF"
echo "talking about cats erryday"
sudo rm ./etc/motd
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

while IFS= read -d $'\0' -r FILE ; do
  if [[ -d $FILE ]]; then
    printf 'Directory found: %s\n' "$FILE"
    NEWDIR=$(echo "$FILE" | sed "s/${OLDPATH}/${NEWPATH}/g")
    printf 'would create new directory: %s\n' "$NEWDIR"
    mkdir -p $NEWDIR
    fix_perms $FILE $NEWDIR
  elif [[ -f $FILE ]]; then
    printf 'File found: %s\n' "$FILE"
    NEWFILE=$(echo "$FILE" | sed "s/${OLDPATH}/${NEWPATH}/g")
    printf 'would copy file from %s to %s\n' "$FILE" "$NEWFILE"
    cp $FILE $NEWFILE
    # need to get owner of old file, otherwise it'll be all root and that's bad
    fix_perms $FILE $NEWFILE
  fi
done < <(find $OLDPATH/* -print0)

echo "Baking the iso now..."
sudo mkisofs -quiet -o $HOME/bakedpi.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Homemade Rhubarb Pie" .

echo "Baked some pi successfully!"
