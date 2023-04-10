

## Create MySQL user and user databases for mlflow experiment;

initialization of environment file
```
cat <<EOT >> .env
MYSQL_ROOT_PASSWORD=root
EOT
```

```
docker compose build
docker compose up
```

```
docker exec -it backend-storage-db-1 bash
```

```
mysql -u root -p 
```
privode password settinf from .env (in this example is  `root`)

create user and correspoding databases
```
CREATE USER '<user>'@'%' IDENTIFIED WITH mysql_native_password BY '<passwd>';
CREATE DATABASE IF NOT EXISTS <databases_name> CHARACTER SET utf8;
GRANT SELECT,INSERT,CREATE,ALTER,DROP,LOCK TABLES,CREATE TEMPORARY TABLES, DELETE, UPDATE, EXECUTE, INDEX, REFERENCES ON <databases_name>.* TO '<user>'@'%';
```
