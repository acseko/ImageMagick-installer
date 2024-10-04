FROM rockylinux:8 AS build

ARG IMAGEMAGICK_VERSION=7.1.0-16
ARG TARGET_ARCH=x86_64

RUN yum install -y epel-release && \
  yum install -y git make yum-utils rpm-build libtool-ltdl libtool-ltdl-devel && \
  yum group install -y "Development Tools" --exclude asciidoc --exclude graphviz && \
  yum clean all && \
  yum-config-manager --enable powertools && \
  yum clean all

WORKDIR /build

RUN echo "Preparing to build Imagemagick $IMAGEMAGICK_VERSION for $TARGET_ARCH..." && \
  git clone --depth 1 -b "$IMAGEMAGICK_VERSION" https://github.com/ImageMagick/ImageMagick.git

WORKDIR /build/ImageMagick

# Drop LQR support
# Drop Raqm support
# Drop ghostscript support
# Drop LibRaw support which is not compatible with the current version of ImageMagick
# Drop urw-base35-fonts support, which has AGPL license.
# Drop graphviz and libwmf, since these depend on urw-base35-fonts
RUN sed -i '/BuildRequires.*lqr/d; /--with-lqr/d' ImageMagick.spec.in && \
    sed -i '/BuildRequires.*raqm/d; s/--with-raqm/--without-raqm/' ImageMagick.spec.in && \
    sed -i '/BuildRequires.*ghostscript-devel/d; s/--with-gslib/--without-gslib/' ImageMagick.spec.in && \
    sed -i '/BuildRequires.*LibRaw/d; /--with-raw/d' ImageMagick.spec.in && \
    sed -i '/BuildRequires.*urw-base35-fonts/d; /--with-urw-base35-fonts/d; /urw-base35-fonts/d' ImageMagick.spec.in && \
    sed -i '/BuildRequires.*graphviz/d' ImageMagick.spec.in && \
    sed -i '/BuildRequires.*libwmf/d' ImageMagick.spec.in

RUN ./configure --with-gvc=no --with-gslib=no --with-wmf=no && \
    make dist-xz && \
    make srpm

RUN yum-builddep -y "ImageMagick-$IMAGEMAGICK_VERSION.src.rpm" --exclude urw-base35-fonts --exclude graphviz --exclude libwmf && \
    rpmbuild --rebuild --nocheck --target "$TARGET_ARCH" "ImageMagick-$IMAGEMAGICK_VERSION.src.rpm" && \
    echo "Imagemagick $IMAGEMAGICK_VERSION for $TARGET_ARCH built successfully." && \
    ls -lR /root/rpmbuild/RPMS/  && \
    cd "/root/rpmbuild/RPMS/$TARGET_ARCH" && \
    echo "Testing package for unexpected dependencies" && \
    rpm -qp --requires ImageMagick-libs-$IMAGEMAGICK_VERSION.$TARGET_ARCH.rpm | grep -qEv 'libgs' && \
    rpm -qp --requires ImageMagick-libs-$IMAGEMAGICK_VERSION.$TARGET_ARCH.rpm | grep -qEv 'urw-base35-fonts' && \
    rpm -qp --requires ImageMagick-libs-$IMAGEMAGICK_VERSION.$TARGET_ARCH.rpm | grep -qEv 'graphviz' && \
    rpm -qp --requires ImageMagick-libs-$IMAGEMAGICK_VERSION.$TARGET_ARCH.rpm | grep -qEv 'libwmf'
    

# Testing installation.
FROM redhat/ubi8:latest

ARG IMAGEMAGICK_VERSION=7.1.0-16
ARG TARGET_ARCH=x86_64

WORKDIR /install

COPY --from=build /root/rpmbuild/RPMS/x86_64/*.rpm ./
RUN yum install -y ImageMagick-libs-$IMAGEMAGICK_VERSION.$TARGET_ARCH.rpm
RUN yum install -y ImageMagick-$IMAGEMAGICK_VERSION.$TARGET_ARCH.rpm

RUN echo "ldd output of convert command" && \
    ldd /usr/bin/convert && \
    echo "Testing convert command" && \
    convert -version && \
    echo "Creating test image file" && \
    convert -size 32x32 xc:transparent test.png && \
    echo "Converting png to jpg"  && \
    convert test.png test1.jpg
