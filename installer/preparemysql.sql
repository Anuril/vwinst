DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';
CREATE DATABASE vaultwarden;
USE vaultwarden;
GRANT ALL PRIVILEGES ON vaultwarden TO '$dbuser'@'%';
FLUSH PRIVILEGES;