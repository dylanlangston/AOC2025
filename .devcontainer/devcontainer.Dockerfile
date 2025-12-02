FROM mcr.microsoft.com/devcontainers/base:debian as base

# Install General Dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
      && apt-get -y install --no-install-recommends ca-certificates bash curl unzip xz-utils make git git-lfs pkg-config netcat-traditional zip

# Clean Image
RUN apt-get clean && rm -rf /var/cache/apt/* && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

# Important we change to the vscode user that the devcontainer runs under
USER vscode
WORKDIR /home/vscode

# Install ZVM - https://github.com/tristanisham/zvm
RUN curl --proto '=https' --tlsv1.3 -sSf https://raw.githubusercontent.com/tristanisham/zvm/master/install.sh | bash
RUN echo "# ZVM" >> $HOME/.bashrc
RUN echo export ZVM_INSTALL="$HOME/.zvm" >> $HOME/.bashrc
RUN echo export PATH="\$PATH:\$ZVM_INSTALL/bin" >> $HOME/.bashrc
RUN echo export PATH="\$PATH:\$ZVM_INSTALL/self" >> $HOME/.bashrc

# Install ZIG & ZLS
RUN $HOME/.zvm/self/zvm i --zls master

# Install UV
RUN curl -L --proto '=https' --tlsv1.3 -sSf https://astral.sh/uv/install.sh | sh
RUN $HOME/.local/bin/uv python install --default python3.11

# Install Bun
RUN curl -L --proto '=https' --tlsv1.3 -sSf https://bun.sh/install | bash

# Install git lfs
RUN git lfs install