#!/usr/bin/env bash

#===============================================================================#
# Здесь устанавливаются параметры передаваемые скрипту #
#===============================================================================#

HDD="/dev/sda"
BOOT_SIZE="100"
SWAP_SIZE="4096"
ROOT_SIZE="32768"

HOST="arch"
readonly TIMEZONE="Europe/Moscow"

ROOT_PASSWD="rootpasswd"
MY_USER="linux"
MY_USER_PASSWD="userpasswd"

#===============================================================================
# Список пакетов #
#===============================================================================
readonly PKG_EXTRA=(
    "netctl" 
    "dialog" 
    "wpa_supplicant"
    "rp-pppoe")
readonly DISPLAY_SERVER=(
    "xf86-video-vesa"
    "bash-completion" 
    "xdg-user-dirs" 
    "telegram-desktop" 
    "p7zip" 
    "zip" 
    "unzip" 
    "unrar" 
    "wget" 
    "compton" 
    "pamac-aur"
    "google-chrome")
readonly VGA_VBOX=(
    "mesa" 
    "lib32-mesa" 
    "virtualbox-guest-utils")
readonly DE_XFCE=(
    "xfce4" 
    "xfce4-goodies"
    "file-roller" 
    "xfce4-whiskermenu-plugin" 
    "alacarte" 
    "thunar-volman" 
    "thunar-archive-plugin" 
    "gvfs" 
    "xfce4-dockbarx-plugin" 
    "xfce-theme-greybird" 
    "elementary-xfce-icons" 
    "xfce-polkit-git")
readonly DM=(
    "lightdm" 
    "lightdm-gtk-greeter" 
    "lightdm-gtk-greeter-settings" 
    "lightdm-slick-greeter" 
    "lightdm-settings" 
    "light-locker")
readonly SLICK_CONF="[Greeter]\\\nshow-a11y=false\\\nshow-keyboard=false\\\ndraw-grid=false\\\nbackground=/usr/share/backgrounds/xfce/xfce-blue.jpg\\\nactivate-numlock=true"
readonly PKG_FONT=(
    "ttf-iosevka-term-ss09" 
    "ttf-ubuntu-font-family" 
    "ttf-font-awesome" 
    "ttf-monoid" 
    "ttf-fantasque-sans-mono" 
    "ttf-liberation"
    "ttf-dejavu"
    "ttf-ms-fonts")
readonly PKG_AUDIO=(
    "alsa-utils" 
    "alsa-oss" 
    "alsa-lib" 
    "pulseaudio"
    "spotify" 
    "playerctl" 
    "pavucontrol")
readonly PKG_NETWORK=(
    "networkmanager"
    "network-manager-applet" 
    "networkmanager-pptp" 
    "ppp")

function start() { 
    echo -en "В процессе установки удалится вся информация с $HDD!\nВы действительно хотите продолжить? [y/N]: "
    read -n 1 OP
    OP=${OP:-"N"}
    case $OP in
        (y|Y)
            echo -e "\n-> Запуск автоматической установки!"
            partitions_drive
            formatting_partitions
            mount_partitions_drive
            install_system


        ;;
        (n|N) 
            echo -e "\n-> Установка отменена!\n"; 
            exit 0 
        ;;
        (*) 
            echo -e "\n-> Неверный ввод!"; 
            exit 0 
        ;;
    esac
}

function partitions_drive(){
    local boot_start=1
    local boot_end=$((BOOT_SIZE + boot_start))
    local root_end=$((ROOT_SIZE + boot_end))
    local swap_end=$((SWAP_SIZE + root_end))

    parted -s "$HDD" mklabel msdos
    parted "$HDD" mkpart primary ext2 "${boot_start}MiB" "${boot_end}MiB" &> /dev/null
    parted "$HDD" set 1 boot on &> /dev/null
    parted "$HDD" mkpart primary ext4 "${boot_end}MiB" "${root_end}MiB" &> /dev/null
    parted "$HDD" mkpart primary linux-swap "${root_end}MiB" "${swap_end}MiB" &> /dev/null
    parted "$HDD" mkpart primary ext4 "${swap_end}MiB" 100% &> /dev/null

}

function formatting_partitions(){
    echo -e "y\n" | mkfs.ext2 ${HDD}1 -L boot
    echo -e "y\n" | mkfs.ext4 ${HDD}2 -L root
    echo -e "y\n" | mkswap ${HDD}3 -L linux-swap
    echo -e "y\n" | mkfs.ext4 ${HDD}4 -L home

}

function mount_partitions_drive(){

    mount ${HDD}2 /mnt
    mkdir -p /mnt/{boot,home}
    mount ${HDD}1 /mnt/boot
    swapon ${HDD}3
    mount ${HDD}4 /mnt/home

    echo -e "==================== ТАБЛИЦА ===================="
    lsblk "$HDD"
    echo -e "================================================="

}

function install_system() {

    pacstrap /mnt base base-devel
    genfstab -p -L /mnt >> /mnt/etc/fstab

}

function _chroot() {
    arch-chroot /mnt /bin/bash -c "$1"
}


clear
start