# Elasticsearch Docker.

 * `docker build --tag raaftech/elasticsearch .`
 * `docker run -detach --publish 9200:9200 --publish 9300:9300 --name elasticsearch raaftech/elasticsearch`
 * `docker logs --follow elasticsearch`
