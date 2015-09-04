#!/bin/bash
# Copyright (C) 2014  Mikkel Oscar Lyderik Larsen
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# Script for setting up and running a travis-ci build in an up to date
# ArchLinux chroot

ARCH_TRAVIS_MIRROR=${ARCH_TRAVIS_MIRROR:-"http://mirror.one.com/archlinux"}
ARCH_TRAVIS_ARCH_ISO=${ARCH_TRAVIS_ARCH_ISO:-"2015.09.01"}
mirror_entry='Server = '$ARCH_TRAVIS_MIRROR'/\$repo/os/\$arch'
archive="archlinux-bootstrap-$ARCH_TRAVIS_ARCH_ISO-x86_64.tar.gz"
default_root="root.x86_64"
ARCH_TRAVIS_CHROOT=${ARCH_TRAVIS_CHROOT:-"$default_root"}
user="travis"
user_home="/home/$user"

# set default locale
export LANG=C
export LC_ALL=C

setup_chroot() {
  echo ":: Setting up arch chroot..."

  if [ ! -f $archive ]; then
    # get root fs
    as_normal "curl -O $ARCH_TRAVIS_MIRROR/iso/$ARCH_TRAVIS_ARCH_ISO/$archive"
  fi

  # extract root fs
  as_root "tar xf $archive"

  if [ "$ARCH_TRAVIS_CHROOT" != "$default_root" ]; then
    as_root "mv $default_root $ARCH_TRAVIS_CHROOT"
  fi

  # don't care for signed packages
  sudo sed -i "s|SigLevel    = Required DatabaseOptional|SigLevel = Never|" $ARCH_TRAVIS_CHROOT/etc/pacman.conf

  # enable multilib
  sudo sed -i "N;s|#[multilib]\n#Include|[multilib]\nInclude|" $ARCH_TRAVIS_CHROOT/etc/pacman.conf

  # add mirror
  as_root "echo $mirror_entry >> $ARCH_TRAVIS_CHROOT/etc/pacman.d/mirrorlist"

  # add nameserver to resolv.conf
  as_root "echo nameserver 8.8.8.8 >> $ARCH_TRAVIS_CHROOT/etc/resolv.conf"

  sudo mount $ARCH_TRAVIS_CHROOT $ARCH_TRAVIS_CHROOT --bind
  sudo mount --bind /proc $ARCH_TRAVIS_CHROOT/proc
  sudo mount --bind /sys $ARCH_TRAVIS_CHROOT/sys
  sudo mount --bind /dev $ARCH_TRAVIS_CHROOT/dev
  sudo mount --bind /dev/pts $ARCH_TRAVIS_CHROOT/dev/pts
  sudo mount --bind /dev/shm $ARCH_TRAVIS_CHROOT/dev/shm
  sudo mount --bind /run $ARCH_TRAVIS_CHROOT/run

  # update packages
  chroot_as_root "pacman -Syy"
  chroot_as_root "pacman -Syu base-devel ruby --noconfirm"

  # setup non-root user
  chroot_as_root "useradd -m -s /bin/bash $user"

  # disable password for sudo users
  as_root "echo \"$user ALL=(ALL) NOPASSWD: ALL\" >> $ARCH_TRAVIS_CHROOT/etc/sudoers.d/$user"

  # setup pacaur for AUR packages
  setup_pacaur
}

as_normal() {
  local cmd="/bin/bash -c '$1'"
  if [ -n "$ARCH_TRAVIS_VERBOSE" ]; then
    verbose $cmd
  else
    output $cmd
  fi
}

as_root() {
  local cmd="sudo /bin/bash -c '$1'"
  if [ -n "$ARCH_TRAVIS_VERBOSE" ]; then
    verbose $cmd
  else
    output $cmd
  fi
}

chroot_as_root() {
  local cmd="sudo chroot $ARCH_TRAVIS_CHROOT /bin/bash -c '$1'"
  if [ -n "$ARCH_TRAVIS_VERBOSE" ]; then
    verbose $cmd
  else
    output $cmd
  fi
}

chroot_as_normal() {
  local cmd="sudo chroot --userspec=$user:$user $ARCH_TRAVIS_CHROOT /bin/bash -c 'export HOME=$user_home && cd $user_home && $1'"
  if [ -n "$ARCH_TRAVIS_VERBOSE" ]; then
    verbose $cmd
  else
    output $cmd
  fi
}

verbose() {
  eval $@
  local ret=$?

  if [ $ret -gt 0 ]; then
    takedown_chroot
    exit $ret
  fi
}

output() {
  out=$(eval $@ 2>&1)
  local ret=$?

  if [ $ret -gt 0 ]; then
    takedown_chroot
    echo "${out}"
    exit $ret
  fi
}

run_build_script() {
  echo "$ $1"
  sudo chroot --userspec=$user:$user $ARCH_TRAVIS_CHROOT /bin/bash -c "export HOME=$user_home && cd $user_home && $1"
  local ret=$?

  if [ $ret -gt 0 ]; then
    takedown_chroot
    exit $ret
  fi
}

setup_pacaur() {
  local cowerarchive="cower.tar.gz"
  local aururl="https://aur.archlinux.org/cgit/aur.git/snapshot/"
  # install cower
  as_normal "curl -O $aururl/$cowerarchive"
  as_normal "tar xf $cowerarchive"
  as_root "mv cower $ARCH_TRAVIS_CHROOT$user_home"
  chroot_as_normal "cd cower && makepkg -is --skippgpcheck --noconfirm"
  as_root "rm -r $ARCH_TRAVIS_CHROOT$user_home/cower"
  as_normal "rm $cowerarchive"
  # install pacaur
  chroot_as_normal "cower -dd pacaur"
  chroot_as_normal "cd pacaur && makepkg -is --noconfirm"
  chroot_as_normal "rm -rf pacaur"
}

_pacaur() {
  local pacaur="pacaur -S $@ --noconfirm --noedit"
  chroot_as_normal "$pacaur"
}

takedown_chroot() {
  sudo umount $ARCH_TRAVIS_CHROOT/{run,dev/shm,dev/pts,dev,sys,proc}
  sudo umount $ARCH_TRAVIS_CHROOT
}

copy_travis_yml() {
  cp -a .travis.yml $ARCH_TRAVIS_CHROOT$user_home
}

copy_cwd() {
  rsync -a --exclude=$ARCH_TRAVIS_CHROOT --exclude=$archive . $ARCH_TRAVIS_CHROOT$user_home
}

travis_yml() {
  local cmd="ruby -ryaml -e 'puts ARGV[1..-1].inject(YAML.load(File.read(ARGV[0]))) {|acc, key| acc[key] }' .travis.yml $@"
  sudo chroot --userspec=$user:$user $ARCH_TRAVIS_CHROOT /bin/bash -c "cd $user_home && $cmd"
}

check_travis_yml() {
  out=$(travis_yml "$@" 2>&1)
  local ret=$?
  if [ $ret -gt 0 ]; then
    echo $ret
  elif [ -z "$out" ]; then
    echo 2
  else
    echo 0
  fi
}

build_scripts() {
  local valid=$(check_travis_yml arch script)
  if [ $valid -eq 0 ]; then
    old_ifs=$IFS
    IFS=$'\n'
    for script in $(travis_yml "arch script"); do
      run_build_script $script
    done
    IFS=$old_ifs
  else
    echo "No build scripts defined"
    takedown_chroot
    exit 1
  fi
}

install_packages() {
  local valid=$(check_travis_yml arch packages)
  if [ $valid -eq 0 ]; then
    _pacaur $(travis_yml arch packages)
  fi
}

setup_chroot

copy_travis_yml

install_packages

copy_cwd

echo ":: Running travis build..."
build_scripts

takedown_chroot

# vim:set ts=2 sw=2 et:
