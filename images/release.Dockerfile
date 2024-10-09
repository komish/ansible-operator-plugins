FROM registry.access.redhat.com/ubi9/ubi:9.4-1214.1726694543 as base
ARG TARGETARCH

# Label this image with the repo and commit that built it, for freshmaking purposes.
ARG GIT_COMMIT=devel
LABEL git_commit=$GIT_COMMIT

RUN mkdir -p /etc/ansible \
  && echo "localhost ansible_connection=local" > /etc/ansible/hosts \
  && echo '[defaults]' > /etc/ansible/ansible.cfg \
  && echo 'roles_path = /opt/ansible/roles' >> /etc/ansible/ansible.cfg \
  && echo 'library = /usr/share/ansible/openshift' >> /etc/ansible/ansible.cfg

RUN set -e && dnf clean all && rm -rf /var/cache/dnf/* \
  && dnf update -y \
  && dnf install -y python3.12 \
  && dnf clean all \
  && rm -rf /var/cache/dnf

COPY images/cache/${TARGETARCH}/usr/local/lib64/python3.12/site-packages /usr/local/lib64/python3.12/site-packages
COPY images/cache/${TARGETARCH}/usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY images/cache/${TARGETARCH}/usr/local/bin /usr/local/bin

ENV TINI_VERSION=v0.19.0
RUN curl -L -o /tini https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TARGETARCH} \
  && chmod +x /tini && /tini --version

# Final image.
FROM base

ENV HOME=/opt/ansible \
    USER_NAME=ansible \
    USER_UID=1001

# Ensure directory permissions are properly set
RUN echo "${USER_NAME}:x:${USER_UID}:0:${USER_NAME} user:${HOME}:/sbin/nologin" >> /etc/passwd \
  && mkdir -p ${HOME}/.ansible/tmp \
  && chown -R ${USER_UID}:0 ${HOME} \
  && chmod -R ug+rwx ${HOME}

WORKDIR ${HOME}
USER ${USER_UID}

COPY ansible-operator /usr/local/bin/ansible-operator

ENTRYPOINT ["/tini", "--", "/usr/local/bin/ansible-operator", "run", "--watches-file=./watches.yaml"]
