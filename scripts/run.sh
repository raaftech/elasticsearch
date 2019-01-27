#!/bin/sh

echo "Starting Elasticsearch ${ES_VERSION}"

# List the directories recursively and pause.
echo "* Mount output: "
mount
echo ""

echo "Listing output:"
ls -lR "$HOME"
echo ""

sleep 60

# (Try to) Make sure that we own our data and pause.
echo "Attempting to take ownership:"
chown -R elasticsearch:elasticsearch "$HOME"
echo ""

sleep 60


# Handle discovery service setting. When unset, take out the
# ping.unicast.hosts setting. Usually unset when running
# standalone in Docker directly but needed by Kubernetes.
if [ -z "$ES_DISCOVERY_SERVICE" ]; then
    cat "$HOME/config/elasticsearch.yml" | grep -v '^.*ping.unicast.hosts:.*$' > "/tmp/elasticsearch.yml"
    mv "/tmp/elasticsearch.yml" "$HOME/config/elasticsearch.yml"
fi

# Rewrite ES_NODE_NAME to HOSTNAME if the former is unset, which
# is usually the case when running standalone in Docker directly.
# In Kubernetes, one usually sets ES_NODE_NAME to metadata.name.
if [ -z "$ES_NODE_NAME" ]; then
    ES_NODE_NAME="$HOSTNAME"
    cat "$HOME/config/elasticsearch.yml" | sed 's|\${ES_NODE_NAME}|\${HOSTNAME}|g' > "/tmp/elasticsearch.yml"
    mv "/tmp/elasticsearch.yml" "$HOME/config/elasticsearch.yml"
fi

# If version is 6.5.0 or higher, we allow setting of
# node.store.allow_mmapfs and we adjust the log pattern format.
ES_VERSION_CONCAT=$(echo $ES_VERSION | sed -e 's|[a-z]||g' -e 's|[A-Z]||g' -e 's|\.||g' -e 's|_||g' -e 's|\-||g' | cut -c 1-3)
if (( $ES_VERSION_CONCAT < 650 )); then
    # Not 6.5+, take out 'store:' line.
    cat "$HOME/config/elasticsearch.yml" | grep -v '^.*store:.*$' > "/tmp/elasticsearch.yml"
    mv "/tmp/elasticsearch.yml" "$HOME/config/elasticsearch.yml"

    # Not 6.5+, take out 'allow_mmapfs:' line.
    cat "$HOME/config/elasticsearch.yml" | grep -v '^.*allow_mmapfs:.*$' > "/tmp/elasticsearch.yml"
    mv "/tmp/elasticsearch.yml" "$HOME/config/elasticsearch.yml"

    # Not 6.5+, take out '[%node_name]' element.
    cat "$HOME/config/log4j2.properties" | sed 's|\[%node_name\]%marker |%marker|g' > "/tmp/log4j2.properties"
    mv /tmp/log4j2.properties "$HOME/config/log4j2.properties"
fi

# Allow for memlock if enabled.
if [ "${ES_MEMORY_LOCK}" == "true" ]; then
    ulimit -l unlimited
fi

# Create a temporary folder for Elasticsearch ourselves,
# see: https://github.com/elastic/elasticsearch/pull/27659
export ES_TMPDIR="$(mktemp -d -t elasticsearch.XXXXXXXX)"

# Prevent "Text file busy" errors.
sync

if [ ! -z "${ES_PLUGINS_INSTALL}" ]; then
    OLDIFS="${IFS}"
    IFS=","
    for plugin in ${ES_PLUGINS_INSTALL}; do
        if ! "${BASE}"/bin/elasticsearch-plugin list | grep -qs ${plugin}; then
            until "${BASE}"/bin/elasticsearch-plugin install --batch ${plugin}; do
                echo "Failed to install ${plugin}, retrying in 3s"
                sleep 3
            done
        fi
    done
    IFS="${OLDIFS}"
fi

if [ "${ES_SHARD_ALLOCATION_AWARENESS_ENABLED}" == "true" ]; then
    # This could map to a file like  /etc/hostname => /dockerhostname. If it's
    # a file, replace the current path specification with the last non-empty,
    # not-beginning-with-a-comment-character line of that file, filter out any
    # spaces and limit the string length to the first 16 characters.
    if [ -f "${ES_SHARD_ALLOCATION_AWARENESS_ATTRIBUTE_VALUE}" ]; then
        ES_SHARD_ALLOCATION_AWARENESS_ATTRIBUTE_VALUE="$(
            cat "${ES_SHARD_ALLOCATION_AWARENESS_ATTRIBUTE_VALUE}" |
            sed '/^[[:space:]]*$/d' |
            sed '/^#/ d' |
            tail -n1 |
            sed 's/[[:space:]]//g' |
            cut -c1-16
        )"
    fi

    # Rewrite the node name by prefixing it with the attribute value.
    ES_NODE_NAME="${ES_SHARD_ALLOCATION_AWARENESS_ATTRIBUTE_VALUE}-${ES_NODE_NAME}"

    # Add the entry to the configuration file.
    echo "node.attr.${ES_SHARD_ALLOCATION_AWARENESS_ATTRIBUTE_KEY}: ${ES_SHARD_ALLOCATION_AWARENESS_ATTRIBUTE_VALUE}" >> $HOME/config/elasticsearch.yml

    if [ "$ES_NODE_MASTER" == "true" ]; then
        echo "cluster.routing.allocation.awareness.attributes: ${ES_SHARD_ALLOCATION_AWARENESS_ATTRIBUTE_KEY}" >> "${BASE}"/config/elasticsearch.yml
    fi
fi

export ES_NODE_NAME

# Remove x-pack-ml module.
rm -rf /elasticsearch/modules/x-pack/x-pack-ml
rm -rf /elasticsearch/modules/x-pack-ml

# Run!
if [[ $(whoami) == "root" ]]; then
    if [ ! -d "/data/data/nodes/0" ]; then
        echo "Changing ownership of /data folder"
        chown -R elasticsearch:elasticsearch /data
    fi
    exec su-exec elasticsearch $HOME/bin/elasticsearch $ES_EXTRA_ARGS
else
    # The container's first process is not running as 'root',
    # it does not have the rights to chown. However, we may
    # assume that it is being ran as 'elasticsearch', and that
    # the volumes already have the right permissions. This is
    # the case for Kubernetes, for example, when 'runAsUser: 1000'
    # and 'fsGroup:100' are defined in the pod's security context.
    "${BASE}"/bin/elasticsearch ${ES_EXTRA_ARGS}
fi
