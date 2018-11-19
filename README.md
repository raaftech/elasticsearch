# Elasticsearch with Docker and Kubernetes or OpenShift

Although Elasticsearch has some great documentation about using Elasticsearch in a Dockerized environment, it focuses mainly on Docker Compose for anything beyond a single instance. Later, @pires has done some great work to get Elasticsearch to play nice with Kubernetes.

This project, inspired by the work done by @pires, allows you to run your own large-scale Elasticsearch production environment on Kubernetes or Openshift, simplifies the Kubernetes aspect of things a little and does some extra magic to make various older and newer (latest) versions of Elasticsearch play nice with regards to the introduction and deprecation of certain environment variables.

In the sections below, you'll find out how to build and run this project's Docker image standalone and how to use the included kubernetes files to deploy an n-scale cluster, tested on Kubernetes 1.10+ and OpenShift 3.9.

## Table of Contents

* [Pre-Requisites](#prereqs)
* [Building Docker images](#docker)
* [Deploying on Kubernetes](#kubernetes)
* [Using OpenShift](#openshift)

<a id="prereqs">

## Pre-requisites

Describe pre-requisites here.

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
