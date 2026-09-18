FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends vsftpd \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /srv/ftp/pub /var/run/vsftpd/empty && echo 'FTP-FLAG{anon_ftp_is_a_gift}' > /srv/ftp/pub/flag.txt \
    && printf 'listen=YES\nanonymous_enable=YES\nanon_root=/srv/ftp\nno_anon_password=YES\nseccomp_sandbox=NO\nsession_support=NO\n' > /etc/vsftpd.conf
EXPOSE 21
CMD ["/usr/sbin/vsftpd", "/etc/vsftpd.conf"]
