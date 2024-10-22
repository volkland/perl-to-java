#!/bin/bash

# Container name
CONTAINER_NAME="javawrapper-perlapp-1"

# kill perl to trigger coverage
docker exec -it $CONTAINER_NAME /bin/bash -c "pkill -TERM perl"

# Wait for the container to stop
echo "Waiting for the container to stop..."
while [ "$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME)" == "true" ]; do
    echo "Container $CONTAINER_NAME still alive ..."
    sleep 1
done

echo "Restarting the container..."
docker start $CONTAINER_NAME
echo "Container has been restarted."

docker cp $CONTAINER_NAME:/root/daemon/cover_db/ .

echo "Changing owner of coverage folder"
sudo chown -R 1000:1000 ./cover_db
