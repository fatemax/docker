#!/bin/bash
set -e

ARCH=armel
ARCH2=armv7
DOCKER_VERSION=24.0.5
COMPOSE_VERSION=2.20.2
DOCKER_DIR=/volume1/@docker

echo "Downloading docker $DOCKER_VERSION-$ARCH"
curl "https://download.docker.com/linux/static/stable/$ARCH/docker-$DOCKER_VERSION.tgz" | tar -xz -C /usr/local/bin --strip-components=1

echo "Creating docker working directory $DOCKER_DIR"
mkdir -p "$DOCKER_DIR"

echo "Creating docker.json config file"
mkdir -p /usr/local/etc/docker
cat <<EOT > /usr/local/etc/docker/docker.json
{
  "storage-driver": "vfs",
  "iptables": false,
  "bridge": "none",
  "data-root": "$DOCKER_DIR"
}
EOT

echo "Creating docker startup script"
cat <<'EOT' > /usr/local/etc/rc.d/docker.sh
#!/bin/sh
# Start docker daemon

NAME=dockerd
PIDFILE=/var/run/$NAME.pid
DAEMON_ARGS="--config-file=/usr/local/etc/docker/docker.json --pidfile=$PIDFILE"

case "$1" in
    start)
        echo "Starting docker daemon"
        # ulimit -n 4096  # needed for influxdb (uncomment if your limit is lower)
        /usr/local/bin/dockerd $DAEMON_ARGS &
        ;;
    stop)
        echo "Stopping docker daemon"
        kill $(cat $PIDFILE)
        ;;
    *)
        echo "Usage: "$1" {start|stop}"
        exit 1
esac
exit 0
EOT

chmod 755 /usr/local/etc/rc.d/docker.sh

echo "Creating docker group"
egrep -q docker /etc/group || synogroup --add docker root

echo "Installing docker compose $COMPOSE_VERSION"
curl -SL "https://github.com/docker/compose/releases/download/v$COMPOSE_VERSION/docker-compose-linux-$ARCH2" \
     --create-dirs -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
chgrp -R docker /usr/local/lib/docker

echo "Starting docker"
/usr/local/etc/rc.d/docker.sh start

echo "Done.  Please add your user to the docker group in the Synology GUI and reboot your NAS."
