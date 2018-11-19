# Elasticsearch with Docker and Kubernetes or OpenShift

Although Elasticsearch has some great documentation about [using Elasticsearch in a Dockerized environment](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html), it focuses mainly on Docker Compose for anything beyond a single instance. Later, @pires has done some great work to get Elasticsearch to play nice with Kubernetes.

This project, inspired by [the work](https://github.com/pires/kubernetes-elasticsearch-cluster) done by @pires, allows you to run your own large-scale Elasticsearch production environment on Kubernetes or Openshift, simplifies the Kubernetes aspect of things a little (amongst others also the elimination of the requirement to run privileged initContainers) and does some extra magic to make various older and newer (latest) versions of Elasticsearch play nice with regards to the introduction and deprecation of certain environment variables.

In the sections below, you'll find out how to build and run this project's Docker image standalone and how to use the included kubernetes files to deploy an n-scale cluster, tested on Kubernetes 1.10+ and OpenShift 3.9.

As of this writing (2018-11-19) these Dockerfiles have been used with Elasticsearch 6.4.3 and 6.5.0.


## Table of Contents

* [Pre-Requisites](#prereqs)
* [Building Docker images](#docker)
* [Deploying on Kubernetes](#kubernetes)
* [Using OpenShift](#openshift)


<a id="prereqs">

## Pre-requisites

You need a reasonably recent version of Docker to build and run the Docker image. To run locally, in standalone mode, without the need to actually serve a large number of requests, you should be able to get away with about 4G of memory and a core or two for computation.

To run on Kubernetes, you need a Kubernetes cluster. I tested with version 1.10 and 1.12 and the Kubernetes services included with OpenShift 3.9. Memory and compute requirements might vary wildly, but to give you an idea: We're running a fairly simple 12 node Elasticsearch cluster with 3 masters, 3 data nodes, 3 ingest notes and 3 client nodes, totalling about 12 cores, 60GB of ram and 100GB of storage.

Finally, I'm assuming a fairly recent modern OS environment where you have the `docker` and `kubectl` commands available via your PATH environment variable and know how to get by using either `cmd.exe`, `powershell`, `ksh` or `bash`.


<a id="docker">

## Building Docker images

Everything is essentially built around a minimal Linux + OpenJDK image, on which we extract the standard Elasticsearch tar distribution, which is installed and started by custom [setup.sh](/scripts/setup.sh) and [run.sh](/scripts/run.sh) scripts.

The [Dockerfile](/Dockerfile) inherits from Red Hat's [redhat-openjdk-18/openjdk18-openshift](https://github.com/jboss-container-images/openjdk) image. Essentially, any image with an OpenJDK of version 8 or higher (yes, Elasticsearch 6.2 and higher can actually run with OpenJDK 9/10/11) and the `bash` and `curl` commands could run this. The advantage of the Red Hat images is that they [promise to keep these updated](https://access.redhat.com/articles/1299013) as oposed to the [state of affairs](https://blog.joda.org/2018/08/java-is-still-available-at-zero-cost.html) with the regular OpenJDK images.

Specifically, Red Hat's "OpenJDK Life Cycle and Support Policy" document mentions: *"Q: Do the lifecycle dates apply to the OpenJDK images available in OpenShift? A: Yes. The lifecycle for OpenJDK 8 applies the the container image available in the Red Hat Container Catalog, and the OpenJDK 11 lifecycle will apply when it is released."*

Alright, without further ado, let's get that standalone Docker image up + running! First off, you should `git clone` this repository somewhere, start your command shell of choice and `cd` in there. Run the following:

 * `docker build -t someorg/elasticsearch .`
 * `docker run -d -p 9200:9200 -p 9300:9300 --rm --name es someorg/elasticsearch`
 * `docker logs -f es` (<ctrl-c> when you've seen enough)
 * `curl http://localhost:9200` (returns the main info json)

And to clean up afterwards:

 * `docker stop es`
 * `docker container purge` (optional, not needed when `--rm` was passed to `docker run`)
 * `docker volume purge` (optional, cleans up the volume entries)
 * `docker rmi someorg/elasticsearch` (removes the previously built image)

If you completed the steps above, congratulations, you ran your first (I'm assuming) Elasticsearch! This instance did not get configured with any of the options that the various environment variables make possible, as the default values of those variables essentially enable a standalone Elasticsearch node with all bells + whistles.

The changing of those environment variables and a few Docker specific settings is what makes it possible for a single Docker image to assume different roles in the Elasticsearch environment and it's this that is key to running this setup in a Kubernetes environment. For more info on that, read on!

<a id="kubernetes">

## Deploying on Kubernetes

On to Kubernetes..


<a id="openshift">

## Using OpenShift

Notes about using OpenShift.
