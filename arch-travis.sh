#!/bin/bash
# Copyright (C) 2016  Mikkel Oscar Lyderik Larsen
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
# Arch Linux chroot

ARCH_TRAVIS_MIRROR=${ARCH_TRAVIS_MIRROR:-"https://ftp.lysator.liu.se/pub/archlinux"}
ARCH_TRAVIS_ARCH_ISO=${ARCH_TRAVIS_ARCH_ISO:-"$(date +%Y.%m).01"}
mirror_entry='Server = '$ARCH_TRAVIS_MIRROR'/\$repo/os/\$arch'
archive="archlinux-bootstrap-$ARCH_TRAVIS_ARCH_ISO-x86_64.tar.gz"
default_root="root.x86_64"
ARCH_TRAVIS_CHROOT=${ARCH_TRAVIS_CHROOT:-"$default_root"}
user="travis"
user_home="/home/$user"
user_uid=$UID


if [ -n "$CC" ]; then
  # store travis CC
  TRAVIS_CC=$CC
  # reset to gcc for building arch packages
  CC=gcc
fi


# default packages
default_packages=("base-devel" "ruby" "git")

# pacman.conf repository line
repo_line=70

# setup working Arch Linux chroot
setup_chroot() {
  echo ":: Setting up Arch chroot..."

  if [ ! -f $archive ]; then
    # get root fs
    local curl=$(curl -O "$ARCH_TRAVIS_MIRROR/iso/$ARCH_TRAVIS_ARCH_ISO/$archive" 2>&1)

    # if it fails, try arch iso form the previous month
    if [ $? -gt 0 ]; then
      ARCH_TRAVIS_ARCH_ISO="$(date +%Y.%m -d "-1 month").01"
      archive="archlinux-bootstrap-$ARCH_TRAVIS_ARCH_ISO-x86_64.tar.gz"
      as_normal "curl -O $ARCH_TRAVIS_MIRROR/iso/$ARCH_TRAVIS_ARCH_ISO/$archive"
    fi
  fi

  # extract root fs
  as_root "tar xf $archive"

  if [ "$ARCH_TRAVIS_CHROOT" != "$default_root" ]; then
    as_root "mv $default_root $ARCH_TRAVIS_CHROOT"
  fi

  # don't care for signed packages
  sudo sed -i "s|SigLevel    = Required DatabaseOptional|SigLevel = Never|" $ARCH_TRAVIS_CHROOT/etc/pacman.conf

  # enable multilib
  sudo sed -i 's|#\[multilib\]|\[multilib\]\nInclude = /etc/pacman.d/mirrorlist|' $ARCH_TRAVIS_CHROOT/etc/pacman.conf

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
  chroot_as_root "pacman -Syu ${default_packages[*]} --noconfirm"

  # use LANG=en_US.UTF-8 as expected in travis environments
  sudo sed -i "s|#en_US.UTF-8|en_US.UTF-8|" $ARCH_TRAVIS_CHROOT/etc/locale.gen
  chroot_as_root "locale-gen"

  # setup non-root user
  chroot_as_root "useradd -u $user_uid -m -s /bin/bash $user"

  # disable password for sudo users
  as_root "echo \"$user ALL=(ALL) NOPASSWD: ALL\" >> $ARCH_TRAVIS_CHROOT/etc/sudoers.d/$user"

  # copy .travis.yml for access in chroot
  copy_travis_yml

  # add custom repos
  add_repositories

  # setup pacaur for AUR packages
  setup_pacaur
}

# add custom repositories to pacman.conf
add_repositories() {
  local valid=$(check_travis_yml arch repos)
  if [ $valid -eq 0 ]; then
    for r in $(travis_yml arch repos); do
      local splitarr=(${r//=/ })
      ((repo_line+=1))
      sudo sed -i "${repo_line}i[${splitarr[0]}]" $ARCH_TRAVIS_CHROOT/etc/pacman.conf
      ((repo_line+=1))
      sudo sed -i "${repo_line}iServer = ${splitarr[1]}\n" $ARCH_TRAVIS_CHROOT/etc/pacman.conf
      ((repo_line+=1))
    done

    # update repos
    chroot_as_root "pacman -Syy"
  fi
}

# run command as normal user
as_normal() {
  local cmd="/bin/bash -c '$1'"
  if [ -n "$ARCH_TRAVIS_VERBOSE" ]; then
    verbose $cmd
  else
    output $cmd
  fi
}

# run command as root
as_root() {
  local cmd="sudo /bin/bash -c '$1'"
  if [ -n "$ARCH_TRAVIS_VERBOSE" ]; then
    verbose $cmd
  else
    output $cmd
  fi
}

# run command in chroot as root
chroot_as_root() {
  local cmd="sudo chroot $ARCH_TRAVIS_CHROOT /bin/bash -c '$1'"
  if [ -n "$ARCH_TRAVIS_VERBOSE" ]; then
    verbose $cmd
  else
    output $cmd
  fi
}

# run command in chroot as normal user
chroot_as_normal() {
  local cmd="sudo chroot --userspec=$user:$user $ARCH_TRAVIS_CHROOT /bin/bash -c 'export HOME=$user_home USER=$user && cd $user_home && $1'"
  if [ -n "$ARCH_TRAVIS_VERBOSE" ]; then
    verbose $cmd
  else
    output $cmd
  fi
}

# run command in verbose mode
verbose() {
  eval $@
  local ret=$?

  if [ $ret -gt 0 ]; then
    takedown_chroot
    exit $ret
  fi
}

# run command in default mode
# Any output is suppressed unless the command returns with an error
output() {
  out=$(eval $@ 2>&1)
  local ret=$?

  if [ $ret -gt 0 ]; then
    takedown_chroot
    echo "${out}"
    exit $ret
  fi
}

# run build script
run_build_script() {
  echo "$ $1"
  sudo chroot --userspec=$user:$user $ARCH_TRAVIS_CHROOT /bin/bash -c "export HOME=$user_home USER=$user && cd $user_home && $1"
  local ret=$?

  if [ $ret -gt 0 ]; then
    takedown_chroot
    exit $ret
  fi
}

# setup pacaur
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

# install package through pacaur
_pacaur() {
  local pacaur="pacaur -S $@ --noconfirm --noedit"
  chroot_as_normal "$pacaur"
}

# takedown chroot
# unmounts anything mounted in the chroot setup
takedown_chroot() {
  sudo umount $ARCH_TRAVIS_CHROOT/{run,dev/shm,dev/pts,dev,sys,proc}
  sudo umount $ARCH_TRAVIS_CHROOT
}

# copy .travis.yml to chroot
copy_travis_yml() {
  cp -a .travis.yml $ARCH_TRAVIS_CHROOT$user_home
}

# copy working dir to chroot
copy_cwd() {
  rsync -a --exclude=$ARCH_TRAVIS_CHROOT --exclude=$archive . $ARCH_TRAVIS_CHROOT$user_home
}

# read value from .travis.yml
travis_yml() {
  local cmd="ruby -ryaml -e 'puts ARGV[1..-1].inject(YAML.load(File.read(ARGV[0]))) {|acc, key| acc[key] }' .travis.yml $@"
  sudo chroot --userspec=$user:$user $ARCH_TRAVIS_CHROOT /bin/bash -c "cd $user_home && $cmd"
}

# check for config in .travis.yml
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

# run build scripts defined in .travis.yml
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

# install packages defined in .travis.yml
install_packages() {
  local valid=$(check_travis_yml arch packages)
  if [ $valid -eq 0 ]; then
    _pacaur $(travis_yml arch packages)
  fi
}

# install custom compiler if CC != gcc
install_c_compiler() {
  if [ "$TRAVIS_CC" != "gcc" ]; then
    _pacaur "$TRAVIS_CC"
  fi
}

setup_chroot

install_packages

copy_cwd

if [ -n "$CC" ]; then
  install_c_compiler

  # restore CC
  CC=$TRAVIS_CC
fi

echo ":: Running travis build..."
build_scripts

takedown_chroot

# vim:set ts=2 sw=2 et:
