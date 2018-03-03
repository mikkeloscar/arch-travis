# arch-travis [![Travis BuildStatus](https://travis-ci.org/mikkeloscar/arch-travis.svg?branch=master)](https://travis-ci.org/mikkeloscar/arch-travis)

arch-travis provides a docker based Arch Linux build environment for
[Travis-CI][travis-ci] builds. It supports a very simple (and limited)
configuration based on `.travis.yml`.

Example:
```yaml
sudo: required

services:
- docker

arch:
  repos:
  - papyros=http://dash.papyros.io/repos/$repo/$arch
  packages:
  # pacman packages
  - python
  - perl
  # aur packages
  - go-git
  # packages from papyros repo
  - papyros-shell
  script:
  - "./build_script.sh"

script:
- "curl -s https://raw.githubusercontent.com/mikkeloscar/arch-travis/master/arch-travis.sh | bash"
```

`arch.repos` defines a list of custom repositories.

`arch.packages` defines a list of packages (from official repos or AUR) to be
installed before running the build.

`arch.script` defines a list of scripts to run as part of the build. Anything
defined in the `arch.script` list will run from the base of the repository as a
normal user called `travis`. `sudo` is available as well as any packages
installed in the setup.

`script` defines the scripts to be run by travis, this is where arch-travis is
initialized.

### Default packages and repositories

By default the following packages are installed and usable from within the
build environment.

* base-devel (group)
* [git](https://www.archlinux.org/packages/extra/x86_64/git/)
* [cower](https://aur.archlinux.org/packages/cower/)
* [pacaur](https://aur.archlinux.org/packages/pacaur/)

The following repositories are enabled by default.

* core
* extra
* community
* multilib

It is possible to use custom respositories by adding them to the `arch.repos`
section of `.travis.yml` using the following format:

```yml
arch:
  repos:
    - repo-name=http://repo.com/path
```

The first repository in the list will be added first in `pacman.conf` and all
custom repositories will be added before the default repositories.

### Limitations/tradeoffs

* Increases build time with about 1-3 min.
* Doesn't work on [travis container-based infrastructure][travis-container] because `sudo` is required.
* Limited configuration.
* Doesn't include `base` group packages. If you need anything
  from `base` just add it to the `arch.packages` list in `.travis.yml`.

### clang support

The default compiler available in the environment is `gcc`, if you want to use
`clang` instead just add the following to `.travis.yml` and arch-travis will
export `CC=clang` in your build:


```yml
language: c

compiler: clang
```

## Projects using arch-travis

* [sway](https://github.com/SirCmpwn/sway)
* [networkd-dispatcher](https://github.com/craftyguy/networkd-dispatcher)

## LICENSE
<<<<<<< HEAD
Copyright (C) 2016-2017  Mikkel Oscar Lyderik Larsen
=======
Copyright (C) 2018  Mikkel Oscar Lyderik Larsen
>>>>>>> Update to use docker based environment

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
[travis-issue-4757]: https://github.com/travis-ci/travis-ci/issues/4757
