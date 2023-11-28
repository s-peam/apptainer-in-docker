FROM golang:1.21-alpine3.18 as builder

RUN apk add --no-cache \
        # Required for apptainer to find min go version
        bash \
        cryptsetup \
        gawk \
        gcc \
        git \
        libc-dev \
        linux-headers \
        libressl-dev \
        libuuid \
        libseccomp-dev \
        make \
        util-linux-dev

ARG APPTAINER_COMMITISH="v1.2.5"
ARG MCONFIG_OPTIONS="--with-suid"
WORKDIR $GOPATH/src/github.com/apptainer
RUN git clone https://github.com/apptainer/apptainer.git --branch $APPTAINER_COMMITISH --single-branch \
    && cd apptainer \
    && ./mconfig $MCONFIG_OPTIONS -p /usr/local/apptainer \
    && cd builddir \
    && make \
    && make install

FROM alpine:3.18.4
ARG ORAS_VERSION="1.1.0"
COPY --from=builder /usr/local/apptainer /usr/local/apptainer
ENV PATH="/usr/local/apptainer/bin:$PATH" \
    APPTAINER_TMPDIR="/tmp-apptainer"
RUN apk add --no-cache ca-certificates libseccomp squashfs-tools tzdata bash sshpass openssh p7zip curl nano docker openrc git \
    && rc-update add docker boot \
    && mkdir -p $APPTAINER_TMPDIR \
    && cp /usr/share/zoneinfo/UTC /etc/localtime \
    && apk del tzdata \
    && rm -rf /tmp/* /var/cache/apk/*

RUN curl -LO "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz" \
    && mkdir -p oras-install \
    && tar -zxf oras_${ORAS_VERSION}_*.tar.gz -C oras-install \
    && mv oras-install/oras /usr/local/bin/ \
    && rm -rf oras_${ORAS_VERSION}_*.tar.gz oras-install

WORKDIR /work
ENTRYPOINT ["/usr/local/apptainer/bin/apptainer"]
