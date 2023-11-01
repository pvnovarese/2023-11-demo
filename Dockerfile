FROM docker.io/opensuse/leap:15.5

LABEL name="2023-11-demo"
LABEL maintainer="pvn@novarese.net"
LABEL org.opencontainers.image.title="2023-11-demo"
LABEL org.opencontainers.image.description="Simple image to demo a specific Anchore Enterprise sbom function to a specific customer"

RUN set -ex && \
    zypper install -y ruby python3 && \
    gem install lockbox:0.6.8 ftpd:0.2.1 && \
    python3 -m ensurepip && \
    pip3 install --no-cache-dir pytest numpy

HEALTHCHECK --timeout=10s CMD /bin/true || exit 1
USER nobody
ENTRYPOINT /bin/false
