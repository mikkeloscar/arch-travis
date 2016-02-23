# Build Archlinux packages with drone
#
#     docker build --rm=true -t mikkeloscar/arch-travis .

FROM nfnty/arch-devel:latest
MAINTAINER Mikkel Oscar Lyderik <mikkeloscar@gmail.com>

# Setup build user/group
ENV UGID='1001' UGNAME='travis'
RUN \
    groupadd --gid "$UGID" "$UGNAME" && \
    useradd --create-home --uid "$UGID" --gid "$UGID" --shell /usr/bin/false "${UGNAME}"

# copy sudoers file
COPY contrib/etc/sudoers.d/$UGNAME /etc/sudoers.d/$UGNAME
# Add pacman.conf template
COPY contrib/etc/pacman.conf /etc/pacman.conf

RUN \
    # Update
    pacman -Syu --noconfirm && \
    # Clean .pacnew files
    find / -name "*.pacnew" -exec rename .pacnew '' '{}' \; && \
    # Clean pkg cache
    find /var/cache/pacman/pkg -mindepth 1 -delete

RUN \
    chmod 'u=r,g=r,o=' /etc/sudoers.d/$UGNAME && \
    chmod 'u=rw,g=r,o=r' /etc/pacman.conf

USER $UGNAME

# install cower and pacaur
RUN \
    cd /home/$UGNAME && \
    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/cower.tar.gz && \
    tar xf cower.tar.gz && \
    cd cower && makepkg -is --skippgpcheck --noconfirm && cd .. && \
    rm -rf cower && rm cower.tar.gz && \
    cower -dd pacaur && \
    cd pacaur && makepkg -is --noconfirm && cd .. && rm -rf pacaur

# Add arch-travis script
COPY docker.sh /usr/bin/arch-travis

ENTRYPOINT ["/usr/bin/arch-travis"]
