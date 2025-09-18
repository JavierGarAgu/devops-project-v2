# final runner dockerfile guide  

---

## start FROM amazonlinux:2023  

this line mean the BASE IMAGE.  
we use amazonlinux:2023 because it is the new generation of amazon linux, it is more secure, it have dnf instead of yum, and is optimized for aws.  
why not ubuntu or debian? well because this docker is for AWS ecosystem and we want compatibility.  

---

## ARG VARIABLES  

in the dockerfile we define some ARG. this is like variables that exist only when we build.  

```dockerfile
ARG TARGETPLATFORM
ARG RUNNER_VERSION
ARG RUNNER_CONTAINER_HOOKS_VERSION
ARG CHANNEL=stable
ARG DOCKER_VERSION=24.0.7
ARG DOCKER_COMPOSE_VERSION=v2.23.0
ARG DUMB_INIT_VERSION=1.2.5
ARG RUNNER_UID=1000
ARG DOCKER_GID=1001
```

- TARGETPLATFORM → docker set this automatically (like linux/amd64 or linux/arm64).  
- RUNNER_VERSION → which version of github runner we will install.  
- RUNNER_CONTAINER_HOOKS_VERSION → version of hooks (used for k8s integration).  
- CHANNEL=stable → docker cli channel, usually stable.  
- DOCKER_VERSION → the version of docker cli. here is 24.0.7.  
- DOCKER_COMPOSE_VERSION → version of docker compose plugin.  
- DUMB_INIT_VERSION → version of dumb-init (a init system for containers).  
- RUNNER_UID → user id for the runner user.  
- DOCKER_GID → group id for docker group.  

ARGS are not kept after build, but we can pass them when building with `--build-arg`.  

---

## ENVIRONMENT VARIABLES  

```dockerfile
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
ENV RUNNER_ASSETS_DIR=/runnertmp
ENV HOME=/home/runner
ENV PATH="${PATH}:${HOME}/.local/bin/"
ENV ImageOS=amazonlinux2023
```

- RUNNER_TOOL_CACHE → cache of tools (important when installing actions tool).  
- RUNNER_ASSETS_DIR → temp directory for runner.  
- HOME → default home of runner user.  
- PATH → we extend PATH to include user local bin.  
- ImageOS → define the os type, here amazonlinux2023.  

these ENV stay inside the container when running.  

---

## INSTALL BASIC TOOLS  

```dockerfile
RUN dnf update -y     && dnf install -y         libicu         git         jq         tar         unzip         gzip         wget         sudo         shadow-utils         which         python3         python3-pip         make         gcc         libyaml         unzip         zip         bzip2         sudo         iproute         net-tools         hostname         iputils         procps-ng         which         postgresql15         && alternatives --install /usr/bin/python python /usr/bin/python3 1         && alternatives --install /usr/bin/pip pip /usr/bin/pip3 1         && dnf clean all
```

this block update the system and install a LOT of tools.  
some are DEV TOOLS (gcc, make), some are BASIC TOOLS (wget, tar, unzip), some are DATABASE client (postgresql15).  

we also add alternatives to make `python` point to python3, and `pip` point to pip3.  

this step is important because actions need python3.  

---

## ADD RUNNER USER  

```dockerfile
RUN groupadd -g $DOCKER_GID docker     && useradd -m -u $RUNNER_UID -G docker,wheel runner     && echo "%wheel   ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers     && echo "Defaults env_keep += \"HOME PATH\"" >> /etc/sudoers
```

here we create the USER runner.  
- group docker with gid = $DOCKER_GID.  
- user runner with uid = $RUNNER_UID, and add to groups docker and wheel.  
- wheel group is like sudoers.  
- we also edit sudoers to allow NOPASSWD and keep ENV vars.  

runner will be the default user at the end.  

---

## INSTALL dumb-init  

```dockerfile
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2)     && if [ "$ARCH" = "arm64" ]; then ARCH=aarch64; fi     && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ]; then ARCH=x86_64; fi     && curl -fLo /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH}     && chmod +x /usr/bin/dumb-init
```

dumb-init is a simple init system for docker containers.  
it handle signals correctly (SIGTERM, SIGINT). without it sometimes processes are zombies.  
we detect arch and download correct binary.  

---

## CREATE DIRECTORIES  

```dockerfile
RUN mkdir -p "$RUNNER_ASSETS_DIR" "$RUNNER_TOOL_CACHE"     && chgrp docker "$RUNNER_TOOL_CACHE"     && chmod g+rwx "$RUNNER_TOOL_CACHE"
```

we create directories for runner.  
- runner assets dir.  
- tool cache dir.  
then give permissions to docker group.  

---

## INSTALL GITHUB RUNNER  

```dockerfile
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2)     && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ]; then ARCH=x64; fi     && cd "$RUNNER_ASSETS_DIR"     && curl -fLo runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz     && tar xzf runner.tar.gz     && rm runner.tar.gz
```

here we download github actions runner tarball.  
we untar it in the assets dir.  
this contain bin, config.sh, run.sh, etc.  
this is the core of self hosted runner.  

---

## INSTALL RUNNER CONTAINER HOOKS  

```dockerfile
RUN cd "$RUNNER_ASSETS_DIR"     && curl -fLo runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip     && unzip runner-container-hooks.zip -d ./k8s     && rm runner-container-hooks.zip
```

this is for when we run runner inside kubernetes.  
the hooks integrate with k8s.  

---

## INSTALL DOCKER CLI  

```dockerfile
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2)     && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ]; then ARCH=x86_64; fi     && curl -fLo docker.tgz https://download.docker.com/linux/static/${CHANNEL}/${ARCH}/docker-${DOCKER_VERSION}.tgz     && tar zxvf docker.tgz     && install -o root -g root -m 755 docker/docker /usr/bin/docker     && rm -rf docker docker.tgz
```

we install docker CLI manually, not with dnf.  
this way we control version.  

---

## INSTALL DOCKER COMPOSE CLI PLUGIN  

```dockerfile
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2)     && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ]; then ARCH=x86_64; fi     && mkdir -p /usr/libexec/docker/cli-plugins     && curl -fLo /usr/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${ARCH}     && chmod +x /usr/libexec/docker/cli-plugins/docker-compose     && ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose     && docker compose version
```

we install docker compose plugin.  
now docker compose work with `docker compose` command.  

---

## COPY SCRIPTS AND HOOKS  

```dockerfile
COPY entrypoint.sh startup.sh logger.sh graceful-stop.sh update-status /usr/bin/
COPY docker-shim.sh /usr/local/bin/docker
COPY hooks /etc/arc/hooks/
```

we copy scripts that control runner lifecycle.  
entrypoint, startup, logger, graceful-stop, update-status.  
docker-shim replace docker binary with wrapper.  

---

## INSTALL kubectl  

```dockerfile
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"     && chmod +x kubectl     && mv kubectl /usr/local/bin/
```

we install kubectl binary.  
this let runner run kubectl commands for k8s clusters.  

---

## INSTALL HELM  

```dockerfile
RUN curl -fsSL https://get.helm.sh/helm-v3.18.4-linux-amd64.tar.gz | tar -xz     && mv linux-amd64/helm /usr/local/bin/     && rm -rf linux-amd64
```

we install helm cli.  
helm is package manager for kubernetes.  

---

## FINAL USER AND ENTRYPOINT  

```dockerfile
USER runner
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["entrypoint.sh"]
```

we switch to runner user.  
entrypoint is bash -c, and we run entrypoint.sh.  

this mean when container start, it launch runner entrypoint.  

---

## CONCLUSION  

this dockerfile create a full environment for github actions self-hosted runner.  
it have:  
- amazonlinux 2023  
- runner binaries  
- docker cli + docker compose  
- kubectl + helm  
- dumb-init for signals  
- runner user with sudo and docker group  

with this we can run actions jobs in docker container, also we can connect to k8s.  