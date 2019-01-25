#Sometimes you need to clone one Linux system to many physical disks. This script solves exactly that problem. This is very old one, found it pretty entangled nowadays, but let this will be example of not so good code.

#!/bin/bash

MOUNTDIR_ROOT="/tmp/root"
MOUNTDIR_HOME="/tmp/home"
SOURCE_ROOT="/home/dmitry/manager/root" #source folder (root)
SOURCE_HOME="/home/dmitry/manager/home" #source folder (home)

fun_parted () {
        echo DESTINATION:"$arg"
        DESTINATION=/dev/"$arg"
        parted "$DESTINATION" mktable msdos y || exit 1 #make new partitions:
        enddisk=`parted "$DESTINATION" unit s print free | awk '{print $2}' | grep -E -o "[0-9]{9,}"` # last sector
        parted "$DESTINATION" unit s mkpart primary 2048 40962047 print free || exit 2 #root partition 20 GB
        parted "$DESTINATION" unit s mkpart primary 40962048 45058047 print free || exit 3 #swap partition 2 GB
        parted "$DESTINATION" unit s mkpart primary 45058048 "$enddisk" print free || exit 4 #home partition entire free space
}

fun_mkfs () {
        mkfs.ext4 -F "$DESTINATION"1 || exit 5 #formatting
        mkfs.ext4 -F "$DESTINATION"3 || exit 6
        mkswap "$DESTINATION"2 || exit 7 #swap added    
}

fun_mnt_copy () {
        if ! [ -d "$MOUNTDIR_ROOT" ]; then
                mkdir "$MOUNTDIR_ROOT" || exit 8
        fi
        if ! [ -d "$MOUNTDIR_HOME" ]; then
                mkdir "$MOUNTDIR_HOME" || exit 9
        fi
        mount $DESTINATION"1" "$MOUNTDIR_ROOT" #mount target device
        mount $DESTINATION"3" "$MOUNTDIR_HOME"
        cp -a -R "$SOURCE_ROOT"/* "$MOUNTDIR_ROOT" && cp -a -R "$SOURCE_HOME"/* "$MOUNTDIR_HOME" #copy
}

fun_chroot_prepare () {
        mount --bind /sys "$MOUNTDIR_ROOT"/sys
        mount --bind /proc "$MOUNTDIR_ROOT"/proc
        mount --bind /dev "$MOUNTDIR_ROOT"/dev
}

fun_chroot () { #script for grub
        echo '#!/bin/bash
        targ1=`mount | grep -E -o "/dev/sd[a-f]" | sed q`
        grub-install "$targ1" 
        update-grub
        file="/boot/grub/grub.cfg"
        sed -e "s/timeout=30\|timeout=10/timeout=0/" $file > /tmp/grb
        cat /tmp/grb > "$file"
        exit' > "$MOUNTDIR_ROOT"/root/grubless.sh

        chroot "$MOUNTDIR_ROOT" /root/grubless.sh #external script!
        rm "$MOUNTDIR_ROOT"/root/grubless.sh
}

fun_prepare () {
        hos=`echo "$user1" | cut -d"." -f1` #hostname modification
        tname=`echo "$user1" | cut -d"." -f2`
        cat "$MOUNTDIR_ROOT"/etc/hostname | sed -e "s/manager/$hos"-"$tname/" > /tmp/hostn
        cat /tmp/hostn > "$MOUNTDIR_ROOT"/etc/hostname
        echo "$user1" > "$MOUNTDIR_ROOT"/tmp/name1
        echo "$pasw" > "$MOUNTDIR_ROOT"/tmp/pasw #external files attention!(see grubinstall.sh)
}

fun_chroot_useradd () { #script for grub and useradd
        echo '#!/bin/bash
        targ1=`mount | grep -E -o "/dev/sd[a-f]" | sed q`
        grub-install "$targ1"
        update-grub
        file="/boot/grub/grub.cfg"
        sed -e "s/timeout=30\|timeout=10/timeout=0/" $file > /tmp/grb
        cat /tmp/grb > "$file"
        disk=`mount | grep -E -o sd[a-f] | sed q`
        mount /dev/"$disk"3 /home
        user2=`cat /tmp/name1`
        useradd -m -G lpadmin -s /bin/bash "$user2"
        pasw1=`cat /tmp/pasw`
        echo "$user2:$pasw1" | chpasswd
        umount /home
        exit' > "$MOUNTDIR_ROOT"/root/grubinstall.sh
        chroot "$MOUNTDIR_ROOT" /root/grubinstall.sh #xternal script
        rm "$MOUNTDIR_ROOT"/root/grubinstall.sh
        cat "$MOUNTDIR_HOME"/"$user1"/.purple/accounts.xml | sed -e "s/user1/$user1/" | sed -e "s/pasw/$pasw/" | sed -e "s/cyrname/$cyrname/" > /tmp/acc.xml #hook for pidgin 
        cat /tmp/acc.xml > "$MOUNTDIR_HOME"/"$user1"/.purple/accounts.xml
}

fun_umount () {
        umount "$MOUNTDIR_ROOT"/dev
        umount "$MOUNTDIR_ROOT"/proc
        umount "$MOUNTDIR_ROOT"/sys
        umount "$MOUNTDIR_ROOT"
        umount "$MOUNTDIR_HOME"
}

fun_shrink_all () {
        list=`lsblk | grep -E -o "sd[a-f]\>"` #list of all disks
        for arg in "$list"
                do
        target1=`mount | grep -E -o "$arg" | sed q` #mount check
        if [ -z "$target1" ]; then
                echo "$arg not_mounted"
                fun_parted
                fun_mkfs
                fun_mnt_copy
                fun_chroot_prepare
                fun_chroot
                fun_umount
        else
                echo "$arg mounted"
        fi
        done
}

fun_ask1 () {
        echo "This will erase all data on unmounted disks! Are you sure?[y/n](y)"
        read -n 1 B

        case "$B" in

        ""|"y"|"Y" )
        echo "start"
        fun_shrink_all
        ;;

        "n"|"N" )
        echo "stopped"
        exit 0
        ;;

        * )
        echo "enter "y" or "n", please"
        exit 1
        ;;

        esac
}

echo "do you want to copy [O]ne hdd or [A]ll hdds?(O/A)"
read -n 1 A

case "$A" in
"a"|"A" )
echo "starting..."
fun_ask1
;;

"o"|"O" )
lsblk
echo 'enter device name like "sda" '
read arg
echo "enter username like s.user"
read user1
echo "enter cyrillic username"
read cyrname
num=`echo -n "$cyrname" | cut -d" " -f2 | wc -m` #password calculation
num=$[$num-1]
pasw="Password $num"
echo "$pasw" "$cyrname"
        fun_parted
        fun_mkfs
        fun_mnt_copy
        fun_chroot_prepare
        fun_prepare
        fun_chroot_useradd
        fun_umount
;;

* )
echo "error"
exit 1
;;

esac

echo "finished!"
