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

Explain Docker's part in all this, I.e:

 * `docker build -t raaftech/elasticsearch .`
 * `docker run -d -p 9200:9200 -p 9300:9300 --name elasticsearch raaftech/elasticsearch`
 * `docker logs -f elasticsearch`
 * `curl http://localhost:9200`


<a id="kubernetes">

## Deploying on Kubernetes

On to Kubernetes..


<a id="openshift">

## Using OpenShift

Notes about using OpenShift.
