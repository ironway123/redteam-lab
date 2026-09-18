FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd \
    && useradd -m -s /bin/bash svc && echo 'svc:password123' | chpasswd
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
