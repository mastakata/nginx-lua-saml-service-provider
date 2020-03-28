FROM ubuntu:18.04

RUN apt-get update \
 && apt-get install -y software-properties-common \
 && add-apt-repository -y ppa:hnakamur/openresty-luajit \
 && add-apt-repository -y ppa:hnakamur/libsxg \
 && add-apt-repository -y ppa:hnakamur/nginx \
 && apt-get update \
 && apt-get install -y luajit libluajit-5.1 libluajit-5.1-common nginx \
        libxmlsec1 libxmlsec1-openssl \
 && ln -s $(readlink /lib/x86_64-linux-gnu/libz.so.1) /lib/x86_64-linux-gnu/libz.so \
 && ln -s $(readlink /usr/lib/x86_64-linux-gnu/libxml2.so.2) /usr/lib/x86_64-linux-gnu/libxml2.so \
 && ln -s $(readlink /usr/lib/x86_64-linux-gnu/libxmlsec1.so.1) /usr/lib/x86_64-linux-gnu/libxmlsec1.so \
 && ln -s $(readlink /usr/lib/x86_64-linux-gnu/libxmlsec1-openssl.so.1) /usr/lib/x86_64-linux-gnu/libxmlsec1-openssl.so \
 && ln -s /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so \
 && rm /var/log/nginx/access.log /var/log/nginx/error.log \
 && ln -s /dev/stdout /var/log/nginx/access.log \
 && ln -s /dev/stderr /var/log/nginx/error.log

COPY example_config/etc/nginx/conf.d /etc/nginx/conf.d/
COPY example_config/etc/nginx/lua /etc/nginx/lua/
COPY example_config/etc/nginx/saml /etc/nginx/saml/
COPY example_config/etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY lib/ /usr/lib/nginx/lua/

RUN openssl req -new -newkey rsa:2048 -sha1 -x509 -nodes \
    -set_serial 2 \
    -days 365 \
    -subj "/C=JP/ST=Osaka/L=Osaka City/CN=sp.example.com" \
    -out /etc/nginx/saml/sp.example.com.crt \
    -keyout /etc/nginx/saml/sp.example.com.key

CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
