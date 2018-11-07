# Elasticsearch Docker.

 * `docker build -t raaftech/elasticsearch .`
 * `docker run -d -p 9200:9200 -p 9300:9300 --name elasticsearch raaftech/elasticsearch`
 * `docker logs -f elasticsearch`
 * `curl http://localhost:9200`
