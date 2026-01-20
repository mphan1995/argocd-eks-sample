FROM jenkins/jenkins:lts-jdk17

USER root
ARG DOCKER_GID=999

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     ca-certificates curl git jq python3 python3-venv unzip zip \
  && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
  && apt-get install -y --no-install-recommends docker.io \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${DOCKER_GID} docker || true \
  && usermod -aG docker jenkins

RUN jenkins-plugin-cli --plugins \
  "configuration-as-code workflow-aggregator git" \
  "job-dsl"

USER jenkins
