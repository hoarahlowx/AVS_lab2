FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-client \
        openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && install -d -o vscode -g vscode -m 0700 /home/vscode/.ssh \
    && printf '%s\n' \
        'PermitRootLogin no' \
        'MaxAuthTries 3' \
        'PasswordAuthentication no' \
        'PubkeyAuthentication yes' \
        'AuthorizedKeysFile .ssh/authorized_keys' \
        'AllowUsers vscode' \
        > /etc/ssh/sshd_config.d/lab.conf \
    && chmod 0644 /etc/ssh/sshd_config.d/lab.conf
