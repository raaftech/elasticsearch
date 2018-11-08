#!/usr/bin/env bash

ARCHIVE_URL=$1
CHECKSUM_URL=$2
GNUPG_KEYID=$3
DISCOVERY_SERVICE=$4
PROXY_URL=$5
NO_PROXY=$6

# Check if run as root.
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit 1
fi

# Check arguments passed.
if [ -z "$1" -o -z "$2" -o -z "$3" ]; then
    echo "Some argument wasn't passed. Arguments are as follows:"
    echo "$0 <archive_url> <checksum_url> <gnupg_keyid> <proxy_url> <no_proxy>"
    exit 1
fi

# Enable proxy if requested.
if [ ! -z "$PROXY_URL" ]; then
    export FTP_PROXY="$PROXY_URL"
    export ftp_proxy="$PROXY_URL"
    export HTTPS_PROXY="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    export HTTP_PROXY="$PROXY_URL"
    export http_proxy="$PROXY_URL"
fi
if [ ! -z "$NO_PROXY" ]; then
    export NO_PROXY="$NO_PROXY"
    export no_proxy="$NO_PROXY"
fi

# Install Elasticsearch.
echo "===> Installing Elasticsearch..."

# Add a user for Elasticsearch. Replace jboss user if existing.
if [ ! -z "$(getent passwd jboss)" ]; then
    sed -i.orig "s|jboss|elasticsearch|g" /etc/passwd
    sed -i.orig "s|jboss|elasticsearch|g" /etc/shadow
    sed -i.orig "s|jboss|elasticsearch|g" /etc/group
    sed -i.orig "s|jboss|elasticsearch|g" /etc/gshadow
    sed -i.orig "s|JBoss user|Elasticsearch user|g" /etc/passwd
    sed -i.orig "s|/home/elasticsearch|/elasticsearch|g" /etc/passwd
    cp -rT /home/jboss /elasticsearch
else
    adduser -d /elasticsearch -m -s /sbin/nologin -u 185 -g 0 elasticsearch
fi

# Get the files
curl -o /tmp/elasticsearch.tar.gz -Lskj "$ARCHIVE_URL"
curl -o /tmp/elasticsearch.tar.gz.asc -Lskj "$CHECKSUM_URL"

# Fetch the key for signature validation.
if [ ! -z "$HTTP_PROXY" ]; then
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --keyserver-options "http-proxy=$HTTP_PROXY timeout=10" --recv-keys "${GNUPG_KEYID}" 2> /dev/null
else
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --keyserver-options "timeout=10" --recv-keys "${GNUPG_KEYID}" 2> /dev/null
fi

# Verify file signature and exit if the following command does not exit 0.
gpg --batch --verify /tmp/elasticsearch.tar.gz.asc /tmp/elasticsearch.tar.gz
if [ $? != 0 ]; then
    echo "KEY SIGNATURE VALIDATION FAILED, ABORTING..."
    exit 1
fi

# Unpack the previously fetched and validated archive.
tar xzf /tmp/elasticsearch.tar.gz -C /elasticsearch --strip-components=1

# Replace default scripts with customized ones.
for file in $(find /elasticsearch/custom -type f); do
    target=$(echo $file | sed 's|/custom/|/config/|g')
    mv "$target" "$target.orig"
    mv "$file" "$target"
done
rmdir /elasticsearch/custom

# Clean up installation artifacts.
rm -r "/tmp/elasticsearch.tar.gz.asc" "/tmp/elasticsearch.tar.gz"
mv /tmp/setup.sh /elasticsearch/setup.sh
chmod 755 /elasticsearch/*.sh

# Create a few extra directories and set ownership.
mkdir -p /elasticsearch/config/scripts /elasticsearch/plugins /elasticsearch/data
chown -R elasticsearch:root /elasticsearch
