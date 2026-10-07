FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       cron \
       curl \
       git \
       iproute2 \
       iputils-ping \
       less \
       net-tools \
       openssh-server \
       procps \
       python3 \
       python3-flask \
       python3-requests \
       supervisor \
       tar \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/sshd /var/log/supervisor /srv/bookshop/uploads /srv/bookshop/app /var/lib/bookshop

COPY app/ /opt/bookshop/app/
COPY docker/entrypoint.sh /usr/local/sbin/bookshop-entrypoint
COPY docker/bookshop-backup.sh /usr/local/sbin/bookshop-backup
COPY docker/supervisord.conf /etc/supervisor/conf.d/bookshop.conf
COPY docker/bookshop-backup.cron /etc/cron.d/bookshop-backup

RUN chmod 0755 /usr/local/sbin/bookshop-entrypoint /usr/local/sbin/bookshop-backup \
    && chmod 0644 /etc/cron.d/bookshop-backup \
    && chmod -R 0755 /opt/bookshop/app

EXPOSE 8080 22

ENTRYPOINT ["/usr/local/sbin/bookshop-entrypoint"]
