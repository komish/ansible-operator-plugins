# This Dockerfile defines the base image for the ansible-operator image.
# It is built with dependencies that take a while to download, thus speeding
# up ansible deploy jobs.

FROM registry.access.redhat.com/ubi9/ubi:9.4-1214.1726694543 AS basebuilder

# Install Rust so that we can ensure backwards compatibility with installing/building the cryptography wheel across all platforms
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustc --version

# Copy python dependencies (including ansible) to be installed using Pipenv
COPY images/ansible-operator/Pipfile* ./
# Instruct pip(env) not to keep a cache of installed packages,
# to install into the global site-packages and
# to clear the pipenv cache as well
ENV PIP_NO_CACHE_DIR=1 \
    PIPENV_SYSTEM=1 \
    PIPENV_CLEAR=1
# Ensure fresh metadata rather than cached metadata, install system and pip python deps,
# and remove those not needed at runtime.
RUN set -e && dnf clean all && rm -rf /var/cache/dnf/* \
  && dnf update -y \
  && dnf install -y gcc libffi-devel openssl-devel python3.12-devel \
  && pushd /usr/local/bin && ln -sf ../../bin/python3.12 python3 && popd \
  && python3 -m ensurepip --upgrade \
  && pip3 install --upgrade pip~=23.3.2 \
  && pip3 install pipenv==2023.11.15 \
  && pipenv install --deploy \
  # NOTE: This ignored vulnerability (70612) was detected in jinja2, \
  # but the vulnerability is disputed and may never be fixed. See: \
  #  - https://github.com/advisories/GHSA-f6pv-j8mr-w6rr \
  #  - https://github.com/dbt-labs/dbt-core/issues/10250 \
  #  - https://data.safetycli.com/v/70612/97c/ \
  # NOTE: This ignored vulnerability (71064) was detected in requests, \
  # but the upgraded version doesn't support the use case (protocol we are using).\
  # Ref: https://github.com/operator-framework/ansible-operator-plugins/pull/67#issuecomment-2189164688
  && pipenv check --ignore 70612 --ignore 71064 \
  && dnf remove -y gcc libffi-devel openssl-devel python3.12-devel \
  && dnf clean all \
  && rm -rf /var/cache/dnf

FROM scratch
COPY --from=basebuilder /usr/local/lib64/python3.12/site-packages /cache/usr/local/lib64/python3.12/site-packages
COPY --from=basebuilder /usr/local/lib/python3.12/site-packages /cache/usr/local/lib/python3.12/site-packages
COPY --from=basebuilder /usr/local/bin  /cache/usr/local/bin