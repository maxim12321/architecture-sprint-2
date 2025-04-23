#!/bin/bash

# Настройка серверов конфигурации
docker compose exec -T configsvr-1 mongosh --port 27017 <<EOF
rs.initiate({
    _id: "config-server",
    configsvr: true,
    members: [
        { _id: 0, host: "configsvr-1:27017" },
        { _id: 1, host: "configsvr-2:27017" },
        { _id: 2, host: "configsvr-3:27017" }
    ]
})
EOF

echo "Waiting for shard1-1..."
until docker exec -t -i shard1-1 sh -c 'mongosh --eval "db.adminCommand(\"ping\")" --quiet; exit $?'; do
  sleep 5
done

# Настройка первого шарда
docker compose exec -T shard1-1 mongosh --port 27017 <<EOF
rs.initiate({
    _id: "shard1",
    members: [
        { _id: 0, host: "shard1-1:27017" },
        { _id: 1, host: "shard1-2:27017" },
        { _id: 2, host: "shard1-3:27017" }
    ]
})
EOF

echo "Waiting for shard2-1..."
until docker exec -t -i shard2-1 sh -c 'mongosh --eval "db.adminCommand(\"ping\")" --quiet; exit $?'; do
  sleep 5
done

# Настройка второго шарда
docker compose exec -T shard2-1 mongosh --port 27017 <<EOF
rs.initiate({
    _id: "shard2",
    members: [
        { _id: 0, host: "shard2-1:27017" },
        { _id: 1, host: "shard2-2:27017" },
        { _id: 2, host: "shard2-3:27017" }
    ]
})
EOF

echo "Waiting for config server replica set to elect a primary..."
until docker exec -t -i router-1 sh -c 'mongosh --host config-server/configsvr-1:27017,configsvr-2:27017,configsvr-3:27017 --eval "rs.status().members.some(m => m.stateStr === \"PRIMARY\")" | grep -q "true"; exit $?'; do
  sleep 5
done

echo "Waiting for shard1 to elect a primary..."
until docker exec -t -i router-1 sh -c 'mongosh --host shard1/shard1-1:27017,shard1-2:27017,shard1-3:27017 --eval "rs.status().members.some(m => m.stateStr === \"PRIMARY\")" | grep -q "true"; exit $?'; do
  sleep 5
done

echo "Waiting for shard2 to elect a primary..."
until docker exec -t -i router-1 sh -c 'mongosh --host shard2/shard2-1:27017,shard2-2:27017,shard2-3:27017 --eval "rs.status().members.some(m => m.stateStr === \"PRIMARY\")" | grep -q "true"; exit $?'; do
  sleep 5
done

echo "Waiting for router-1..."
until docker exec -t -i router-1 sh -c 'mongosh --eval "db.adminCommand(\"ping\")" --quiet; exit $?'; do
  sleep 5
done

# Настройка первого роутера
docker compose exec -T router-1 mongosh --port 27017 <<EOF
sh.addShard("shard1/shard1-1:27017")
sh.addShard("shard1/shard1-2:27017")
sh.addShard("shard1/shard1-3:27017")
sh.addShard("shard2/shard2-1:27017")
sh.addShard("shard2/shard2-2:27017")
sh.addShard("shard2/shard2-3:27017")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
EOF

echo "Waiting for router-2..."
until docker exec -t -i router-2 sh -c 'mongosh --eval "db.adminCommand(\"ping\")" --quiet; exit $?'; do
  sleep 5
done

# Настройка второго роутера
docker compose exec -T router-2 mongosh --port 27017 <<EOF
sh.addShard("shard1/shard1-1:27017")
sh.addShard("shard1/shard1-2:27017")
sh.addShard("shard1/shard1-3:27017")
sh.addShard("shard2/shard2-1:27017")
sh.addShard("shard2/shard2-2:27017")
sh.addShard("shard2/shard2-3:27017")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
EOF

echo "Waiting for router-3..."
until docker exec -t -i router-3 sh -c 'mongosh --eval "db.adminCommand(\"ping\")" --quiet; exit $?'; do
  sleep 5
done

# Настройка третьего роутера
docker compose exec -T router-3 mongosh --port 27017 <<EOF
sh.addShard("shard1/shard1-1:27017")
sh.addShard("shard1/shard1-2:27017")
sh.addShard("shard1/shard1-3:27017")
sh.addShard("shard2/shard2-1:27017")
sh.addShard("shard2/shard2-2:27017")
sh.addShard("shard2/shard2-3:27017")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
EOF
