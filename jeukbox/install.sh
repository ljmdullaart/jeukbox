#!/bin/bash

ssh root@webservers mkdir -p /opt/jeukbox
ssh root@webservers mountcommand synology

rm music.db
perl jeukbox-db.pl >/dev/null &

if [ ! -L /links/cdtracks ] ; then
cat <<EOF
******************************************************
*  ERROR : op webservers ontbreekt /links/cdtracks   *
******************************************************
EOF
exit 99
fi
scp -r * root@webservers:/opt/jeukbox


ssh root@webservers cpan Dancer2
ssh root@webservers cpan Plack
ssh root@webservers cpan JSON
ssh root@webservers cpan File::Slurp
ssh root@webservers cpan DBD::SQLite
ssh root@webservers cpan Encode::Detect

wait

cp music.db /links/cdtracks
