FROM ubuntu:24.04
ENV SEAFILE_SERVER=seafile-server SEAFILE_VERSION=

# https://github.com/phusion/baseimage-docker
COPY base_scripts /bd_build
RUN /bd_build/prepare.sh && \
    /bd_build/system_services.sh && \
    /bd_build/utilities.sh && \
    /bd_build/cleanup.sh
ENV DEBIAN_FRONTEND="teletype" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

RUN echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list \
    && curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -

# Security
RUN apt-get update --fix-missing && apt-get upgrade -y

# Utility tools
RUN apt-get install -y vim htop net-tools psmisc wget curl git unzip

# For suport set local time zone.
RUN export DEBIAN_FRONTEND=noninteractive && apt-get install -y tzdata \
    nginx \
    libmysqlclient-dev \
    libmemcached11 libmemcached-dev \
    fuse \
    ldap-utils libldap2-dev ca-certificates dnsutils pkg-config

# Python3
RUN apt-get install -y python3 python3-pip python3-setuptools python3-ldap && \
    rm /usr/lib/python3.12/EXTERNALLY-MANAGED && \
    rm -f /usr/bin/python && ln -s /usr/bin/python3 /usr/bin/python

RUN pip3 install --timeout=3600 \
    click termcolor colorlog \
    sqlalchemy==2.0.* gevent==24.2.* pymysql==1.1.* jinja2 markupsafe==2.0.1 django-pylibmc pylibmc psd-tools lxml \
    django==4.2.* cffi==1.17.0 future==1.0.* mysqlclient==2.2.* captcha==0.6.* django_simple_captcha==0.6.* \
    pyjwt==2.9.* djangosaml2==1.9.* pysaml2==7.3.* pycryptodome==3.20.* python-ldap==3.4.* pillow==10.4.* PyMuPDF==1.24.* numpy==1.26.* \
    --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple/

# Scripts
COPY scripts_12.0 /scripts
COPY templates /templates
COPY services /services

# acme
# RUN curl https://get.acme.sh | sh -s
RUN unzip /scripts/acme.sh-master.zip -d /scripts/ && \
    mv /scripts/acme.sh-master /scripts/acme.sh && \
    cd /scripts/acme.sh && /scripts/acme.sh/acme.sh --install

RUN mkdir -p /etc/ldap/ && echo "TLS_REQCERT     allow" >> /etc/ldap/ldap.conf && \
    chmod u+x /scripts/* && rm /scripts/cluster* && \
    mkdir -p /etc/my_init.d && \
    rm -f /etc/my_init.d/* && \
    cp /scripts/create_data_links.sh /etc/my_init.d/01_create_data_links.sh && \
    mkdir -p /etc/service/nginx && \
    mkdir -p /etc/nginx/sites-enabled && mkdir -p /etc/nginx/sites-available && \
    rm -f /etc/nginx/sites-enabled/* /etc/nginx/conf.d/* && \
    mv /services/nginx.conf /etc/nginx/nginx.conf && \
    mv /services/nginx.sh /etc/service/nginx/run

# Seafile
WORKDIR /opt/seafile

RUN mkdir -p /opt/seafile/ && cd /opt/seafile/ && \
    wget https://seafile-downloads.oss-cn-shanghai.aliyuncs.com/seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz && \
    tar -zxvf seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz && \
    rm -f seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz

EXPOSE 80

CMD ["/sbin/my_init", "--", "/scripts/enterpoint.sh"]
