#!/bin/bash

# Credentials for OpenSearch Dashboards
USERNAME="admin"
PASSWORD="openHIEdemo!123"

# Wait for OpenSearch Dashboards to be available
until curl -s -u "$USERNAME:$PASSWORD" http://opensearch-dashboards:5601/api/status | grep '"state":"green"' > /dev/null; do
    echo "Waiting for OpenSearch Dashboards to be available..."
    sleep 5
done

# Proceed with importing saved objects
curl -X POST "http://opensearch-dashboards:5601/api/saved_objects/_import?createNewCopies=true" \
  -u "$USERNAME:$PASSWORD" \
  -H "osd-xsrf: true" \
  -H "securitytenant: global" \
  --form file=@/usr/share/opensearch-dashboards/data/saved_objects.ndjson

echo "Import completed."
