#!/bin/bash

while getopts ":p:r:" opt; do
	case $opt in
		p)
			PASSWORD=$OPTARG
			;;
		r)
			REPLSET=$OPTARG
			if [ ! -f /var/mongo-keyfile ]; then
				echo "No key file found."
				echo "Generate keyfile:"
				echo "   openssl rand -base64 741 > mongodb-keyfile"
				echo "   chmod 600 mongodb-keyfile"
				echo "Mount keyfile:"
				echo "   docker run ... -v ./mongodb-keyfile:/var/mongo-keyfile ..."
				exit 1
			fi
			;;
		\?)
			echo "Invalid option: -$OPTARG"
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument"
			exit 1
			;;
	esac
done


function setup {
	echo "=> Setting up MongoDB..."
	if [ ! $PASSWORD ]; then
		PASSWORD=`cat /dev/urandom| tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
	fi
	echo "PASSWORD=$PASSWORD, REPLSET=$REPLSET"

	/usr/bin/mongod -f /etc/mongod.conf &

	RET=1
	while [[ RET -ne 0 ]]; do
		echo "=>    waiting for MongoDB..."
		sleep 5
		mongo admin --eval "help" >  /dev/null 2>&1
		RET=$?
	done

	mongo admin --eval "db.createUser({user: 'admin', pwd: '$PASSWORD', roles: [ { role: 'userAdminAnyDatabase', db: 'admin' } , { role: 'dbAdminAnyDatabase', db: 'admin' }, { role: 'clusterAdmin', db: 'admin' } ]});"
	mongo -u admin -p $PASSWORD --authenticationDatabase admin --eval "db.shutdownServer();" admin

	touch /.mongo-initialized

	echo "=> Setup of MongoDB finished"
	echo "=>    User 'admin' was created with the following roles: "
	echo "=>        userAdminAnyDatabase"
	echo "=>        dbAdminAnyDatabase"
	echo "=>        clusterAdmin"
	echo "=>    Connect with user 'admin', password '$PASSWORD'"
	echo "=>    Change the admin password !"
}

if [ ! -f /.mongo-initialized ]; then
	setup
fi

echo "=> Starting MongoDB..."
if [ -f /data/db/mongod.lock ]; then
	rm /data/db/mongod.lock
fi

if [ $REPLSET ]; then
	echo "=>Joining replica set $REPLSET..."
	echo ""
	echo "=>   if this is the first member of the replica set, initiate the replica set"
	echo "=>      rs.initiate()"
	echo "=>   after initializing the replica set, configure the host name the first member"
	echo "=>      cfg = rs.conf()"
	echo "=>      cfg.members[0].host = '<IP>:<Port>'     e.g.  cfg.members[0].host = '172.17.42.1:49150'"
	echo "=>      rs.reconfig(cfg)"
	echo ""
	echo "=>   if this instance should be added to an existing replica set, call"
	echo "=>      rs.add('<IP>:<Port>')"
	echo "=>   on the RS master"
	echo ""
	exec /usr/bin/mongod -f /etc/mongod.conf --replSet "$REPLSET" --keyFile /var/mongo-keyfile 
else
	exec /usr/bin/mongod -f /etc/mongod.conf
fi
