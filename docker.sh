#!/bin/bash

cd /build

if [ -n "$CC" ]; then
  # store travis CC
  TRAVIS_CC=$CC
  # reset to gcc for building arch packages
  CC=gcc
fi

# /etc/pacman.conf repository line
repo_line=70

# read arch-travis config from env
read_config() {
  local old_ifs=$IFS
  local sep='::::'
  CONFIG_BUILD_SCRIPTS=${CONFIG_BUILD_SCRIPTS//$sep/$'\n'}
  CONFIG_PACKAGES=${CONFIG_PACKAGES//$sep/$'\n'}
  CONFIG_REPOS=${CONFIG_REPOS//$sep/$'\n'}
  IFS=$'\n'
  CONFIG_BUILD_SCRIPTS=(${CONFIG_BUILD_SCRIPTS[@]})
  CONFIG_PACKAGES=(${CONFIG_PACKAGES[@]})
  CONFIG_REPOS=(${CONFIG_REPOS[@]})
  IFS=$old_ifs
}

# add custom repositories to pacman.conf
add_repositories() {
  if [ ${#CONFIG_REPOS[@]} -gt 0 ]; then
    for r in "${CONFIG_REPOS[@]}"; do
      local splitarr=(${r//=/ })
      ((repo_line+=1))
      sudo sed -i "${repo_line}i[${splitarr[0]}]" /etc/pacman.conf
      ((repo_line+=1))
      sudo sed -i "${repo_line}iServer = ${splitarr[1]}\n" /etc/pacman.conf
      ((repo_line+=1))
    done

    # update repos
    sudo pacman -Syy
  fi
}

# install packages defined in .travis.yml
install_packages() {
  for package in "${CONFIG_PACKAGES[@]}"; do
    pacaur -Syu $package --noconfirm --noedit
  done
}

# run build scripts defined in .travis.yml
build_scripts() {
  if [ ${#CONFIG_BUILD_SCRIPTS[@]} -gt 0 ]; then
    for script in "${CONFIG_BUILD_SCRIPTS[@]}"; do
      echo "\$ $script"
      eval $script
    done
  else
    echo "No build scripts defined"
    exit 1
  fi
}

install_c_compiler() {
  if [ "$TRAVIS_CC" != "gcc" ]; then
    pacaur -S "$TRAVIS_CC" --noconfirm --noedit
  fi
}

arch_msg() {
  lightblue='\033[1;34m'
  reset='\e[0m'
  echo -e "${lightblue}$@${reset}"
}

read_config

echo "travis_fold:start:arch_travis"
arch_msg "Setting up Arch environment"
add_repositories

install_packages

if [ -n "$CC" ]; then
  install_c_compiler

  # restore CC
  CC=$TRAVIS_CC
fi
echo "travis_fold:end:arch_travis"
echo ""

arch_msg "Running travis build"
build_scripts
