#!/usr/bin/env bash
# Build pi5-os on a separate, mounted ext4 drive chosen at run time.
# This script removes the contents of the selected build directory after confirmation.
set -Eeuo pipefail

fail() { printf 'Stopped: %s\n' "$*" >&2; exit 1; }

[[ $(id -u) -ne 0 ]] || fail 'Run as your normal user, not with sudo.'
[[ $(uname -m) == aarch64 ]] || fail 'This script needs a 64-bit ARM Linux host (for example, a Pi 5). It does not run on macOS.'
[[ -f /etc/debian_version ]] || fail 'This script needs Debian or Raspberry Pi OS.'
for program in sudo git findmnt lsblk df realpath find awk readlink; do
  command -v "$program" >/dev/null || fail "Missing required command: $program"
done

# Resolve the underlying whole disk for a block-device mount source.
backing_disk() {
  local source resolved
  source=$(findmnt -n -o SOURCE -T "$1") || return 1
  [[ $source == /dev/* ]] || return 1
  resolved=$(readlink -f -- "$source") || return 1
  lsblk -spno NAME,TYPE -- "$resolved" | awk '$2 == "disk" { print $1; exit }'
}

printf 'Build directory (must already exist on a separate ext4 drive with at least 40 GiB free): '
IFS= read -r input_dir
[[ -n $input_dir ]] || fail 'No directory entered.'
[[ -d $input_dir && ! -L $input_dir ]] || fail 'Enter an existing real directory, not a symlink.'
target=$(realpath -e -- "$input_dir") || fail 'Cannot resolve that directory.'
[[ $target != / && $target != /boot && $target != /boot/firmware && $target != "$HOME" ]] || fail 'That directory is protected.'
[[ $target != *' '* ]] || fail 'pi-gen cannot build in a path containing spaces.'
[[ -w $target && -x $target ]] || fail 'You need write access to that directory as your normal user.'
filesystem=$(findmnt -n -o FSTYPE -T "$target") || fail 'Cannot determine filesystem.'
[[ $filesystem == ext4 ]] || fail "Build directory is on $filesystem, not ext4. Use a separate ext4 Linux drive."
mountpoint=$(findmnt -n -o TARGET -T "$target") || fail 'Cannot determine mount point.'
[[ $mountpoint != / && $mountpoint != /boot && $mountpoint != /boot/firmware ]] || fail 'Cannot use the main or boot filesystem.'
# Prevent deleting entries from a second mount nested inside the chosen directory.
while IFS= read -r nested_mount; do
  if [[ $nested_mount == "$target"/* ]]; then
    fail "Another filesystem is mounted under the directory: $nested_mount"
  fi
done < <(findmnt -rn -o TARGET)

chosen_disk=$(backing_disk "$target") || fail 'Cannot verify the selected drive. Refusing to erase anything.'
[[ -n $chosen_disk ]] || fail 'Cannot verify the selected drive.'
root_disk=$(backing_disk /) || fail 'Cannot verify the boot/root drive. Refusing to erase anything.'
[[ -n $root_disk && $chosen_disk != "$root_disk" ]] || fail 'The selected directory shares a physical disk with the root filesystem.'
for boot_path in /boot /boot/firmware; do
  if [[ -d $boot_path ]]; then
    boot_disk=$(backing_disk "$boot_path") || fail "Cannot verify $boot_path drive. Refusing to erase anything."
    [[ -n $boot_disk && $chosen_disk != "$boot_disk" ]] || fail "The selected directory shares a physical disk with $boot_path."
  fi
done

free_kib=$(df -Pk -- "$target" | awk 'NR == 2 { print $4 }')
[[ $free_kib =~ ^[0-9]+$ ]] || fail 'Could not check available space.'
(( free_kib >= 40 * 1024 * 1024 )) || fail 'This drive has less than 40 GiB free. Erasing a 32GB card cannot make enough space. Choose a larger ext4 drive.'
[[ $target != "$mountpoint" ]] || fail "Choose a dedicated folder inside the drive, not the drive root. Create an empty folder such as MICROSD/build first."
script_path=$(realpath -e -- "$0") || fail 'Cannot resolve this script path.'
[[ $script_path != "$target"/* ]] || fail 'Move this script outside the directory to erase before running it.'

printf '\nSelected build directory: %s\nMount point: %s\nFilesystem: %s\nPhysical drive: %s\nFree space: %s GiB\n' \
  "$target" "$mountpoint" "$filesystem" "$chosen_disk" "$((free_kib / 1024 / 1024))"
printf 'WARNING: This will PERMANENTLY DELETE every file and folder INSIDE %s, including hidden files.\n' "$target"
printf 'It will not reformat the drive or flash an SD card. It will install build packages onto the host OS.\n'
printf 'Type exactly "ERASE %s" to continue: ' "$target"
IFS= read -r confirmation
[[ $confirmation == "ERASE $target" ]] || fail 'Confirmation did not match. Nothing was erased.'

cd /
find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
[[ ! -e $target/pi5-os ]] || fail 'Could not clear the old pi5-os directory.'
printf '\nBuild directory cleared. Installing dependencies and building pi5-os...\n'
sudo apt-get update
sudo apt-get install -y coreutils quilt parted qemu-user-binfmt debootstrap zerofree zip \
  dosfstools e2fsprogs libarchive-tools libcap2-bin grep rsync xz-utils file git curl bc \
  gpg pigz xxd arch-test bmap-tools kmod
cd "$target"
git clone --branch arm64 --single-branch https://github.com/Greenisus1/pi5-os.git pi5-os
cd pi5-os
[[ -f stage4/02-install-liam-apps/00-run-chroot.sh ]] || fail 'Expected custom stage is missing; stopping.'
printf "IMG_NAME='pi5-os'\n" > config
sudo ./build.sh
printf '\nBuild finished. Image files in %s/deploy/:\n' "$PWD"
find "$PWD/deploy" -maxdepth 1 -type f \( -name '*.img' -o -name '*.img.xz' -o -name '*.zip' \) -print
printf 'Use a separate SD card and Raspberry Pi Imager to flash the finished image. This script did not flash or reformat a card.\n'
