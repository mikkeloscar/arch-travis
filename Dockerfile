# Build Archlinux packages with drone
#
#     docker build --rm=true -t mikkeloscar/arch-travis .

FROM archlinux:latest
MAINTAINER Mikkel Oscar Lyderik Larsen <m@moscar.net>

# copy sudoers file
COPY contrib/etc/sudoers.d/$UGNAME /etc/sudoers.d/$UGNAME
# Add pacman.conf template
COPY contrib/etc/pacman.conf /etc/pacman.conf

# WORKAROUND for glibc 2.33 and old Docker
# See https://github.com/actions/virtual-environments/issues/2658
# Thanks to https://github.com/lxqt/lxqt-panel/pull/1562
RUN patched_glibc=glibc-linux4-2.33-4-x86_64.pkg.tar.zst && \
    curl -LO "https://repo.archlinuxcn.org/x86_64/$patched_glibc" && \
    bsdtar -C / -xvf "$patched_glibc"

RUN cat /etc/pacman.d/mirrorlist

RUN \
    # Update
    pacman -Syu \
        base-devel \
        git \
        reflector \
        --noconfirm && \
    # Clean .pacnew files
    find / -name "*.pacnew" -exec rename .pacnew '' '{}' \;

RUN \
    chmod 'u=r,g=r,o=' /etc/sudoers.d/$UGNAME && \
    chmod 'u=rw,g=r,o=r' /etc/pacman.conf

# Setup build user/group
ENV UGID='2000' UGNAME='travis'
RUN \
    groupadd --gid "$UGID" "$UGNAME" && \
    useradd --create-home --uid "$UGID" --gid "$UGID" --shell /usr/bin/false "${UGNAME}"

USER $UGNAME

RUN \
    sudo reflector --verbose -l 10 \
        --sort rate --save /etc/pacman.d/mirrorlist

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/core_perl

# install cower and pacaur
RUN \
    cd /home/$UGNAME && \
    curl -O -s https://aur.archlinux.org/cgit/aur.git/snapshot/yay-bin.tar.gz && \
    tar xf yay-bin.tar.gz && \
    cd yay-bin && makepkg -is --skippgpcheck --noconfirm && cd .. && \
    rm -rf yay-bin && rm yay-bin.tar.gz

# Add arch-travis script
COPY init.sh /usr/bin/arch-travis

ENTRYPOINT ["/usr/bin/arch-travis"]
