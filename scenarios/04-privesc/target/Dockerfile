FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server sudo cron python3 libcap2-bin procps \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash lowpriv && echo 'lowpriv:lowpriv' | chpasswd
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
