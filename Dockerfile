FROM centos:7

MAINTAINER dan78uk

# Set working dir
ENV WORKING_DIRECTORY=/opt/build
RUN mkdir -p $WORKING_DIRECTORY
WORKDIR $WORKING_DIRECTORY

# ENV build variables
ENV LANG C.UTF-8
ENV NPS_VERSION=1.9.32.2
ENV NGINX_VERSION=1.11.1
ENV MODSEC_VERSION=2.9.1
ENV NGINX_ADD_MODULES=" --add-module=$WORKING_DIRECTORY/ModSecurity/nginx/modsecurity "
ENV NGINX_EXTRA_MODULES=" --with-http_realip_module --with-http_ssl_module "
ENV LC_ALL=C

# 1 Install required dependencies
# 2 Compile Mod Security
# 3 Get Mod security configs
# 4 Compile Nginx
RUN yum -y groups mark convert \
    && yum clean all && yum -y swap fakesystemd systemd \
    && echo "#### Install required dependencies ####" \
    && yum -y --setopt=group_command=objects groupinstall 'Development Tools' \
    && yum -y install gcc-c++ pcre-dev pcre-devel zlib-devel make unzip httpd-devel libxml2 libxml2-devel wget openssl-devel \
    && echo "#### Compile Mod Security ####" \
    && git clone https://github.com/SpiderLabs/ModSecurity.git \
    && cd ModSecurity \
    && git checkout tags/v${MODSEC_VERSION} \
    && ./autogen.sh \
    && ./configure --enable-standalone-module --disable-mlogc \
    && make \
    && make install \
    && cd .. \
    && wget https://raw.githubusercontent.com/SpiderLabs/ModSecurity/master/modsecurity.conf-recommended \
    && mkdir -p /etc/nginx \
    && cat modsecurity.conf-recommended  > /etc/nginx/modsecurity.conf \
    && echo "#### Get Mod security configs ####" \
    && wget https://github.com/SpiderLabs/owasp-modsecurity-crs/tarball/master -O owasp-modsecurity-crs.tar.gz \
    && tar -xvzf owasp-modsecurity-crs.tar.gz \
    && CRS_DIR=$(find . -type d -name SpiderLabs-owasp-modsecurity-crs*) \
    && cat ${CRS_DIR}/modsecurity_crs_10_setup.conf.example >> /etc/nginx/modsecurity.conf \
    && cat ${CRS_DIR}/base_rules/modsecurity_*.conf >> /etc/nginx/modsecurity.conf \
    && cp ${CRS_DIR}/base_rules/*.data /etc/nginx/ \
    && cp ModSecurity/unicode.mapping /etc/nginx/unicode.mapping \
    && echo "#### Compile Nginx ####" \
    && wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -xvzf nginx-${NGINX_VERSION}.tar.gz \
    && cd nginx-${NGINX_VERSION}/ \
    && ./configure $NGINX_ADD_MODULES $NGINX_EXTRA_MODULES \
    && make \
    && make install \
    && cd .. \
    && echo "#### Clean Solution ####" \
    && yum -y --setopt=group_command=objects groupremove 'Development Tools' \
    && yum -y autoremove \
    && yum -y remove *-devel \
    && yum -y clean all \
    && rm -rf $WORKING_DIRECTORY

# Link nginx and clean solution
RUN ln -s /usr/local/nginx/sbin/nginx /usr/bin/nginx \
    && cp /usr/local/nginx/conf/*.* /etc/nginx/
WORKDIR /etc/nginx

# Check Nginx installation
RUN nginx -V

# Enable basic configurations and import of external configurations
RUN yum -y install openssl \
    && yum -y clean all \
    && rm -rf /etc/nginx/conf.d/*; \
    mkdir -p /etc/nginx/external
RUN sed -i 's/access_log.*/access_log \/dev\/stdout;/g' /etc/nginx/nginx.conf; \
    sed -i 's/error_log.*/error_log \/dev\/stdout info;/g' /etc/nginx/nginx.conf;
ADD basic.conf /etc/nginx/conf.d/basic.conf
ADD ssl.conf /etc/nginx/conf.d/ssl.conf
ADD entrypoint.sh /opt/entrypoint.sh
RUN chmod a+x /opt/entrypoint.sh
ENTRYPOINT ["/opt/entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
