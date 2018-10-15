# change slim alpine
FROM oraclelinux:7.5

RUN yum update -y && \
    yum-config-manager --enable ol7_developer_EPEL && \
    yum install -y openssl docker-engine python36 gcc libffi-devel python-devel openssl-devel --enablerepo=ol7_addons ol7_developer_EPEL

RUN yum install -y python-pip && \
    pip install oci-cli

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

WORKDIR /root/

RUN curl -LO https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-18.06.1.ce-3.el7.x86_64.rpm && \
    yum install /root/docker-ce-18.06.1.ce-3.el7.x86_64.rpm -y && \
    rm docker-ce-18.06.1.ce-3.el7.x86_64.rpm

ADD . .