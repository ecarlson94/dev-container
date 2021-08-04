FROM ruby:3.0.2-alpine3.14
MAINTAINER Eric Carlson
LABEL maintainer "Eric Carlson <e.carlson94@gmail.com>"
LABEL org.opencontainers.image.source https://github.com/ecarlson94/userspace

ARG user=walawren
ARG group=wheel
ARG uid=1000
ARG dotfiles=dotfiles.git
ARG userspace=userspace.git
ARG vcsprovider=github.com
ARG vcsowner=ecarlson94
ARG azurecliversion=2.26.1
ARG nvmversion=0.38.0
ARG nodeversion=14

USER root

ENV PYTHONUNBUFFERED=1

RUN \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk upgrade --no-cache \
    && apk add --update --no-cache \
        sudo \
        autoconf \
        libtool \
        automake \
        ncurses \
        nasm \
        ca-certificates \
        libressl \
        git git-doc \
        python2 \
        python3 \
        python3-dev \
        py3-pip \
        perl \
        openssh \
        bash \
        bash-completion \
        cmake \
        ctags \
        file \
        curl \
        build-base \
        gcc \
        coreutils \
        wget \
        gnupg-scdaemon \
        pcsc-lite \
        gnupg \
        neovim \
        zsh \
        fontconfig \
        ripgrep \
        terraform \
        tmux \
        docker \
        docker-compose \
        less \
        go \
    && ln -sf python3 /usr/bin/python \
    && python3 -m ensurepip \
    && pip3 install --no-cache --upgrade pip setuptools

# Install Azure CLI
RUN \
    apk add --no-cache curl tar openssl jq \
    && apk add --virtual=build gcc libffi-dev musl-dev openssl-dev make python3-dev \
    && pip3 install virtualenv \
    && python3 -m virtualenv /azure-cli \
    && /azure-cli/bin/python -m pip --no-cache-dir install azure-cli==${azurecliversion} \
    && printf "#!/usr/bin/env sh \
      \n\n \
      /azure-cli/bin/python -m azure.cli \"\$@\"" > /usr/bin/az \
    && chmod +x /usr/bin/az

# Create user to run commands as
RUN \
    echo "%${group} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && adduser -D -G ${group} ${user} \
    && addgroup ${user} docker

COPY ./ /home/${user}/.userspace/
RUN \
    git clone --recursive https://${vcsprovider}/${vcsowner}/${dotfiles} /home/${user}/.dotfiles \
    && chown -R ${user}:${group} /home/${user}/.dotfiles \
    && cd /home/${user}/.dotfiles \
    && git remote set-url origin git@${vcsprovider}:${vcsowner}/${dotfiles} \
    && chown -R ${user}:${group} /home/${user}/.userspace \
    && cd /home/${user}/.userspace \
    && git remote set-url origin git@${vcsprovider}:${vcsowner}/${userspace}

USER ${user}

# Install NVM, Node, and NPM
RUN \
    sudo apk add --no-cache bash \
    && sudo curl -o- https://raw.githubusercontent.com/creationix/nvm/v${nvmversion}/install.sh | bash \
    && . $HOME/.nvm/nvm.sh \
    && nvm install ${nodeversion} \
    && nvm alias default ${nodeversion} \
    && npm install -g yarn \
    && sudo apk del bash

ARG ghVersion=1.7.0
RUN \
    cd $HOME/.dotfiles \
    && ./install-profile linux \
    && cd $HOME/.userspace \
    && if [ ! -d ~/.fzf ]; then git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf; fi && ~/.fzf/install --key-bindings --completion --no-update-rc \
    && gem install tmuxinator \
    && go get -u github.com/boyter/scc/ \
    && wget -O ./ghcli.tar.gz https://github.com/cli/cli/releases/download/v${ghVersion}/gh_${ghVersion}_linux_amd64.tar.gz \
    && mkdir ghcli \
    && tar -xvf ghcli.tar.gz -C ./ghcli \
    && sudo cp ghcli/gh_${ghVersion}_linux_amd64/bin/gh /usr/bin \
    && rm -rf ghcli \
    && rm ghcli.tar.gz \
    && ./install-standalone \
        zsh-dependencies \
        zsh-plugins \
        vim-dependencies \
        vim-plugins \
        tmux-plugins \
        gnupg-configure

ENV HISTFILE=/config/.zsh_history

CMD [ ]
