#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
client_dir="$project_root/.local-docker/client"
server_dir="$project_root/.local-docker/server"

mkdir -p "$client_dir" "$server_dir"

if [ ! -f "$client_dir/id_ed25519" ] && [ ! -f "$client_dir/id_ed25519.pub" ]; then
    ssh-keygen -q -t ed25519 -N '' -C 'lab-local-client' -f "$client_dir/id_ed25519"
elif [ ! -s "$client_dir/id_ed25519" ] || [ ! -s "$client_dir/id_ed25519.pub" ]; then
    printf '%s\n' 'Incomplete client key pair in .local-docker/client; fix it before continuing.' >&2
    exit 1
fi

if [ ! -f "$server_dir/ssh_host_ed25519_key" ] && [ ! -f "$server_dir/ssh_host_ed25519_key.pub" ]; then
    ssh-keygen -q -t ed25519 -N '' -C 'lab-local-server' -f "$server_dir/ssh_host_ed25519_key"
elif [ ! -s "$server_dir/ssh_host_ed25519_key" ] || [ ! -s "$server_dir/ssh_host_ed25519_key.pub" ]; then
    printf '%s\n' 'Incomplete server host key pair in .local-docker/server; fix it before continuing.' >&2
    exit 1
fi

cp "$client_dir/id_ed25519.pub" "$server_dir/authorized_keys"
awk '{print "ml-trainer-local " $1 " " $2}' \
    "$server_dir/ssh_host_ed25519_key.pub" > "$client_dir/known_hosts"

chmod 700 "$client_dir" "$server_dir"
chmod 600 "$client_dir/id_ed25519" "$server_dir/ssh_host_ed25519_key" "$server_dir/authorized_keys"
chmod 644 "$client_dir/id_ed25519.pub" "$client_dir/known_hosts" "$server_dir/ssh_host_ed25519_key.pub"

printf '%s\n' 'Local Docker SSH keys prepared under .local-docker/. Keep that directory out of version control.'
