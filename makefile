# Deploy all the service needed to use awx
stack: postgres awx

status:
	docker service ls

awx_logs:
	docker service logs -f awx_awx

postgres:
	docker stack deploy -c ./postgres.yml awx

awx:
	docker stack deploy -c ./awx.yml awx

remove:
	docker stack rm awx
	sleep 10 
	docker volume rm awx_postgres

# Used to check the setup and teardown
make e2e: stack status remove
		
