FROM ubuntu:18.04 AS base1

# cmake version. See https://github.com/osquery/osquery/pull/6801 We
# might have to fall back to something earlier and build cmake :\
ENV cmakeVer 3.19.6

RUN apt update -q -y
RUN apt upgrade -q -y
RUN apt install -q -y --no-install-recommends \
	git \
	make \
	cppcheck \
	ccache \
	python \
	python3 \
	sudo \
	wget \
	ca-certificates \
	tar \
	icu-devtools \
	flex \
	bison \
	xz-utils \
	python3-setuptools \
	python3-psutil \
	python3-pip \
	python3-six \
	rpm \
	dpkg-dev \
	file \
	elfutils \
	locales \
	python3-wheel
RUN apt clean && rm -rf /var/lib/apt/lists/* \
RUN pip3 install timeout_decorator thrift==0.11.0 osquery pexpect==3.3 docker

FROM base1 AS base2
RUN case $(uname -m) in aarch64) ARCH="aarch64" ;; amd64|x86_64) ARCH="x86_64" ;; esac \
	&& wget https://github.com/osquery/osquery-toolchain/releases/download/1.1.0/osquery-toolchain-1.1.0-${ARCH}.tar.xz \
	&& sudo tar xvf osquery-toolchain-1.1.0-${ARCH}.tar.xz -C /usr/local \
	&& rm osquery-toolchain-1.1.0-${ARCH}.tar.xz \
	&& wget https://github.com/Kitware/CMake/releases/download/v${cmakeVer}/cmake-${cmakeVer}-Linux-${ARCH}.tar.gz \
	&& sudo tar xvf cmake-${cmakeVer}-Linux-${ARCH}.tar.gz -C /usr/local --strip 1 \
	&& rm cmake-${cmakeVer}-Linux-${ARCH}.tar.gz

RUN rm -rf /usr/local/doc /usr/local/bin/cmake-gui

FROM base2 AS base3
RUN locale-gen en_US.UTF-8
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

# Squash all layers down using a giant COPY. It's kinda gross, but it
# works. Though the layers are only adding about 50 megs on a 1gb
# image.
FROM scratch AS builder
COPY --from=base3 / /
