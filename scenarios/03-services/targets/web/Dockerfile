FROM php:8.2-apache
RUN echo 'WEB-FLAG{cmd_1nj3ct10n_to_rce}' > /flag.txt && apt-get update \
    && apt-get install -y --no-install-recommends iputils-ping && rm -rf /var/lib/apt/lists/*
COPY cmd.php /var/www/html/cmd.php
