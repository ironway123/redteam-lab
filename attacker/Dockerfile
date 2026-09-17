FROM kalilinux/kali-rolling
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      nmap gobuster ffuf whatweb netcat-traditional curl wget \
      smbclient ftp openssh-client sshpass iproute2 iputils-ping python3 \
      sqlmap hydra metasploit-framework \
      hashcat john aircrack-ng hcxtools wordlists dirb ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN gunzip -kf /usr/share/wordlists/rockyou.txt.gz \
    && ln -sf /usr/share/wordlists/rockyou.txt /root/rockyou.txt
COPY linpeas.sh /opt/privesc/linpeas.sh
RUN chmod +x /opt/privesc/linpeas.sh
WORKDIR /root
CMD ["sleep", "infinity"]
