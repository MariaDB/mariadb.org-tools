#### Create encrypted key
```bash
# Generate 32 byte key and store in a file
echo "1;"$(openssl rand -hex 32) > $PWD/encryption/keyfile
```
#### Encrypt encrypted key (re-encrypt)
```bash
# Generate random key
openssl rand -hex 128 > $PWD/encryption/keyfile.key
# Re-encrypt key with random key (here is a bug in [1])
openssl enc -aes-256-cbc -md md5 -pass file:$PWD/encryption/keyfile.key -in $PWD/encryption/keyfile -out $PWD/encryption/keyfile.enc
# Remove original key
rm -rf $PWD/encryption/keyfile
```

#### References

[1] [Transparent Data Encryption (TDE) Using MariaDB’s File Key Management Encryption Plugin](https://mariadb.com/resources/blog/mariadb-encryption-tde-using-mariadbs-file-key-management-encryption-plugin/)