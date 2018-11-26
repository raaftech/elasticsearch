# Elasticsearch with Docker and Kubernetes or OpenShift

Although Elasticsearch has some great documentation about [using Elasticsearch in a Dockerized environment](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html), it focuses mainly on Docker Compose for anything beyond a single instance. Later, [@pires](https://github.com/pires) has done [some great work](https://github.com/pires/kubernetes-elasticsearch-cluster) to get Elasticsearch to play nice with Kubernetes.

This project, inspired by [the work](https://github.com/pires/kubernetes-elasticsearch-cluster) done by [@pires](https://github.com/pires), allows you to run your own large-scale Elasticsearch production environment on Kubernetes or Openshift, simplifies the Kubernetes aspect of things a little (amongst others also the elimination of the requirement to run privileged initContainers) and does some extra magic to make various older and newer (latest) versions of Elasticsearch play nice with regards to the introduction and deprecation of certain environment variables.

In the sections below, you'll find out how to build and run this project's Docker image standalone and how to use the included kubernetes files to deploy an n-scale cluster, tested on Kubernetes 1.10+ and OpenShift 3.9.

As of this writing (2018-11-19) these Dockerfiles have been used with Elasticsearch 6.4.3 and 6.5.0.


## Table of Contents

* [Pre-Requisites](#prereqs)
* [Building Docker images](#docker)
* [Deployment using Kubernetes](#kubernetes)
* [Using OpenShift](#openshift)
* [Environment Variables and Arguments](#envargs)


<a id="prereqs">

## Pre-requisites

You need a reasonably recent version of Docker to build and run the Docker image. To run locally, in standalone mode, without the need to actually serve a large number of requests, you should be able to get away with about 4G of memory and a core or two for computation.

To run on Kubernetes, you need a Kubernetes cluster. I tested with version 1.10 and 1.12 and the Kubernetes services included with OpenShift 3.9. Memory and compute requirements might vary wildly, but to give you an idea: We're running a fairly simple 12 node Elasticsearch cluster with 3 masters, 3 data nodes, 3 ingest nodes and 3 client nodes, totalling about 12 cores, 60GB of ram and 100GB of storage.

Finally, I'm assuming a fairly recent modern OS environment where you have the `docker` and `kubectl` commands available via your PATH environment variable and know how to get by using either `cmd.exe`, `powershell`, `ksh` or `bash`.


<a id="docker">

## Building Docker images

Everything is essentially built around a minimal Linux + OpenJDK image, on which we extract the standard Elasticsearch tar distribution, which is installed and started by custom [setup.sh](/scripts/setup.sh) and [run.sh](/scripts/run.sh) scripts.

The [Dockerfile](/Dockerfile) inherits from Red Hat's [redhat-openjdk-18/openjdk18-openshift](https://github.com/jboss-container-images/openjdk) image. Essentially, any image with an OpenJDK of version 8 or higher (yes, Elasticsearch 6.2 and higher can actually run with OpenJDK 9/10/11) and the `bash` and `curl` commands could run this. The advantage of the Red Hat images is that they [promise to keep these updated](https://access.redhat.com/articles/1299013) as oposed to the [state of affairs](https://blog.joda.org/2018/08/java-is-still-available-at-zero-cost.html) with the regular OpenJDK images.

Specifically, Red Hat's "OpenJDK Life Cycle and Support Policy" document mentions: *"Q: Do the lifecycle dates apply to the OpenJDK images available in OpenShift? A: Yes. The lifecycle for OpenJDK 8 applies the the container image available in the Red Hat Container Catalog, and the OpenJDK 11 lifecycle will apply when it is released."*

Alright, without further ado, let's get that standalone Docker image up + running! First off, you should `git clone` this repository somewhere, start your command shell of choice and `cd` into the cloned repository's directory. Run the following:

 * `docker build -t someorg/elasticsearch .`
 * `docker run -d -p 9200:9200 -p 9300:9300 --rm --name es someorg/elasticsearch`
 * `docker logs -f es` (`<ctrl-c>` when you've seen enough)
 * `curl http://localhost:9200` (returns the main info json)

And to clean up afterwards:

 * `docker stop es`
 * `docker container prune` (optional, not needed when `--rm` was passed to `docker run`)
 * `docker volume prune` (optional, cleans up the volume entries)
 * `docker rmi someorg/elasticsearch` (removes the previously built image)
 * `docker rmi registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift` (removes the parent image)

If you completed the steps above, congratulations, you ran your first (I'm assuming) Elasticsearch! This instance did not get configured with any of the options that the various environment variables make possible, as the default values of those variables essentially enable a standalone Elasticsearch node with all bells + whistles.

The changing of those environment variables and a few Docker specific settings is what makes it possible for a single Docker image to assume different roles in the Elasticsearch environment and it's this that is key to running this setup in a Kubernetes environment. For more info on that, read on!

<a id="kubernetes">

## Deployment using Kubernetes

in the [kubernetes](/kubernetes) subdirectory you'll find a selection of yaml files that set up various resources within a Kubernetes environment. In this case, there are four types of resources:

 * route: An HTTP endpoint that exposes the service for the outside world to consume;
 * service: A port definition that defines which ports should be open amongst pods;
 * statefulset: A set of pods that have identity and state associated with them;
 * deployment: A set of pods that have no persistent identity and usually no state;

Essentially, the resources in a Kubernetes environment represent the things you care about when configuring a service on a system: how is the service accessed externally (routes), what ports do the service(s) use when talking to each other (services), which systems have data and identity that should be consistent across multiple lifecycles/restarts (statefulset) and which systems are simply interchangable workers without state or identity I care about (deployments).

The yaml files in the kubernetes directory set up the routes and services and parameterize the Docker image to run in a specific way for each role of an Elasticsearch node in the cluster. If you read the yaml files, you'll see them setting various environment variables in a certain way: this configures the Docker image to assume a certain set of Elasticsearch responsibilities.

When you have your Kubernetes environment set-up and available for interaction with the `kubectl` command, `cd` into the kubernetes subdirectory, take a look at the default sizings in the statefulset and deployment files (In particular, look at the size of the storage claims, the number of cpu cores and the amount of memory assigned) and create your cluster as follows:

 * `kubectl create -f service-es-transport.yaml`
 * `kubectl create -f service-es-http.yaml`
 * `kubectl create -f route-es-http.yaml`
 * `kubectl create -f statefulset-es-master.yaml`
 * `kubectl create -f statefulset-es-data.yaml`
 * `kubectl create -f deployment-es-ingest.yaml`
 * `kubectl create -f deployment-es-client.yaml`

Note that the defaults currently defined in the yaml files are sized for a medium scale real-world deployment; That means about 60Gib of RAM and about 12 cores of CPU available in your cluster. If you're just playing around, feel free to lower these to whatever you think you can get away with. Bear in mind that as a general rule, you need to assign double the amount of ram to a pod compared to the amount of ram you assign to the JVM using the `-Xms` and `-Xmx` parameters. Finally, keep in mind that your persistent storage classes in your Kubernetes might be named differently than the ones mentioned in the yaml files. To check names that would work in your cluster, issue a `kubectl get sc` command which will show the available storage classes to you.

<a id="openshift">

## Using OpenShift

OpenShift v3 and later are based on Kubernetes. OpenShift adds a ton of nice features related to image building and versioning, authentication and isolation and definitely worth to check out. You can read more about OpenShift on the [okd.io](https://okd.io/) site.

OpenShift tries to keep its Kubernetes related parts as compatible as feasibly possible and so you can run this cluster setup on your OpenShift environment by issuing an `oc login` and simply replacing the `kubectl` part of the commands above with `oc`, for examle: `oc create -f service-es-transport.yaml`, etc.


<a id="envargs">

## Environment Variables and Arguments

As mentioned before, the Docker image can be parameterized at build and runtime with various arguments and environment variables. Arguments (the `ARG` keyword in a Dockerfile) are things which exist at build time (i.e, during `docker build`). Environment variables exist during build and runtime (i.e, also during `docker run`).


### ARG PROXY_URL

Default: `none`

Specifies a proxy url that can be used during build time to make curl use a proxy when fetching the neccessary artifacts during a `setup.sh` run. Example value: `http://proxy.example.com:8080`.

### ARG NO_PROXY

Default: `none`

Allows one to explicitly specify a comma-separated list of IP addresses and (partial) hostnames which should not be accessed using a proxy. You can partially specify a hostname as follows: `.example.com`, which would match all hosts ending in `.example.com`. Example value: `localhost,127.0.0.1,.example.com`.

### ENV HOME

Default: `/elasticsearch`

The home directory of the Elasticsearch installation. Don't change this, will definitely give unexpected results if changed.


### ENV PATH

Default: `/elasticsearch/bin:$PATH`

The default path for the image, prefixed with the bin directory of the Elasticsearch installation. If you change this, be sure to keep the `/elasticsearch/bin` directory as a first entry.


### ENV ES_ALLOW_MMAPFS

Default: `true`

Since Elasticsearch 6.5.0, does not work on versions prior to 6.5.0. Allows or disallows `mmapfs` as an index backend. Can be set to `false` when you don't have root permissions on the underlying platform to set `vm.max_map_count` to be at least `262144`. Be sure to also set `ES_INDEX_STORE_TYPE` to `niofs` or `simplefs`.

When Elasticsearch boots up and detects it is not just running on localhost, it will invoke the bootchecks mechanism to make sure various things are sanely configured. One of those checks is for the value of `vm.max_map_count` to be at least `262144`. Prior to Elasticsearch version 6.5.0, there was no way to avoid that bootcheck, not even when you'd set `index.store.type` to anything other than `mmapfs`; the reason for that is that `index.store.type` simply defines a default and can be overridden during index creation.

The value of `vm.max_map_count` is only relevant when `index.store.type` is `mmapfs` and when `node.store.allow_mmapfs` is `true` which is the resulting default on at least Linux and macOS when `index.store.type` is set to `fs` or `mmapfs`.


### ENV ES_JAVA_OPTS

Default: `-Xms1g -Xmx1g -XX:ParallelGCThreads=1`

Can be used to set a selection of JVM parameters. The default as shown above sets the minimum and maximum heap sizes to an equal amount, disabling the dynamic growth and shrink functions within the JVM which can incur a performance penalty and sets the ParallelGCThreads option to 1, guaranteeing at most 1 concurrent garbage collection threads running at any given moment. This last setting is specific to the CMS (ConcurrentMarkSweep) garbage collector which is configured in the `jvm.options` configuration file.

Note that these settings can also be set in the jvm.options file, but setting them here allows you to override them on a per-instance basis.


### ENV ES_ARCHIVE_BASEURL

Default: `https://artifacts.elastic.co/downloads/elasticsearch`

Controls where `setup.sh` retrieves its installation payloads from. When you specify a SNAPSHOT version of Elasticsearch in `ES_VERSION`, you need to set this to `https://snapshots.elastic.co/downloads/elasticsearch`. For regular stable releases, the default is fine.


### ENV ES_ARCHIVE_KEYID

Default: `46095ACC8548582C1A2699A9D27D666CD88E42B4`

The public key id which Elastic Co uses to sign their released artifacts. The `setup.sh` script uses this id and the downloaded hash file to retrieve the associated public key from a PGP keyserver and afterwards determine if the downloaded artifact is valid.


### ENV ES_CLUSTER_NAME

Default: `elasticsearch-default`

The name of your Elasticsearch instance.


### ENV ES_DISCOVERY_SERVICE

Default: `none`

This effectively sets `discovery.zen.ping.unicast.hosts` in the Elasticsearch configuration file. [Zen Discovery](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery-zen.html) is the default built-in discovery module for cluster nodes in Elasticsearch. The Kubernetes configuration files set this value to `es-transport` which is the name of the Kubernetes Service that defines an inter-node transport port 9300 for nodes to talk to each other.

Note: the documentation from Elastic Co tells us that this value can be a list of hosts. I surmise that Kubernetes actually creates a DNS entry for a service name and that would resolve to multiple hosts (DNS round-robin style), but unsure of this (Edit: The Kubernetes Documentation on Services seems to indeed indicate that that's the case).


### ENV ES_HTTP_CORS_ALLOW_ORIGIN

Default: `*`

Which origins to allow (see `ES_HTTP_CORS_ENABLE` below for more details on cross-origin resource sharing). If you prepend and append a `/` to the value, this will be treated as a regular expression, allowing you to support HTTP and HTTPs. for example using `/https?:\/\/localhost(:[0-9]+)?/` would return the request header appropriately in both cases.

The default in our case: `*` is a valid value but is considered a security risk as your Elasticsearch instance is open to cross origin requests from anywhere and it is strongly suggested you change this.

Also check out Elastic Co's page documenting the [HTTP Module](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-http.html#modules-http) for more details.


### ENV ES_HTTP_CORS_ENABLE

Default: `true`

Enable or disable cross-origin resource sharing, i.e. whether a client on another origin can execute requests against Elasticsearch. For more details, see the rather excellent Wikipedia page on [Cross-Origin Resource Sharing](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing).


### ENV ES_INDEX_STORE_TYPE

Default: `fs`

The default leaves the selection of an index store type implementation to Elasticsearch. On Linux and macOS, that would be `mmapfs` and on Windows it's `simplefs`.

Note that this value simply specifies the default index store type and does not actually restrict the specification of index store types at index creation time. Also see `ES_ALLOW_MMAPFS`.

See the reference documentation page on the [Store Module](https://www.elastic.co/guide/en/elasticsearch/reference/current/index-modules-store.html) for more detailed information about the possible values here.


### ENV ES_MAX_LOCAL_STORAGE_NODES

Default: `1`

This setting limits how many Elasticsearch processes can interact with a local data path and should in almost all cases be set to `1`. If you're running multiple Elasticsearch processes locally, and you want them to all access the same data path, you can increase this number. Should usually not be higher than `1` in production. Check the [Node Data Path Settings](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html#_node_data_path_settings) in the Elasticsearch reference guide for more details.


### ENV ES_MEMORY_LOCK

Default: `false`

From the Elasticsearch reference guide: When the JVM does a major garbage collection it touches every page of the heap. If any of those pages are swapped out to disk they will have to be swapped back in to memory. That causes lots of disk thrashing that Elasticsearch would much rather use to service requests.

There are several ways to configure a system to disallow swapping. One way is by requesting the JVM to lock the heap in memory through `mlockall` (Unix) or `virtuallock` (Windows). This is done via the Elasticsearch setting `bootstrap.memory_lock`.

However, there are cases where this setting can be passed to Elasticsearch but Elasticsearch is not able to lock the heap (e.g., if the elasticsearch user does not have `memlock unlimited`). The memory lock check verifies that if the bootstrap.memory_lock setting is enabled and that the JVM was successfully able to lock the heap.

The default in our case is `false` which disables the check. If you know you have `memlock unlimited` you can set this value to `true`


### ENV ES_NETWORK_HOST

Default: `_site_`

Elasticsearch will bind to this hostname or IP address and publish (advertise) this host to other nodes in the cluster. Accepts an IP address, hostname, a special value, or an array of any combination of these.

Special values are: `_[networkInterface]_` (addresses of a network interface, for example `_en0_`), `_local_` (any loopback addresses on the system, for example `127.0.0.1`), `_site_` (any site-local addresses on the system, for example `192.168.0.1`, `172.16.0.1` or `10.0.0.1`) and `_global_` (any globally-scoped addresses on the system, for example `8.8.8.8`).


### ENV ES_NODE_DATA

Default: `true`

Will this Elasticsearch instance fulfill a [Data Node](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html) role?


### ENV ES_NODE_INGEST

Default: `true`

Will this Elasticsearch instance fulfill an [Ingest Node](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html) role?


### ENV ES_NODE_MASTER

Default: `true`

Will this Elasticsearch instance fulfill a [Master Node](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html) role?


### ENV ES_NUMBER_OF_MASTERS

Default: `1`

Sets `discovery.zen.minimum_master_nodes`. This is the minimum number of master eligible nodes that need to join a newly elected master in order for an election to complete and for the elected node to accept its masterness.

The same setting also controls the minimum number of active master eligible nodes that should be a part of any active cluster. If this requirement is not met the active master node will step down and a new master election will begin.

This setting must be set to a quorum of your master eligible nodes ((*master_eligible_nodes/2)+1*). It is recommended to avoid having only two master **eligible** nodes, since a quorum of two is two. Therefore, a loss of either master eligible node will result in an inoperable cluster. In practice, three master eligible nodes and a minimum_master_nodes of two is a good option.

Be sure to read the documentation on [Avoiding Split Brain](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html#split-brain).


### ENV ES_REPO_LOCATIONS

Default: `none`


### ENV ES_SHARD_ALLOCATION_AWARENESS

Default: `none`


### ENV ES_SHARD_ALLOCATION_AWARENESS_ATTR

Default: `none`


### ENV ES_VERSION

Default: `6.5.0`

