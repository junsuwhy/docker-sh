#!/bin/sh
echo "Usage: ./$0 domain.com mail@mail.com neticrm-7.sh"
REALPATH=`realpath $0`
WORKDIR=`dirname $REALPATH`
MOUNTDIR=$WORKDIR

if [ -z "$1" ]; then
  echo "No domain name."
  exit 1
fi
if [ -z "$2" ]; then
  echo "No mail"
  exit 1
fi

if [ ! -d "$MOUNTDIR/neticrm-7" ]; then
  mkdir -p $MOUNTDIR/neticrm-7
fi
if [ ! -d "$MOUNTDIR/www/sites/$1/log/supervisor" ]; then
  mkdir -p $MOUNTDIR/www/sites/$1/log/supervisor
fi
if [ ! -d "$MOUNTDIR/mysql/sites/$1" ]; then
  mkdir -p $MOUNTDIR/mysql/sites/$1
fi

cd $MOUNTDIR/neticrm-7
git clone -b develop https://github.com/NETivism/netiCRM.git civicrm
cd civicrm
git clone -b 7.x-develop https://github.com/NETivism/netiCRM-neticrm neticrm
git clone -b 7.x-develop https://github.com/NETivism/netiCRM-drupal drupal
cd ..
git clone -b 7.x-develop https://git.netivism.com.tw/jimmy/neticrmp.git neticrmp

if [ -n "$3" ] && [ -f "$WORKDIR/container/$3" ]; then
  SCRIPT="$WORKDIR/container/$3"
else
  SCRIPT="$WORKDIR/container/neticrm-7.sh"
fi

docker run -d --name $1 \
  -p 8888:80 \
  -p 33333:3306 \
  -v $MOUNTDIR/www/sites/$1:/var/www/html \
  -v $MOUNTDIR/mysql/sites/$1:/var/lib/mysql \
  -v /etc/localtime:/etc/localtime:ro \
  -v $SCRIPT:/init.sh \
  -v $MOUNTDIR/neticrm-7:/mnt/neticrm-7 \
  -v $WORKDIR/mysql/my.cnf:/etc/mysql/my.cnf \
  -e INIT_DB=develop \
  -e INIT_PASSWD=123456 \
  -e INIT_DOMAIN=$1 \
  -e INIT_NAME=develop \
  -e INIT_MAIL=$2 \
  -e HOST_MAIL=mis@netivism.com.tw \
  -e "TZ=Asia/Taipei" \
  -w "/var/www/html" \
  -i -t netivism/docker-wheezy-php55