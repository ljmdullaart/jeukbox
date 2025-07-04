#!/bin/bash
if [ -f bin/app.psgi ] ; then
	plackup -p 5101 -r bin/app.psgi
elif [ -f /opt/jeukbox/bin/app.psgi ] ; then
	plackup -p 5101 -r /opt/jeukbox/bin/app.psgi
fi

