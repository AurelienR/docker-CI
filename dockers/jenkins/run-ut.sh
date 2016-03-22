#!/bin/bash

MVN_CONTAINER="docker-ut"
DIRECTORY="logs"
MYSQL_CONTAINER="mysql-docker"
MYSQL_IMAGE="mysql:5.6"
MVN_IMAGE="aurelienr/jdk8-mvn:latest"

echo "##################################################################################"
echo "#                                                                                #"
echo "#                     Run Unit Test - run-ut.sh                                  #"
echo "#                                                                                #"
echo "##################################################################################"


echo ""
echo "##################################################################################"
echo "# Step 1 - Run MYSQL docker                                                      #"
echo "##################################################################################"

# Detect if mysql container is running
echo "LOG- Check $MYSQL_CONTAINER container is running."
MYSQL_CONTAINER_RUNNING=$(docker inspect --format="{{ .State.Running }}" $MYSQL_CONTAINER 2> /dev/null)

# If Mysql container is not running
if [ $? -eq 0  ] && [ "$MYSQL_CONTAINER_RUNNING" == "false" ]  ; then
  echo "LOG - $MYSQL_CONTAINER container already exists"
  echo "LOG - Starting $MYSQL_CONTAINER container."
  docker start $MYSQL_CONTAINER
else
  echo "LOG - $MYSQL_CONTAINER container does not exist"
  echo "LOG - Remove $MYSQL_CONTAINER container."
  docker rm $MYSQL_CONTAINER
  echo "LOG - Run $MYSQL_CONTAINER container."
  docker run --name $MYSQL_CONTAINER -p 3306:3306 -e "MYSQL_ROOT_PASSWORD=admin" -d $MYSQL_IMAGE
fi

echo "LOG - Wait 10sec to $MYSQL_CONTAINER container to run"
sleep 10

echo "LOG- Docker ps check:"
docker ps

echo ""
echo "##################################################################################"
echo "# Step 2 - Create JDK-MVN container                                              #"
echo "##################################################################################"

echo "LOG- Pull last image of $MVN_IMAGE."
docker pull $MVN_IMAGE > pull.txt

res=$(grep "Image is up to date" pull.txt)
rm pull.txt

# Detect if mysql container is running
echo "LOG- Check $MVN_CONTAINER container is running."
MVN_RUNNING=$(docker inspect --format="{{ .State.Running }}" $MVN_CONTAINER 2> /dev/null)

# Create container if does not exists
if [ ${#res} -eq 0 ] || [ $? -eq 1 ] ; then
  echo "LOG - $MVN_CONTAINER container does not exist."
  echo "LOG - Remove $MVN_CONTAINER container."
  docker rm $MVN_CONTAINER
  echo "LOG - Create container: $MVN_CONTAINER."
  docker create --name $MVN_CONTAINER --link $MYSQL_CONTAINER $MVN_IMAGE
fi

echo "LOG- Docker ps check:"
docker ps

echo ""
echo "##################################################################################"
echo "# Step 3 - Copy cloned repo                                                      #"
echo "##################################################################################"
# Copy cloned repo to docker:/webapp
echo "LOG - Copy repo to webapp."
docker cp . $MVN_CONTAINER:webapp

echo ""
echo "##################################################################################"
echo "# Step 4 - Generate dao.properties                                               #"
echo "##################################################################################"
# Copy dao properties for JDBC Test connection
echo "LOG - Generating dao.properties for testing environment"
MYSQL_CONTAINER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $MYSQL_CONTAINER)

#We then use this ip to create the connection.properties file
echo "url = jdbc:mysql://$MYSQL_CONTAINER_IP:3306/computer-database-db_TEST?zeroDateTimeBehavior=convertToNull" > src/main/resources/properties/dao.properties
echo "driver = com.mysql.jdbc.Driver" >> src/main/resources/properties/dao.properties
echo "nomutilisateur = root" >> src/main/resources/properties/dao.properties
echo "motdepasse = admin" >> src/main/resources/properties/dao.properties
echo "MinConnectionsPerPartition = 5" >> src/main/resources/properties/dao.properties
echo "MaxConnectionsPerPartition = 10" >> src/main/resources/properties/dao.properties
echo "PartitionCount = 2"  >> src/main/resources/properties/dao.properties
cp src/main/resources/properties/dao.properties src/test/resources/properties/dao.properties

echo ""
echo "##################################################################################"
echo "# Step 5 - Start JDK-MVN container                                               #"
echo "##################################################################################"

# Start mvn docker
echo "LOG - $MVN_CONTAINER container is not running."
echo "LOG - start $MVN_CONTAINER."
docker start -a $MVN_CONTAINER


echo "LOG- JDK-MVN infos:"
STARTED=$(docker inspect --format="{{ .State.StartedAt }}" $MVN_CONTAINER)
NETWORK=$(docker inspect --format="{{ .NetworkSettings.IPAddress }}" $MVN_CONTAINER)
echo "OK - $MVN_CONTAINER is running. IP: $NETWORK, StartedAt: $STARTED"

echo "LOG- Docker ps check:"
docker ps

echo ""
echo "##################################################################################"
echo "# Step 6 - Copy logs                                                             #"
echo "##################################################################################"

# Copy logs
if [ ! -d "$DIRECTORY" ]; then
  echo "LOG- Create log directory"
  mkdir logs
fi

echo "Copying logs:"
echo "Copying from webapp/target/surefire-reports ... "
docker cp $MVN_CONTAINER:webapp/target/surefire-reports ./logs
echo "Copying from webapp/target/failsafe-reports ... "
docker cp $MVN_CONTAINER:webapp/target/failsafe-reports ./logs

echo ""
echo "##################################################################################"
echo "# Step 7 - Stop containers                                                       #"
echo "##################################################################################"
# Stop all dockers
docker stop $MYSQL_CONTAINER
docker stop $MVN_CONTAINER
