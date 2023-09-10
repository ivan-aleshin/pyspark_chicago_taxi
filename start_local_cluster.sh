#!/bin/bash

# Full path to project directory
# We mount it to docker containers
# So they will se the content in that directory
PATH_TO_PROJECT_DIR="/mnt/c/Users/Ivan/Documents/spark/mount"

MEMORY_PER_WORKER='4g'
CORES_PER_WORKER=2

# Creates local docker network and names it as "spark_network"
docker network create spark_network

# Runs Spark Master Node
docker run -d -p 8080:8080 -p 7077:7077 --name spark_master --network spark_network \
-v $PATH_TO_PROJECT_DIR:/work:rw \
custom-spark-python3.11 /opt/spark/bin/spark-class org.apache.spark.deploy.master.Master \
-h spark_master

# Save IP address of our Spark Master node
# to attach workers to it
SPARK_MASTER_IP=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' spark_master`

# Run Spark workers and bind them to our Spark Master node
docker run -d --name spark_worker1 --network spark_network \
-e SPARK_WORKER_MEMORY=$MEMORY_PER_WORKER \
-e SPARK_WORKER_CORES=$CORES_PER_WORKER \
-v $PATH_TO_PROJECT_DIR:/work:rw \
custom-spark-python3.11 /opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker \
spark://$SPARK_MASTER_IP:7077

docker run -d --name spark_worker2 --network spark_network \
-e SPARK_WORKER_MEMORY=$MEMORY_PER_WORKER \
-e SPARK_WORKER_CORES=$CORES_PER_WORKER \
-v $PATH_TO_PROJECT_DIR:/work:rw \
custom-spark-python3.11 /opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker \
spark://$SPARK_MASTER_IP:7077

docker run -d --name spark_worker3 --network spark_network \
-e SPARK_WORKER_MEMORY=$MEMORY_PER_WORKER \
-e SPARK_WORKER_CORES=$CORES_PER_WORKER \
-v $PATH_TO_PROJECT_DIR:/work:rw \
custom-spark-python3.11 /opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker \
spark://$SPARK_MASTER_IP:7077

docker run -d --name spark_worker4 --network spark_network \
-e SPARK_WORKER_MEMORY=$MEMORY_PER_WORKER \
-e SPARK_WORKER_CORES=$CORES_PER_WORKER \
-v $PATH_TO_PROJECT_DIR:/work:rw \
custom-spark-python3.11 /opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker \
spark://$SPARK_MASTER_IP:7077

docker run -d --name mlflow_server -p 5000:5000 --network spark_network \
-v $PATH_TO_PROJECT_DIR/mlflow_data:/mlflow_data \
mlflow-server

# Извлекаем IP MLflow server
MLFLOW_IP=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mlflow_server`

docker run -d --name jupyter_lab -p 10000:8888 -p 4040:4040 --network spark_network --user root \
-v $PATH_TO_PROJECT_DIR:/work:rw \
-e SPARK_MASTER=spark://$SPARK_MASTER_IP:7077 \
jupyter/pyspark-notebook start-notebook.sh --NotebookApp.token='' --NotebookApp.notebook_dir='/work'

# Записываем переменные в конфиг
cp $PATH_TO_PROJECT_DIR/spark_mlflow_config_template.py $PATH_TO_PROJECT_DIR/spark_mlflow_config.py
sed -i "s/CHANGE_ME_1/$MLFLOW_IP/g" $PATH_TO_PROJECT_DIR/spark_mlflow_config.py
sed -i "s/CHANGE_ME_2/$SPARK_MASTER_IP/g" $PATH_TO_PROJECT_DIR/spark_mlflow_config.py

echo 'YOUR SPARK MASTER NODE IP IS:' $SPARK_MASTER_IP
echo 'YOUR MLFLOW IP IS:' $MLFLOW_IP
echo 'YOU CAN ACCESS JUPYTER LAB VIA: http://localhost:10000'
echo 'YOU CAN ACCESS ML-Flow VIA: http://localhost:5000'
