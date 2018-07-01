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
            configurations_system

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

function set_language(){
    _chroot "echo -e \"KEYMAP=ru\\nFONT=cyr-sun16\\nFONT_MAP=\" > /etc/vconsole.conf"
    _chroot "sed -i '/ru_RU.UTF-8/,+1 s/^#//' /etc/locale.gen"
    _chroot "sed -i '/en_US.UTF-8/,+1 s/^#//' /etc/locale.gen"
    _chroot "locale-gen"
    _chroot "echo LANG=ru_RU.UTF-8 > /etc/locale.conf"
    _chroot "export LANG=ru_RU.UTF-8"
}

function set_hour(){
    _chroot "ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime"
    _chroot "hwclock --systohc --localtime"
    _chroot "echo -e \"$NTP\" >> /etc/systemd/timesyncd.conf"
}

function configurations_pacman(){
    _chroot "sed -i '/multilib]/,+1  s/^#//' /etc/pacman.conf"
    _chroot "pacman -Sy reflector --needed --noconfirm" &> /dev/null
    _chroot "reflector --country Russia --country Germany --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist" &> /dev/null
    _chroot "pacman -Syu --noconfirm" &> /dev/null
    _chroot "pacman-key --init && pacman-key --populate archlinux" &> /dev/null
}

function create_users(){
    _chroot "useradd -m -g users -G wheel -s /bin/bash $MY_USER"
    _chroot "echo ${MY_USER}:${MY_USER_PASSWD} | chpasswd"
    _chroot "echo root:${ROOT_PASSWD} | chpasswd"
    _chroot "echo \"$HOST\" > /etc/hostname"
}

function install_manager_aur(){
     (_chroot "pacman -S git --needed --noconfirm" &> /dev/null
    _chuser "cd /home/${MY_USER} && git clone https://aur.archlinux.org/trizen.git && 
             cd /home/${MY_USER}/trizen && makepkg -si --noconfirm && 
             rm -rf /home/${MY_USER}/trizen" &> /dev/null)
}

function install_bootloader_grub(){
    _chroot "pacman -S grub os-prober --needed --noconfirm" 1> /dev/null
    _chroot "grub-install $HDD" &> /dev/null
    _chroot "grub-mkconfig -o /boot/grub/grub.cfg" &> /dev/null
}

function install_packages(){
    local packages=("$@")
    for i in "${packages[@]}"; do
        (_chuser "trizen -S ${i} --needed --noconfirm --quiet --noinfo" &> /dev/null)

    done 
}

function install_desktop_environment(){
    install_packages "${DE_XFCE[@]}"
}

function install_display_manager(){
    (_chuser "trizen -S ${DM} --needed --noconfirm" &> /dev/null
    _chroot "sed -i '/^#greeter-session/c \greeter-session=slick-greeter' /etc/lightdm/lightdm.conf"
    _chroot "echo -e ${SLICK_CONF} > /etc/lightdm/slick-greeter.conf"
    _chroot "systemctl enable lightdm.service" &> /dev/null)
}

function install_packages_audio(){
    install_packages "${PKG_AUDIO[@]}"
}

function install_packages_video(){
    install_packages "${VGA_VBOX[@]}"
    install_packages "${PKG_VIDEO[@]}"
}

function install_packages_network(){
    install_packages "${PKG_NETWORK[@]}"
    _chroot "systemctl enable NetworkManager.service" 2> /dev/null
}

function install_packages_font(){
    install_packages "${PKG_FONT[@]}"
}

function install_packages_other(){
    install_packages "${PKG_EXTRA[@]}"
    _chuser "xdg-user-dirs-update"
}

function configurations_system() {
    set_language
    set_hour
    configurations_pacman
    create_users
    install_manager_aur
    install_bootloader_grub
    install_desktop_environment
    install_display_manager
    install_packages_audio
    install_packages_video
    install_packages_network
    install_packages_font
    install_packages_other
    umount -R /mnt &> /dev/null
}

clear
start