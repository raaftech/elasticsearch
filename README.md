# Elasticsearch Docker.

 * `docker build --tag ahold/elasticsearch .`
 * `docker run -detach --publish 9200:9200 --publish 9300:9300 --name elasticsearch ahold/elasticsearch`
 * `docker logs --follow elasticsearch`
