#!/usr/bin/env bash
# Build Liam's Raspberry Pi OS 64-bit image from the arm64 pi-gen fork.
# Run as your normal user on a Raspberry Pi 5 with Raspberry Pi OS 64-bit.
set -Eeuo pipefail

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
trap 'printf "Build stopped at line %s. Check the error above.\n" "$LINENO" >&2' ERR

[[ $EUID -ne 0 ]] || fail 'Run as your normal user, not with sudo. The script calls sudo where needed.'
[[ $(uname -m) == aarch64 ]] || fail 'This script requires a 64-bit ARM (aarch64) system.'
[[ -r /etc/os-release ]] || fail 'Cannot identify the operating system.'
# shellcheck disable=SC1091
. /etc/os-release
[[ ${ID:-} == raspbian || ${ID:-} == debian || " ${ID_LIKE:-} " == *' debian '* ]] || fail 'Use Raspberry Pi OS or another Debian-based system.'
[[ $PWD != *' '* ]] || fail 'Run from a directory whose path contains no spaces (pi-gen cannot build from one).'
command -v apt-get >/dev/null || fail 'apt-get is required.'
command -v sudo >/dev/null || fail 'sudo is required.'
command -v df >/dev/null || fail 'df is required.'
[[ ! -e pi5-os ]] || fail "./pi5-os already exists. Move to a different empty working directory; this script will not overwrite it."

# pi-gen's work directory can consume tens of gigabytes. This is a minimum,
# not a guarantee: an SSD with substantially more room is preferable.
available_kib=$(df -Pk . | awk 'NR==2 {print $4}')
[[ $available_kib =~ ^[0-9]+$ ]] || fail 'Could not measure free space.'
minimum_kib=$((40 * 1024 * 1024))
(( available_kib >= minimum_kib )) || fail "At least 40 GiB free is required here; only $((available_kib / 1024 / 1024)) GiB is available. Use a larger drive."

printf 'Using %s GiB free in %s. Checking sudo access...\n' "$((available_kib / 1024 / 1024))" "$PWD"
sudo -v
printf 'Installing pi-gen dependencies from the arm64 README...\n'
sudo apt-get update
sudo apt-get install -y \
  coreutils quilt parted qemu-user-binfmt debootstrap zerofree zip \
  dosfstools e2fsprogs libarchive-tools libcap2-bin grep rsync xz-utils \
  file git curl bc gpg pigz xxd arch-test bmap-tools kmod

printf 'Cloning Greenisus1/pi5-os (arm64)...\n'
git clone --branch arm64 --single-branch https://github.com/Greenisus1/pi5-os.git pi5-os
cd pi5-os
[[ -f stage4/02-install-liam-apps/00-run-chroot.sh ]] || fail 'The custom app-install stage was not found; not building a different image.'
[[ ! -e config ]] || fail 'The cloned repo already contains a config; not overwriting it.'
printf "IMG_NAME='pi5-os'\n" > config

printf 'Building the image. This may take hours; keep the Pi powered and online.\n'
sudo ./build.sh

shopt -s nullglob
images=(deploy/*.img deploy/*.img.gz deploy/*.img.xz deploy/*.zip)
(( ${#images[@]} > 0 )) || fail 'Build exited successfully, but no image archive was found in deploy/. Inspect the build output.'
printf '\nFinished image file(s):\n'
printf '  %s\n' "${images[@]}"
printf 'Use Raspberry Pi Imager to write one to a SEPARATE target microSD card, not the card the Pi booted from.\n'
