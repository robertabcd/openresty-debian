FROM ubuntu:trusty

# Required system packages
RUN apt-get update \
    && apt-get install -y \
        libreadline6-dev \
        libncurses5-dev \
        libpcre3-dev \
        libssl-dev \
        perl \
        make \
        build-essential \
        curl \
        wget \
        unzip \
        ruby-dev \
    && gem install fpm


RUN mkdir /build /build/root
WORKDIR /build

# Download packages
RUN wget https://openresty.org/download/openresty-1.11.2.3.tar.gz \
    && tar xfz openresty-1.11.2.3.tar.gz


# Compile and install openresty
RUN cd /build/openresty-1.11.2.3 \
    && ./configure \
        --with-pcre-jit \
        --with-ipv6 \
        --with-http_v2_module \
        --prefix=/usr/share/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --lock-path=/var/lock/nginx.lock \
        --pid-path=/run/nginx.pid \
        --http-client-body-temp-path=/var/lib/nginx/body \
        --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
        --http-proxy-temp-path=/var/lib/nginx/proxy \
        --http-scgi-temp-path=/var/lib/nginx/scgi \
        --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
        --user=www-data \
        --group=www-data \
    && make -j16 \
    && make install DESTDIR=/build/root


COPY scripts/* nginx-scripts/
COPY conf/* nginx-conf/

# Add extras to the build root
RUN cd /build/root \
    && mkdir \
        etc/init.d \
        etc/logrotate.d \
        etc/nginx/sites-available \
        etc/nginx/sites-enabled \
        var/lib \
        var/lib/nginx \
    && rm etc/nginx/*.default \
    && cp /build/nginx-scripts/init etc/init.d/nginx \
    && chmod +x etc/init.d/nginx \
    && cp /build/nginx-conf/logrotate etc/logrotate.d/nginx \
    && cp /build/nginx-conf/nginx.conf etc/nginx/nginx.conf \
    && cp /build/nginx-conf/default etc/nginx/sites-available/default


# Build deb
RUN fpm -s dir -t deb \
    -n openresty \
    -v 1.11.2.3-tapstream1 \
    -C /build/root \
    -p openresty_VERSION_ARCH.deb \
    --description 'a high performance web server and a reverse proxy server' \
    --url 'http://openresty.org/' \
    --category httpd \
    --maintainer 'Nick Sitarz <nick@tapstream.com>' \
    --depends libpcre3 \
    --depends libssl1.0.0 \
    --deb-build-depends build-essential \
    --replaces 'nginx-full' \
    --provides 'nginx-full' \
    --conflicts 'nginx-full' \
    --replaces 'nginx-common' \
    --provides 'nginx-common' \
    --conflicts 'nginx-common' \
    --after-install nginx-scripts/postinstall \
    --before-install nginx-scripts/preinstall \
    --after-remove nginx-scripts/postremove \
    --before-remove nginx-scripts/preremove \
    etc run usr var

