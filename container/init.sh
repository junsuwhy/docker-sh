#!/bin/sh
DB=$INIT_DB
PW=$INIT_PASSWD

# init log directory
if [ ! -d /var/www/html/log ]; then
  mkdir /var/www/html/log
  chown -R root:adm /var/www/html/log
fi

# init mysql
if [ ! -d /var/lib/mysql/mysql ]; then
  # Setup MySQL data directory.
  echo "Initializing mysql data dir to /var/lib/mysql ..."
  mysql_install_db --datadir=/var/lib/mysql

  /usr/bin/mysqld_safe > /dev/null 2>&1 &

  while (true); do
    sleep 3s
    mysql -uroot -e "status" > /dev/null 2>&1 && break
  done

  mysql -uroot -e "UPDATE mysql.user set Password=PASSWORD('$PW') where user = 'root';"
  mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"
  mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
  mysql -uroot -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, \
      CREATE TEMPORARY TABLES ON $DB.* TO '$DB'@'%';"
  echo "MYSQL_DB=$DB"
  echo "MYSQL_PW=$PW"
else
  # if mysql stopped, start it
  /usr/bin/mysqld_safe > /dev/null 2>&1 &
fi

# enter to bash interface
/bin/bash