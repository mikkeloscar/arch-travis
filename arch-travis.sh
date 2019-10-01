#!/bin/bash
# Copyright (C) 2018  Mikkel Oscar Lyderik Larsen
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

# read value from .travis.yml (separated by new line character)
travis_yml() {
  ruby -ryaml -e 'input=ARGV[1..-1].inject(YAML.load(File.read(ARGV[0]))) {|acc, key| acc[key] }; print input.respond_to?(:join) ? input.join("\n") : input' .travis.yml "$@"
}

# read value from .travis.yml (separated by null character)
travis_yml_null() {
  ruby -ryaml -e 'input=ARGV[1..-1].inject(YAML.load(File.read(ARGV[0]))) {|acc, key| acc[key] }; print input.respond_to?(:join) ? input.join("\0") : input' .travis.yml "$@"
}

# encode config so it can be passed to docker in an environment var.
encode_config() {
    base64 -w 0 <( if [ "$1" == "--null" ]; then travis_yml_null "${@:2}"; else travis_yml "$@"; fi )
}

# configure docker volumes
configure_volumes() (
    IFS=$'\n'
    mapfile -t volumes < <(travis_yml archlinux mount)
    [[ -z "${volumes[*]}" ]] && return 1
    # expand environment variables
    mapfile -t volumes < <(while read -r vol; do eval echo -e "$vol"; done <<<"${volumes[*]}")
    # expand relative paths
    mapfile -t volumes < <(ruby -e 'ARGV.each{|vol| puts vol.split(":").map{|path| File.expand_path(path)}.join(":")}' "${volumes[*]}")
    echo "Docker volumes: $(declare -p volumes)" >&2
    while read -r vol; do printf -- '-v "%s"\n' "$vol"; done<<<"${volumes[*]}"
)

# regression test for outdated arch-travis configuration scheme.
{
    if travis_yml arch script >/dev/null 2>&1; then
      echo '*** WARNING! Your current arch-travis configuration is outdated'
      echo '*** Update ".travis.yml": replacing "arch:" keyword with "archlinux:"'
      echo '*** More info: https://github.com/mikkeloscar/arch-travis/issues/65'
      exit 66
    fi
} >&2

# read travis config
CONFIG_BEFORE_INSTALL=$(encode_config --null archlinux before_install)
CONFIG_BUILD_SCRIPTS=$(encode_config --null archlinux script)
CONFIG_PACKAGES=$(encode_config archlinux packages)
CONFIG_REPOS=$(encode_config archlinux repos)
#ubuntu bash is to old to have mapfile -d syntax [sic!]
mapfile -t CONFIG_VOLUMES < <(configure_volumes)

mapfile -t envs < <(ruby -e 'ENV.each {|key,_| if not ["PATH","USER","HOME","GOROOT","LC_ALL"].include?(key) then puts "-e #{key}" end}')

#using eval to expand variables is plain wrong, but this is only way to make it work against shellcheck SC2086
eval docker run --rm \
    -v "$(pwd):/build" \
    "${CONFIG_VOLUMES[@]}" \
    -e "CC=$CC" \
    -e "CXX=$CXX" \
    -e CONFIG_BEFORE_INSTALL="$CONFIG_BEFORE_INSTALL" \
    -e CONFIG_BUILD_SCRIPTS="$CONFIG_BUILD_SCRIPTS" \
    -e CONFIG_PACKAGES="$CONFIG_PACKAGES" \
    -e CONFIG_REPOS="$CONFIG_REPOS" \
    "${envs[@]}" \
    mikkeloscar/arch-travis:latest
