#!/bin/bash

date > installlog
ssh root@webservers mkdir -p /opt/jeukbox
ssh root@webservers mountcommand synology

if [ "$1" = "-db" ] ; then
	rm music.db
	perl jeukbox-db.pl >/dev/null &
else
cat <<EOF
******************************************************
*  WARNING: use -db to regenerate the database       *
******************************************************
EOF
fi
	

if [ ! -L /links/cdtracks ] ; then
cat <<EOF
******************************************************
*  ERROR : op webservers ontbreekt /links/cdtracks   *
******************************************************
EOF
exit 99
fi
scp -r * root@webservers:/opt/jeukbox  >>installlog 2>&1
echo -n '.'


ssh root@webservers cpan Dancer2  >>installlog 2>&1
echo -n '.'
ssh root@webservers cpan Plack >>installlog 2>&1
echo -n '.'
ssh root@webservers cpan JSON >>installlog 2>&1
echo -n '.'
ssh root@webservers cpan File::Slurp >>installlog 2>&1
echo -n '.'
ssh root@webservers cpan DBD::SQLite >>installlog 2>&1
echo -n '.'
ssh root@webservers cpan Encode::Detect >>installlog 2>&1
echo '.'

wait

cp music.db /links/cdtracks
