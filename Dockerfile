FROM registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift

# Set the main work directory.
WORKDIR /elasticsearch

# Set privileged user for installation and setup steps ( but don't
# forget to set USER to non-privileged before CMD/ENTRYPOINT part).
USER 0

# Optional argument for handling builds on proxified locations.
ARG PROXY_URL=""
ARG NO_PROXY=""

# Environment variables for Elasticsearch (Note that ES_JAVA_OPTS complements
# options specified in the config/jvm.options file).
ENV HOME="/elasticsearch" \
    PATH="/elasticsearch/bin:$PATH" \
    ES_ALLOW_MMAPFS="true" \
    ES_JAVA_OPTS="-XX:InitialRAMPercentage=80.0 -XX:MaxRAMPercentage=80.0 -XX:ParallelGCThreads=1" \
    ES_ARCHIVE_BASEURL="https://artifacts.elastic.co/downloads/elasticsearch" \
    #ES_ARCHIVE_BASEURL="https://snapshots.elastic.co/downloads/elasticsearch" \
    ES_ARCHIVE_KEYID="46095ACC8548582C1A2699A9D27D666CD88E42B4" \
    ES_CLUSTER_NAME="elasticsearch-default" \
    ES_DISCOVERY_SERVICE="" \
    ES_HTTP_CORS_ALLOW_ORIGIN="*" \
    ES_HTTP_CORS_ENABLE="true" \
    # https://github.com/elastic/elasticsearch/issues/29773
    #ES_INDEX_AUTO_CREATE=".kibana*,.logstash*,.management*,.monitoring*,.security*,.triggered_watches*,.watcher-history*,.watches*" \
    ES_INDEX_AUTO_CREATE="true" \
    ES_INDEX_STORE_TYPE="fs" \
    ES_MAX_LOCAL_STORAGE_NODES="1" \
    ES_MEMORY_LOCK="false" \
    ES_NETWORK_HOST="_site_" \
    ES_NODE_DATA="true" \
    ES_NODE_INGEST="true" \
    ES_NODE_MASTER="true" \
    ES_NUMBER_OF_MASTERS="1" \
    ES_REPO_LOCATIONS="" \
    ES_SHARD_ALLOCATION_AWARENESS_ENABLED="false" \
    ES_SHARD_ALLOCATION_AWARENESS_ATTRIBUTE_KEY="" \
    ES_SHARD_ALLOCATION_AWARENESS_ATTRIBUTE_VALUE="" \
    ES_VERSION="6.7.1"
    #ES_VERSION="7.0.0-SNAPSHOT"

# Separate environment block due to usage of previously set environment variables.
ENV ES_ARCHIVE_TARBALL="${ES_ARCHIVE_BASEURL}/elasticsearch-${ES_VERSION}.tar.gz" \
    ES_ARCHIVE_CHECKSUM="${ES_ARCHIVE_BASEURL}/elasticsearch-${ES_VERSION}.tar.gz.asc"

# Image labels for Kubernetes and OpenShift.
LABEL   architecture="x86_64" \
        io.k8s.description="Elasticsearch" \
        io.k8s.display-name="Elasticsearch $ES_VERSION" \
        io.openshift.expose-services="9200:https, 9300:https" \
        io.openshift.source-repo-url="https://github.com/raaftech/elasticsearch" \
        io.openshift.tags="logging,elk,elasticsearch" \
        License="Apache-2.0" \
        maintainer="RAAF Technology <info@raaf.tech>" \
        name="elasticsearch" \
        vendor="Elastic" \
        version="v$ES_VERSION"


# Copy the Elasticsearch customized configuration files.
COPY config /elasticsearch/custom

# Copy the Elasticsearch run script.
COPY scripts/run.sh /elasticsearch/run.sh

# Copy the Elasticsearch setup script.
COPY scripts/setup.sh /tmp/setup.sh

# Set correct ownership.
RUN chown -R 185:0 /elasticsearch

# Run setup script.
RUN chmod +x /tmp/setup.sh && /tmp/setup.sh ${ES_ARCHIVE_TARBALL} ${ES_ARCHIVE_CHECKSUM} ${ES_ARCHIVE_KEYID} ${ES_DISCOVERY_SERVICE} ${PROXY_URL} ${NO_PROXY}

# Remove dangling home.
RUN rm -rf /home

# Switch to the previously created, non-privileged user.
USER 185

# Volumes for Elasticsearch data and logs.
VOLUME ["/elasticsearch/data", "/elasticsearch/logs"]

# Expose the API and node inter-traffic ports.
EXPOSE 9200 9300

CMD ["/elasticsearch/run.sh"]
