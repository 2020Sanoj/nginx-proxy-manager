FROM zoeyvid/nginx-quic:20
COPY rootfs          /
COPY backend         /app
COPY frontend/dist   /app/frontend

WORKDIR /app
RUN echo https://dl-cdn.alpinelinux.org/alpine/edge/testing | tee -a /etc/apk/repositories && \
    apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache ca-certificates wget tzdata \
    python3 \
    nodejs-current npm \
    openssl apache2-utils jq \
    gcc g++ libffi-dev python3-dev \
    php7 php7-fpm php8 php8-fpm php81 php81-fpm php82 php82-fpm && \
    
# Install pip
    wget https://bootstrap.pypa.io/get-pip.py -O - | python3 && \

# Change permission
    chmod +x /usr/local/bin/start && \
    chmod +x /usr/local/bin/check-health && \

# Build Backend
    npm install --force && \
    pip install --no-cache-dir certbot && \
    apk del --no-cache gcc g++ libffi-dev python3-dev npm

ENV NODE_ENV=production \
    DB_SQLITE_FILE=/data/database.sqlite
    
ENTRYPOINT ["start"]
HEALTHCHECK CMD check-health
