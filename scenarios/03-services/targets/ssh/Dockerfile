FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd \
    && useradd -m -s /bin/bash svc && echo 'svc:password123' | chpasswd \
    && mkdir -p /etc/ssh/sshd_config.d \
    && printf 'PerSourcePenalties no\nMaxStartups 100:30:200\n' \
         > /etc/ssh/sshd_config.d/00-lab-bruteforceable.conf \
    && sed -i 's/\(pam_unix\.so.*\)/\1 nodelay/' /etc/pam.d/common-auth
# This is a deliberately weak training target. Modern defaults fight the
# scenario's whole point (cracking the svc password with hydra/Metasploit), so
# three brakes are released here:
#   - PerSourcePenalties no      (OpenSSH 9.8+ blocks a source IP after failed auths)
#   - MaxStartups 100:30:200     (default 10:30:100 drops parallel unauth connections)
#   - pam_unix ... nodelay       (removes PAM's ~2s delay per failed password)
# Do NOT copy any of this onto a real host.
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
