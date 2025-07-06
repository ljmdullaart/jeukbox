#!/bin/bash

ssh root@webservers mkdir -p /opt/jeukbox
ssh root@webservers mountcommand synology

if [ ! -L /links/cdtracks ] ; then
cat <<EOF
******************************************************
*  ERROR : op webservers ontbreekt /links/cdtracks   *
******************************************************
EOF
exit 99
fi
scp -r * root@webservers:/opt/jeukbox

if [ -f music.db ] ; then
	cp music.db /links/cdtracks
elif [ -f ../music.db ] ; then
	cp ../music.db /links/cdtracks
elif [ -f ../../music.db ] ; then
	cp ../../music.db /links/cdtracks
fi

ssh root@webservers cpan Dancer2
ssh root@webservers cpan Plack
ssh root@webservers cpan JSON
ssh root@webservers cpan File::Slurp
ssh root@webservers cpan DBD::SQLite

