# Setup build arguments
ARG HELM_VERSION
ARG KUBECTL_VERSION
ARG AWS_CLI_VERSION
ARG DEBIAN_VERSION=bookworm-20231120-slim
ARG DEBIAN_FRONTEND=noninteractive

FROM debian:${DEBIAN_VERSION} AS helm
ARG TARGETARCH
ARG HELM_VERSION
RUN apt-get update
# RUN apt-get install --no-install-recommends -y libcurl4=7.74.0-1.3+deb11u7
RUN apt-get install --no-install-recommends -y ca-certificates=20230311
RUN apt-get install --no-install-recommends -y curl=7.88.1-10+deb12u8
RUN apt-get install --no-install-recommends -y gnupg=2.2.40-1.1
RUN apt-get install --no-install-recommends -y unzip=6.0-28
RUN rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
RUN curl --silent --show-error --fail -o get_helm.sh --remote-name https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
RUN chmod 700 get_helm.sh
RUN ./get_helm.sh --version ${HELM_VERSION}

FROM debian:${DEBIAN_VERSION} AS kubectl
ARG TARGETARCH
ARG KUBECTL_VERSION
RUN apt-get update && apt-get install -y \
    curl \
    apt-transport-https \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*
RUN curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl"
RUN curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256"
RUN echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
RUN install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
RUN rm kubectl kubectl.sha256
RUN kubectl version --client

# Install AWS CLI version 2
FROM debian:${DEBIAN_VERSION} AS aws-cli
ARG AWS_CLI_VERSION
RUN apt-get update
RUN apt-get install -y --no-install-recommends ca-certificates=20230311
RUN apt-get install -y --no-install-recommends curl=7.88.1-10+deb12u8
RUN apt-get install -y --no-install-recommends gnupg=2.2.40-1.1
RUN apt-get install -y --no-install-recommends unzip=6.0-28
RUN apt-get install -y --no-install-recommends git=1:2.39.5-0+deb12u1
RUN apt-get install -y --no-install-recommends jq=1.6-2.1
RUN rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
RUN curl --show-error --fail --output "awscliv2.zip" --remote-name "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip"
RUN unzip -u awscliv2.zip
RUN ./aws/install --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin

# Build final image
FROM debian:${DEBIAN_VERSION} AS build
LABEL maintainer="mroberts91@github"
RUN apt-get update
RUN apt-get install -y --no-install-recommends ca-certificates=20230311
RUN apt-get install -y --no-install-recommends git=1:2.39.5-0+deb12u1
RUN apt-get install -y --no-install-recommends jq=1.6-2.1
RUN apt-get install -y --no-install-recommends openssh-client=1:9.2p1-2+deb12u3
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
COPY --from=helm /usr/local/bin/helm /usr/local/bin/helm
COPY --from=kubectl /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=aws-cli /usr/local/bin/ /usr/local/bin/
COPY --from=aws-cli /usr/local/aws-cli /usr/local/aws-cli

RUN groupadd --gid 1001 nonroot \
  # user needs a home folder to store aws credentials
  && useradd --gid nonroot --create-home --uid 1001 nonroot \
  && chown nonroot:nonroot /workspace
USER nonroot

CMD ["bash"]
