# Thanks https://blog.xmatthias.com/compiling-python-3-6-for-centos-5-11-with-openssl/
# for the major part of this Dockerfile
FROM centos:5

ARG PYINSTALLER_VERSION=3.4
ARG PYTHON_VERSION=3.6

# As centos5 has reached end of life, some manipulation are needed
# to get "yum" behave as expected in the container
# As tlsv1 is refused by vault, we need to change the repo
RUN sed -i -e 's/^#baseurl=/baseurl=/' \
    -e 's/^mirrorlist=/#mirrorlist=/' \
    -e 's!http://mirror.centos.org/centos/$releasever/!http://archive.kernel.org/centos-vault/5.11/!' \
    /etc/yum.repos.d/*.repo && \
    sed -i -e 's/enabled=1/enabled=0/' \
    /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/libselinux.repo /etc/yum/pluginconf.d/fastestmirror.conf && \
    yum -y clean all

RUN yum update -y

# Installing dependencies
RUN yum install -y gcc gcc44 zlib-devel python-setuptools readline-devel wget make perl

# build and install openssl
RUN cd /tmp && wget --no-check-certificate https://www.openssl.org/source/openssl-1.0.2l.tar.gz \
    && tar xzvpf openssl-1.0.2l.tar.gz && cd openssl-1.0.2l \
    && ./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl \
    && sed -i.orig '/^CFLAG/s/$/ -fPIC/' Makefile \
    && make && make test || true && make install

# or you can use "wget https://www.python.org/ftp/python/3.6.8/Python-3.6.8.tgz" here
# but it didnt work for me, so we need to use already downloaded one
COPY ./python-for-docker/Python-3.6.8.tgz /tmp/
COPY entrypoint.sh /entrypoint.sh

# build and install python${PYTHON_VERSION}
RUN tar xzvf /tmp/Python-3.6.8.tgz && cd Python-3.6.8 \
    && ./configure --prefix=/opt/python${PYTHON_VERSION} --enable-shared --with-threads && make altinstall \
    && ln -s /opt/python${PYTHON_VERSION}/bin/python${PYTHON_VERSION} /usr/local/bin/python${PYTHON_VERSION} \
    && ln -s /opt/python${PYTHON_VERSION}/bin/pip${PYTHON_VERSION} /usr/local/bin/pip${PYTHON_VERSION}

ENV LD_LIBRARY_PATH=/opt/python${PYTHON_VERSION}/lib

RUN pip${PYTHON_VERSION} install pyinstaller==$PYINSTALLER_VERSION \
    && rm -rf /tmp/ && chmod +x /entrypoint.sh

RUN mkdir /code
WORKDIR /code

ENTRYPOINT [ "/entrypoint.sh" ]