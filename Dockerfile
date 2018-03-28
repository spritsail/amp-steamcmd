ARG GLIBC_VER=2.27
ARG PREFIX=/usr
ARG OUTDIR=/output

FROM spritsail/debian-builder as builder

ARG GLIBC_VER
ARG PREFIX
ARG OUTDIR
WORKDIR /tmp/glibc/build

ARG CC="gcc -m32 -mstackrealign"
ARG CXX="g++ -m32 -mstackrealign"

RUN dpkg --add-architecture i386 \
 && apt-get -y update \
 && apt-get -y install bison lib32gcc1 linux-libc-dev:i386 g++-multilib

# Download and build glibc from source
RUN curl -fL https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VER}.tar.xz \
        | tar xJ --strip-components=1 -C .. && \
    \
    echo "slibdir=${PREFIX}/lib32" >> configparms && \
    echo "rtlddir=${PREFIX}/lib32" >> configparms && \
    echo "sbindir=${PREFIX}/bin" >> configparms && \
    echo "rootsbindir=${PREFIX}/bin" >> configparms && \
    \
    export CFLAGS="-march=i686 -O2 -pipe -fstack-protector-strong" && \
    export CXXFLAGS="-march=i686 -O2 -pipe -fstack-protector-strong" && \
    \
    ../configure \
        --host=i686-pc-linux-gnu \
        --prefix=${PREFIX} \
        --libdir="${PREFIX}/lib32" \
        --libexecdir="${PREFIX}/lib32" \
        --with-native-system-header-dir=/usr/include/x86_64-linux-gnu \
        --enable-add-ons \
        --enable-obsolete-rpc \
        --enable-kernel=3.10.0 \
        --enable-bind-now \
        --disable-profile \
        --enable-stackguard-randomization \
        --enable-stack-protector=strong \
        --enable-lock-elision \
        --enable-multi-arch \
        --disable-werror && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install_root="$(pwd)/out" install


# Copy glibc libs
RUN mkdir -p ${OUTDIR}${PREFIX}/{bin,lib,lib32} \
 && cp -d out/${PREFIX}/lib32/*.so ${OUTDIR}${PREFIX}/lib32 \
 && ln -snv ../lib32/ld-linux.so.2 ${OUTDIR}${PREFIX}/lib/ld-linux.so.2

# Yeah we should probably build these from source, but its part of the debian image.....
RUN cp -d /usr/lib32/libgcc_s.so.1 ${OUTDIR}${PREFIX}/lib32

#================


FROM spritsail/amp

ARG GLIBC_VER
ARG OUTDIR

LABEL maintainer="Spritsail <amp@spritsail.io>" \
      org.label-schema.vendor="Spritsail" \
      org.label-schema.name="AMP with steamcmd" \
      org.label-schema.url="https://cubecoders.com/AMP" \
      org.label-schema.description="A game server web management tool" \
      org.label-schema.version="latest" \
      io.spritsail.version.lib32-glibc=${GLIBC_VER}

USER root

COPY --from=builder ${OUTDIR}/ /

RUN echo /usr/lib32 > /etc/ld.so.conf \
 && ldconfig && ldconfig -p

RUN mkdir -p /opt/steam/steamcmd \
 && wget -O- https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
        | tar xz -C /opt/steam/steamcmd --strip-components=1 \
 && rm -f /opt/steam/steamcmd/libstdc++.so* \
 && ln -sfv ../../opt/steam/steamcmd/steam* /usr/bin

USER amp
