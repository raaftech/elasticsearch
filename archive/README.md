# kubernetes-elasticsearch-cluster
Elasticsearch (6.4.3) cluster on top of Kubernetes made easy.

### Table of Contents

* [Pre-Requisites](#pre-requisites)
* [Building images](#build-images)
* [Deploying the cluster](#deploy)
* [Access the service](#access-the-service)
* [Pod anti-affinity](#pod-anti-affinity)
* [Install plug-ins](#plugins)
* [Kibana](#kibana)
* [FAQ](#faq)


## Abstract

[Elasticsearch best-practices recommend to separate nodes in three roles](https://www.elastic.co/guide/en/elasticsearch/reference/6.2/modules-node.html):

* `Master` nodes - intended for clustering management only, no data, no HTTP API
* `Data` nodes - intended for client usage and data
* `Ingest` nodes - intended for document pre-processing during ingestion

Given this, I'm going to demonstrate how to provision a production grade scenario consisting of 3 master, 2 data and 2 ingest nodes.

<a id="pre-requisites">

## Pre-requisites

* Kubernetes 1.11.x (tested with v1.11.2 on top of [Vagrant + CoreOS](https://github.com/pires/kubernetes-vagrant-coreos-cluster)).
* `kubectl` configured to access the Kubernetes API.

<a id="build-images">

## Building images

Write this section.

<a id="deploy">

## Deploying the cluster

We're going to run  elasticsearch data and master pods as a [`StatefulSet`](https://kubernetes.io/docs/concepts/abstractions/controllers/statefulsets/), using storage provisioned using a [`StorageClass`](http://blog.kubernetes.io/2016/10/dynamic-provisioning-and-storage-in-kubernetes.html).

### Storage

The [`es-data-stateful.yaml`](es-data-stateful.yaml) and [`es-master-stateful.yaml`](es-master-stateful.yaml) files contain `volumeClaimTemplates` sections which request 2GB volume for each master node, and 12GB volume for each data node. This is plenty of space for a demonstration cluster, but will fill up quickly under moderate to heavy load. Consider modifying the disk size to your needs.

### Deploy
These brief instructions show a deployment using the `StatefulSet` and `StorageClass`.

```
kubectl create -f es-discovery-svc.yaml
kubectl create -f es-svc.yaml

kubectl create -f es-master-svc.yaml
kubectl create -f es-master-stateful.yaml
kubectl rollout status -f es-master-stateful.yaml

kubectl create -f es-ingest-svc.yaml
kubectl create -f es-ingest.yaml
kubectl rollout status -f es-ingest.yaml

kubectl create -f es-data-svc.yaml
kubectl create -f es-data-stateful.yaml
kubectl rollout status -f es-data-stateful.yaml
```

Kubernetes creates the pods for a `StatefulSet` one at a time, waiting for each to come up before starting the next, so it may take a few minutes for all pods to be provisioned.

### Check the results
Let's check if everything is working properly:

```shell
kubectl get svc,deployment,pods -l component=elasticsearch
NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/elasticsearch             ClusterIP   10.100.243.196   <none>        9200/TCP   3m
service/elasticsearch-discovery   ClusterIP   None             <none>        9300/TCP   3m
service/elasticsearch-ingest      ClusterIP   10.100.76.74     <none>        9200/TCP   2m

NAME                              DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deployment.extensions/es-data     2         2         2            2           1m
deployment.extensions/es-ingest   2         2         2            2           2m
deployment.extensions/es-master   3         3         3            3           3m

NAME                             READY     STATUS    RESTARTS   AGE
pod/es-data-56f8ff8c97-642bq     1/1       Running   0          1m
pod/es-data-56f8ff8c97-h6hpc     1/1       Running   0          1m
pod/es-ingest-6ddd5fc689-b4s94   1/1       Running   0          2m
pod/es-ingest-6ddd5fc689-d8rtj   1/1       Running   0          2m
pod/es-master-68bf8f86c4-bsfrx   1/1       Running   0          3m
pod/es-master-68bf8f86c4-g8nph   1/1       Running   0          3m
pod/es-master-68bf8f86c4-q5khn   1/1       Running   0          3m
```

As we can assert, the cluster seems to be up and running. Easy, wasn't it?


<a id="access-the-service">

## Access the service

*Don't forget* that services in Kubernetes are only acessible from containers in the cluster. For different behavior one should [configure the creation of an external load-balancer](https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer). While it's supported within this example service descriptor, its usage is out of scope of this document, for now.

*Note:* if you are using one of the cloud providers which support external load balancers, setting the type field to "LoadBalancer" will provision a load balancer for your Service. You can uncomment the field in [es-svc.yaml](https://github.com/pires/kubernetes-elasticsearch-cluster/blob/master/es-svc.yaml).

```shell
kubectl get svc elasticsearch
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
elasticsearch   ClusterIP   10.100.243.196   <none>        9200/TCP   3m
```

From any host on the Kubernetes cluster (that's running `kube-proxy` or similar), run:

```shell
curl http://10.100.243.196:9200
```

One should see something similar to the following:

```json
{
  "name" : "es-data-56f8ff8c97-642bq",
  "cluster_name" : "myesdb",
  "cluster_uuid" : "RkRkTl26TDOE7o0FhCcW_g",
  "version" : {
    "number" : "6.3.2",
    "build_flavor" : "default",
    "build_type" : "tar",
    "build_hash" : "053779d",
    "build_date" : "2018-07-20T05:20:23.451332Z",
    "build_snapshot" : false,
    "lucene_version" : "7.3.1",
    "minimum_wire_compatibility_version" : "5.6.0",
    "minimum_index_compatibility_version" : "5.0.0"
  },
  "tagline" : "You Know, for Search"
}
```

Or if one wants to see cluster information:

```shell
curl http://10.100.243.196:9200/_cluster/health?pretty
```

One should see something similar to the following:

```json
{
  "cluster_name" : "myesdb",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 7,
  "number_of_data_nodes" : 2,
  "active_primary_shards" : 0,
  "active_shards" : 0,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0
}
```

<a id="pod-anti-affinity">

## Pod anti-affinity

One of the main advantages of running Elasticsearch on top of Kubernetes is how resilient the cluster becomes, particularly during
node restarts. However if all data pods are scheduled onto the same node(s), this advantage decreases significantly and may even
result in no data pods being available.

It is then **highly recommended**, in the context of the solution described in this repository, that one adopts [pod anti-affinity](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#inter-pod-affinity-and-anti-affinity-beta-feature)
in order to guarantee that two data pods will never run on the same node.

Here's an example:

```yaml
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: component
              operator: In
              values:
              - elasticsearch
            - key: role
              operator: In
              values:
              - data
          topologyKey: kubernetes.io/hostname
  containers:
  - (...)
```

<a id="plugins">

## Install plug-ins

The image used in this repo is very minimalist. However, one can install additional plug-ins at will by simply specifying the `ES_PLUGINS_INSTALL` environment variable in the desired pod descriptors. For instance, to install [Google Cloud Storage](https://www.elastic.co/guide/en/elasticsearch/plugins/current/repository-gcs.html) and [S3](https://www.elastic.co/guide/en/elasticsearch/plugins/current/repository-s3.html) plug-ins it would be like follows:

```yaml
- name: "ES_PLUGINS_INSTALL"
  value: "repository-gcs,repository-s3"
```

**Note:** The X-Pack plugin does not currently work with the `quay.io/pires/docker-elasticsearch-kubernetes` image. See Issue #102

<a id="kibana">

## Kibana

If Kibana defaults are not enough, one may want to customize `kibana.yaml` through a `ConfigMap`.
Please refer to [Configuring Kibana](https://www.elastic.co/guide/en/kibana/current/settings.html) for all available attributes.

```shell
kubectl create -f kibana-cm.yaml
kubectl create -f kibana-svc.yaml
kubectl create -f kibana.yaml
```

Kibana will become available through service `kibana`, and one will be able to access it from within the cluster, or proxy it through the Kubernetes API as follows:

```shell
curl https://<API_SERVER_URL>/api/v1/namespaces/default/services/kibana:http/proxy
```

One can also create an Ingress to expose the service publicly or simply use the service nodeport.
In the case one proceeds to do so, one must change the environment variable `SERVER_BASEPATH` to the match their environment.

## FAQ

### Why does `NUMBER_OF_MASTERS` differ from number of master-replicas?

The default value for this environment variable is 2, meaning a cluster will need a minimum of 2 master nodes to operate. If a cluster has 3 masters and one dies, the cluster still works. Minimum master nodes are usually `n/2 + 1`, where `n` is the number of master nodes in a cluster. If a cluster has 5 master nodes, one should have a minimum of 3, less than that and the cluster _stops_. If one scales the number of masters, make sure to update the minimum number of master nodes through the Elasticsearch API as setting environment variable will only work on cluster setup. More info: https://www.elastic.co/guide/en/elasticsearch/guide/1.x/_important_configuration_changes.html#_minimum_master_nodes


### How can I customize `elasticsearch.yaml`?

Read a different config file by settings env var `ES_PATH_CONF=/path/to/my/config/` [(see the Elasticsearch docs for more)](https://www.elastic.co/guide/en/elasticsearch/reference/current/settings.html#config-files-location). Another option would be to build one's own image from  [this repository](https://github.com/pires/docker-elasticsearch-kubernetes)
