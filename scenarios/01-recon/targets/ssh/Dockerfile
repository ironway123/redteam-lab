FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd \
    && useradd -m -s /bin/bash recon && echo 'recon:recon' | chpasswd
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
