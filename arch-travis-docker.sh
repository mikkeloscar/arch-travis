#!/bin/bash

# read value from .travis.yml
travis_yml() {
  ruby -ryaml -e 'puts ARGV[1..-1].inject(YAML.load(File.read(ARGV[0]))) {|acc, key| acc[key] }' .travis.yml $@
}

# encode config so it can be passed to docker in an environment var.
encode_config() {
    local old_ifs=$IFS
    IFS=$'\n'
    local sep="::::"
    arr=($(travis_yml $@))
    arr="$(printf "${sep}%s" "${arr[@]}")"
    arr="${arr:${#sep}}"
    IFS=$old_ifs
    echo $arr
}

# read travis config
CONFIG_BUILD_SCRIPTS=$(encode_config arch script)
CONFIG_PACKAGES=$(encode_config arch packages)
CONFIG_REPOS=$(encode_config arch repos)

docker pull mikkeloscar/arch-travis
docker run --rm -v $(pwd):/build \
    -e CC=$CC \
    -e CONFIG_BUILD_SCRIPTS="$CONFIG_BUILD_SCRIPTS" \
    -e CONFIG_PACKAGES="$CONFIG_PACKAGES" \
    -e CONFIG_REPOS="$CONFIG_REPOS" \
    mikkeloscar/arch-travis
