#!/bin/bash
date +"@ %Y-%m-%d %H:%M:%S %z"

# wait for mysql start
while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done
sleep 10

DB=$INIT_DB
PW=$INIT_PASSWD
DOMAIN=$INIT_DOMAIN
BASE="/var/www"
DRUPAL="7.53"
SITE=$INIT_NAME
MAIL="mis@netivism.com.tw"

# init script repository
cd /home/docker && git pull

# init log directory
if [ ! -d /var/www/html/log ]; then
  mkdir /var/www/html/log
  chown root /var/www/html/log
fi
chgrp -R www-data $BASE/html/log && chmod -R g+ws $BASE/html/log

# init mysql
DB_EXISTS=`mysql -uroot -sN -e "SHOW databases" | grep $DB`

function clear_demo() {
  # add clear.sql
  echo "SET FOREIGN_KEY_CHECKS = 0; SET GROUP_CONCAT_MAX_LEN=32768; SET @tables = NULL; SELECT GROUP_CONCAT('\`', table_name, '\`') INTO @tables FROM information_schema.tables WHERE table_schema = (SELECT DATABASE()); SELECT IFNULL(@tables,'dummy') INTO @tables; SET @tables = CONCAT('DROP TABLE IF EXISTS ', @tables); PREPARE stmt FROM @tables; EXECUTE stmt; DEALLOCATE PREPARE stmt; SET FOREIGN_KEY_CHECKS = 1;" > /tmp/cleardb.sql
  mysql -u\$INIT_DB -p\$INIT_PASSWD \$INIT_DB < /tmp/cleardb.sql

  if [ -f $BASE/html/sites/default/settings.php ]; then
    rm -f $BASE/html/sites/default/settings.php
    chmod 755 $BASE/html/sites/default
  fi
  if [ -f $BASE/html/sites/default/civicrm.settings.php ]; then
    rm -f $BASE/html/sites/default/civicrm.settings.php
  fi
  if [ -d $BASE/html/sites/default/files ]; then
    rm -Rf $BASE/html/sites/default/files
  fi
}
function create_demo() {
  cd $BASE/html
  php -d sendmail_path=`which true` ~/.composer/vendor/bin/drush.php site-install neticrmp variables.civicrm_demo_sample_data=1 --account-mail=${MAIL} --account-name=admin --account-pass=${PW} --db-url=mysql://${DB}:${PW}@127.0.0.1/${DB} --site-mail=${MAIL} --site-name="${SITE}" --locale=zh-hant --yes

  cd $BASE && chown -R www-data:www-data html
  drush user-create demo --password="demouser" --mail="demo@netivism.com.tw" 
  drush user-add-role "網站總管" "demo"
  drush vset neticrm_welcome_message "歡迎您來到 netiCRM示範網站。本網站為測試用途，資料隨時清除，請勿留下個資以免外洩。測試帳號/密碼請用 demo / demouser 登入，如有任何問題，請至 https://neticrm.tw 與我們聯繫。"
}

if [ -z "$DB_EXISTS" ] && [ -n "$DB" ]; then
  mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"
  mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'%' WITH GRANT OPTION;"
  mysql -uroot -e "UPDATE mysql.user set Password=PASSWORD('$PW') where user = 'root';"
  mysql -uroot -e "FLUSH PRIVILEGES;"
  echo "MySQL initialize completed !!"
  echo "MYSQL_DB=$DB"
  echo "MYSQL_PW=$PW"

  if [ -f "$BASE/html/index.php" ]; then
    DRUPAL_EXISTS=`cat $BASE/html/index.php | grep drupal`
  else
    DRUPAL_EXISTS=""
  fi
  if [ -z "$DRUPAL_EXISTS" ]; then
    date +"@ %Y-%m-%d %H:%M:%S %z"
    echo "Install Drupal ..."
    cd $BASE
    drush dl drupal-${DRUPAL}
    mv $BASE/drupal-${DRUPAL}/* $BASE/html/
    mv $BASE/drupal-${DRUPAL}/.htaccess $BASE/html/
    rm -Rf $BASE/drupal-${DRUPAL}
  fi
  if [ ! -h "$BASE/html/profiles/neticrmp" ]; then
    cd $BASE/html/profiles && ln -s /mnt/neticrm-demo/neticrmp neticrmp
  fi
  if [ ! -h "$BASE/html/sites/all/modules/civicrm" ]; then
    cd $BASE/html/sites/all/modules && ln -s /mnt/neticrm-demo/civicrm civicrm
  fi
  # make sure drush have correct base_url
  if [ ! -f "$BASE/html/sites/default/drushrc.php" ]; then
    echo -e "<?php\n\$options['uri'] = 'http://$INIT_DOMAIN';\n\$options['php-notices'] = 'warning';" > $BASE/html/sites/default/drushrc.php;
  fi

  if [ ! -d "$BASE/html/profiles/neticrmp" ]; then
    echo "Error: Profile not found. (missing neticrmp)"
    exit 1
  fi
  if [ -f $BASE/html/sites/default/settings.php ]; then
    echo "Error: Drupal already installed. (found settings.php)"
    exit 1
  fi
  if [ -f $BASE/html/sites/default/civicrm.settings.php ]; then
    echo "Error: CiviCRM already installed. (found civicrm.settings.php)"
    exit 1
  fi

  create_demo
  echo "Done!"
elif [ -n "$DB_EXISTS" ]; then
  echo "Clear exists demo site data..."
  clear_demo
  echo "Create new demo site"
  create_demo
else
  echo "Skip exist $DB, root password already setup before."
fi
date +"@ %Y-%m-%d %H:%M:%S %z"

