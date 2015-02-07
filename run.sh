#!/bin/bash

ADMINUSER=admin

while getopts ":p:r:h:" opt; do
	case $opt in
		p)
			PASSWORD=$OPTARG
			OPTION_CUSTOMPASSWORD=1
			echo "Using custom password"
			;;
		h)
			OPTION_HOST=$OPTARG
			echo "Using custom host: $OPTION_HOST"
			;;
		r)
			REPLSET=$OPTARG
			if [ ! -f /var/mongo-keyfile ]; then
				echo "No key file found."
				echo "  Generate keyfile:"
				echo "     openssl rand -base64 741 > mongo-keyfile"
				echo "     chmod 600 mongo-keyfile"
				echo "  Mount keyfile:"
				echo "     docker run ... -v ./mongo-keyfile:/var/mongo-keyfile ..."
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
		PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
	fi

	/usr/bin/mongod -f /etc/mongod.conf &

	RET=1
	while [[ RET -ne 0 ]]; do
		echo "=>    waiting for MongoDB..."
		sleep 5
		mongo $ADMINUSER --eval "help" >  /dev/null 2>&1
		RET=$?
	done

	mongo $ADMINUSER --eval "db.createUser({user: 'admin', pwd: '$PASSWORD', roles: [ { role: 'userAdminAnyDatabase', db: 'admin' } , { role: 'dbAdminAnyDatabase', db: 'admin' }, { role: 'clusterAdmin', db: 'admin' } ]});"

	touch /.mongo-initialized
	mongo -u $ADMINUSER -p $PASSWORD --authenticationDatabase admin --eval "db.shutdownServer();" admin


	echo "=> Setup of MongoDB finished"
	echo "=>    User 'admin' was created with the following roles: "
	echo "=>        userAdminAnyDatabase"
	echo "=>        dbAdminAnyDatabase"
	echo "=>        clusterAdmin"

	if [ -n $OPTION_CUSTOMPASSWORD ]; then
		echo "=>   Connect with user '$ADMINUSER' and the password you passed as a parameter"
	else
		echo "=>    Connect with user '$ADMINUSER', password '$PASSWORD'"
		echo "=>        Change this password !"
	fi
}

if [ ! -f /.mongo-initialized ]; then
	setup
fi

echo "=> Starting MongoDB..."
if [ -f /data/db/mongod.lock ]; then
	rm /data/db/mongod.lock
fi

if [ $REPLSET ]; then
	echo "=>   if this is the first member of the replica set, initiate the replica set"
	echo "=>      rs.initiate()"
	echo "=>   after initializing the replica set, configure the host name the first member"
	echo "=>      cfg = rs.conf()"
	echo "=>      cfg.members[0].host = '<IP>:<Port>'     e.g.  cfg.members[0].host = '172.17.42.1:49150'"
	echo "=>      rs.reconfig(cfg)"
	echo "=>   if this instance should be added to an existing replica set, call"
	echo "=>      rs.add('<IP>:<Port>')"
	echo "=>   on the RS master"
	echo ""
	exec /usr/bin/mongod -f /etc/mongod.conf --replSet "$REPLSET" --keyFile /var/mongo-keyfile 
else
	exec /usr/bin/mongod -f /etc/mongod.conf
fi
