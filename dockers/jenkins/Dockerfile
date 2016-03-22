FROM jenkins:latest

ENV DEBIAN_FRONTEND noninteractive

USER root
RUN apt-get update \
      && apt-get install -y sudo \
      && rm -rf /var/lib/apt/lists/*
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

RUN (curl -sSL https://get.docker.com/ | sh) && (rm -rf /var/lib/apt/lists/*)

ENV DOCKER_HOST tcp://docker:2375

USER jenkins
COPY plugins.txt /usr/share/jenkins/plugins.txt
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/plugins.txt