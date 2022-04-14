#!/bin/bash
mkdir $PWD/encryption
echo "-------- Create keys --------------- "
# Generate 32 byte key and store in a file
echo "1;"$(openssl rand -hex 32) > $PWD/encryption/keyfile
# Generate random key to re-encrypt
openssl rand -hex 128 > $PWD/encryption/keyfile.key
# Re-encrypt key with random key
openssl enc -aes-256-cbc -md sha1 -pass file:$PWD/encryption/keyfile.key -in $PWD/encryption/keyfile -out $PWD/encryption/keyfile.enc
# Remove original key
rm -rf $PWD/encryption/keyfile

echo "-------- Create container --------------- "
docker run --name mariadb-encrypted --rm \
-v $PWD/config:/etc/mysql/mariadb.conf.d \
-v $PWD/encryption:/etc/mysql/encryption \
-e MARIADB_ROOT_PASSWORD=secret -d mariadb

echo "-------- Check container --------------- "
docker exec -it mariadb-encrypted ls -C /usr/lib/mysql/plugin
docker logs mariadb-encrypted
#docker exec -it mariadb-encrypted mariadb -uroot -psecret "show plugins;"

#echo "-------- Stop container --------------- "
#docker stop mariadb-encrypted