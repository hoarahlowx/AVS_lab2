#!/bin/sh
set -eu

install -o root -g root -m 600 \
    /run/local-ssh/ssh_host_ed25519_key \
    /etc/ssh/ssh_host_ed25519_key
install -o root -g root -m 644 \
    /run/local-ssh/ssh_host_ed25519_key.pub \
    /etc/ssh/ssh_host_ed25519_key.pub
install -o lab -g lab -m 700 -d /home/lab/.ssh
install -o lab -g lab -m 600 \
    /run/local-ssh/authorized_keys \
    /home/lab/.ssh/authorized_keys

exec supervisord -n -c /etc/supervisor/conf.d/supervisord.local.conf
