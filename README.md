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
 * `docker logs -f es` (<ctrl-c> when you've seen enough)
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

The yaml files in the kubernetes directory set up the routes and services and parameterize the Docker image to run in a specific way for each role of an Elasticsearch node in the cluster. If you read the yaml files, you'll see them setting various environment variables in a certain way: this configures the Docker image to assume a certain set of elasticsearch responsibilities.

When you have your Kubernetes environment set-up and available for interaction with the `kubectl` command, `cd` into the kubernetes subdirectory, take a look at the default sizings in the statefulset and deployment files (In particular, look at the size of the storage claims, the number of cpu cores and the amount of memory assigned) and create your cluster as follows:

 * `kubectl create -f service-es-transport.yaml`
 * `kubectl create -f service-es-http.yaml`
 * `kubectl create -f route-es-http.yaml`
 * `kubectl create -f statefulset-es-master.yaml`
 * `kubectl create -f statefulset-es-data.yaml`
 * `kubectl create -f deployment-es-ingest.yaml`
 * `kubectl create -f deployment-es-client.yaml`

Note that the defaults currently defined in the yaml files are sized for a medium scale real-world deployment; That means about 60Gib of RAM and about 12 cores of CPU available in your cluster. If you're just playing around, feel free to lower these to whatever you think you can get away with. Bear in mind that as a general rule, you need to assign double the amount of ram to a pod compared to the amount of ram you assign to the JVM using the `-Xms` and `-Xmx` parameters.

<a id="openshift">

## Using OpenShift

Notes about using OpenShift.
