#!/bin/bash

while getopts ":p:" opt; do
	case $opt in
		p)
			echo "password = $OPTARG"
			PASSWORD=$OPTARG
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

	/usr/bin/mongod -f /etc/mongod.conf &

	RET=1
	while [[ RET -ne 0 ]]; do
		echo "=>    waiting for MongoDB..."
		sleep 5
		mongo admin --eval "help" > /dev/null 2>&1
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
if [ ! -f /data/db/mongod.lock ]; then
	exec /usr/bin/mongod -f /etc/mongod.conf
else
	rm /data/db/mongod.lock
	exec /usr/bin/mongod -f /etc/mongod.conf
fi
