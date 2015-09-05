# arch-travis [![Travis BuildStatus](https://travis-ci.org/mikkeloscar/arch-travis.svg?branch=master)](https://travis-ci.org/mikkeloscar/arch-travis)

arch-travis provides a chroot based Arch Linux build environment for
[Travis-CI][travis-ci] builds. It supports a very simple (and limited)
configuration based on `.travis.yml`.

Example:
```yml
sudo: required

arch:
  packages:
    # pacman packages
    - python
    - perl
    # aur packages
    - go-git
  script:
    - "./build_script.sh"

script:
  - "curl -s https://raw.githubusercontent.com/mikkeloscar/arch-travis/master/arch-travis.sh | bash"
```

`arch.packages` defines a list of packages (from official repos or AUR) to be
installed before running the build.

`arch.script` defines a list of scripts to run as part of the build. Anything
defined in the `arch.script` list will run from the base of the repository as a
normal user called `travis`. `sudo` is available as well as any packages
installed in the setup.

`script` defines the scripts to be run by travis, this is where arch-travis is
initialized.

### Default packages

By default the following packages are installed and usable from within the
build environment.

* base-devel (group)
* [ruby](https://www.archlinux.org/packages/extra/x86_64/ruby/)
* [git](https://www.archlinux.org/packages/extra/x86_64/git/)
* [cower](https://aur.archlinux.org/packages/cower/)
* [pacaur](https://aur.archlinux.org/packages/pacaur/)

### Limitations/tradeoffs

* Increases build time with about 1-3 min.
* Doesn't work on [travis container-based infrastructure][travis-container] because `sudo` is required.
* Limited configuration.
* Doesn't include `base` group packages. If you need anything
  from `base` please list it in the `arch.packages` list of `.travis.yml`.

## Advanced configuration

Apart from the basic `arch` entry in `.travis.yml` it is also possible to
define some environment variables in order to control the chroot setup.

The following variables are available:

`ARCH_TRAVIS_VERBOSE` by default any output generated in the chroot setup is
suppressed and only displayed if one of the setup commands fails. By setting
`ARCH_TRAVIS_VERBOSE` no output is suppressed.

`ARCH_TRAVIS_CHROOT` name of the folder containing the chroot. (default is
`root.x86_64`).

`ARCH_TRAVIS_MIRROR` Arch Linux mirror used by pacman. See list of available
mirrors [here][arch-mirros]. (default is
`https://ftp.lysator.liu.se/pub/archlinux`)

`ARCH_TRAVIS_ARCH_ISO` Arch iso date from which the chroot is bootstraped.
(default is the latest iso date, updated about once a month).

To use, just add the variable to the `env` section of `.travis.yml`.

```yml
env:
  - ARCH_TRAVIS_VERBOSE=1
  - ARCH_TRAVIS_CHROOT="custom_root"
```

## LICENSE
Copyright (C) 2015  Mikkel Oscar Lyderik Larsen

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

[travis-ci]: https://travis-ci.org
[travis-container]: http://docs.travis-ci.com/user/workers/container-based-infrastructure/
[arch-mirrors]: https://www.archlinux.org/mirrorlist/all/
