# Deploy AWX stack on Docker Swarm

![awx](img/awx.png)

I'm a huge fan of Ansible and have been writing playbooks and roles for the past year.  Typically I run these locally from a laptop but in 2018 would like to do things a little more "enterprisy"?  AWX is a really nice OpenSource frontend for ansible.  Since we rely on ansible for rolling out new environments we would need AWX to be HA.  Docker Swarm is a nice fit for keeping our AWX stack running and healthy.  

The stack has been split into 2 parts :

- Postgres service
- awx and supporting services

This was broken into 2 parts since the 'depends_on' option is not supported with "docker stack deploy" so we start Postgres first and then the awx containers. I also removed all the swarm deploy options restricting memory/cpu, placement etc but plan to add these in at a later date. To avoid splitting the stack like this we can update the ansible/awx_task image entrypoint to wait for the postgres container to be ready. And finally the postgres data volume is just a regular volume on the local disk. This can be updated to use a nfs mount or in AWS the rexray/efs plugin. 

Let's get started.

If you don't have time to read through the following commands you can run the Cheatsheet commands instead.

## Cheatsheet

```
make stack - Deploys all the services required to use awx. Appendix 1.
make status - Shows running services. Appendix 2.
make awx_logs - Tails the logs from the awx service. This is a good place to debug when the service is starting. Appendix 3.
make remove - Removes services, networks and data volumes used by awx.
make e2e - Checks the end-to-end start up and teardown of the services. Appendix 4.
```

## Step by Step walkthrough

### Deploy Postgres
```
docker stack deploy -c ./postgres.yml awx
```

Check the service has started : 
```
docker stack ls

Output :

NAME                SERVICES
awx                 1
```

Check how many replicas are running.  There should be 1 postgres replica running.
```
docker service ls

Output :

ID                  NAME                MODE                REPLICAS            IMAGE               PORTS
rel5r5tt0zsj        awx_postgres        replicated          1/1                 postgres:9.6        

```
Check where the service is running :
```
docker stack ps awx

Output : 

ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
l293rugcxofb        awx_postgres.1      postgres:9.6        laptop              Running             Running 24 seconds ago                       

```

### Deploy awx and supporting containers
```
docker stack deploy -c ./awx.yml awx
```

Using the commands above you can check that each supporting service started correctly.

The awx_awx service is the one which propagates the Postgres DB and connects to the RabbitMQ service.  To check on the progress of the awx service run :
```
docker service logs -f awx_awx 

or

make awx_logs
```

## Login

When all the services are started correctly you can login as admin/password on http://localhost:80

At this point you can follow the official awx documentation to setup inventories, templates and scheduled tasks : https://github.com/ansible/awx

## Tear down everything
```
docker stack rm awx
docker volume rm awx_postgres

## Caveats

I had some issues connecting between the awx container and the rabbitmq container as the guest user.  To work around this I created a test user and updated the connection.py script which is bundled with ansible/awx_task image.  There is also a 500 internal server error when running the scm scheduled check. Debugging at the moment. When running cleanup you may occasionally see this error :
```
Error response from daemon: unable to remove volume: remove awx_postgres: volume is in use - [e3e26d6e331cf5eaad9e3db53b6d3ff28aaac0494c58e3ce92d3a5ea9a16f190]
makefile:17: recipe for target 'remove' failed
make: *** [remove] Error 1

```

The service has been removed but there is still a handle open to the data volume so it can't be removed. You can run docker rm -f e3e26d6e331c and then make cleanup again.

## Appendix

### 1
```
docker stack deploy -c ./postgres.yml awx
Creating network awx_network
Creating service awx_postgres
docker stack deploy -c ./awx.yml awx
Creating service awx_rabbitmq
Creating service awx_memcached
Creating service awx_awx
Creating service awx_awx_web

```

### 2
```
docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                    PORTS
9a59l59uq6o2        awx_awx             replicated          1/1                 ansible/awx_task:1.0.1   
quaam4d3wh3u        awx_awx_web         replicated          1/1                 ansible/awx_web:1.0.1    *:80->8052/tcp
9dtaa2zqz1zg        awx_memcached       replicated          1/1                 memcached:alpine         
p21x7s4do32k        awx_postgres        replicated          1/1                 postgres:9.6             
d5nyxfh3ect1        awx_rabbitmq        replicated          1/1                 rabbitmq:3               

```

### 3
```
docker service logs -f awx_awx
awx_awx.1.lhr605tdntah@laptop    | Using /etc/ansible/ansible.cfg as config file
awx_awx.1.lhr605tdntah@laptop    | [DEPRECATION WARNING]: The sudo command line option has been deprecated in 
awx_awx.1.lhr605tdntah@laptop    | favor of the "become" command line arguments. This feature will be removed in 
awx_awx.1.lhr605tdntah@laptop    | version 2.6. Deprecation warnings can be disabled by setting 
awx_awx.1.lhr605tdntah@laptop    | deprecation_warnings=False in ansible.cfg.
awx_awx.1.lhr605tdntah@laptop    | 127.0.0.1 | SUCCESS => {
awx_awx.1.lhr605tdntah@laptop    |     "changed": true, 
awx_awx.1.lhr605tdntah@laptop    |     "db": "awx"
awx_awx.1.lhr605tdntah@laptop    | }
awx_awx.1.lhr605tdntah@laptop    | Operations to perform:
awx_awx.1.lhr605tdntah@laptop    |   Apply all migrations: auth, conf, contenttypes, django_celery_results, main, sessions, sites, social_django, sso, taggit
awx_awx.1.lhr605tdntah@laptop    | Running migrations:
awx_awx.1.lhr605tdntah@laptop    |   Applying contenttypes.0001_initial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying contenttypes.0002_remove_content_type_name... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying auth.0001_initial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying auth.0002_alter_permission_name_max_length... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying auth.0003_alter_user_email_max_length... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying auth.0004_alter_user_username_opts... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying auth.0005_alter_user_last_login_null... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying auth.0006_require_contenttypes_0002... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying auth.0007_alter_validators_add_error_messages... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying auth.0008_alter_user_username_max_length... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying taggit.0001_initial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying taggit.0002_auto_20150616_2121... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0001_initial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0002_squashed_v300_release... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0003_squashed_v300_v303_updates... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0004_squashed_v310_release... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying conf.0001_initial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying conf.0002_v310_copy_tower_settings... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying conf.0003_v310_JSONField_changes... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying conf.0004_v320_reencrypt... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying django_celery_results.0001_initial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0005_squashed_v310_v313_updates... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0005a_squashed_v310_v313_updates... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0005b_squashed_v310_v313_updates... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0006_v320_release... OK
awx_awx.1.lhr605tdntah@laptop    | 2017-12-30 14:45:15,945 DEBUG    awx.main.migrations Removing all Rackspace InventorySource from database.
awx_awx.1.lhr605tdntah@laptop    | 2017-12-30 14:45:16,262 DEBUG    awx.main.migrations Removing all Azure Credentials from database.
awx_awx.1.lhr605tdntah@laptop    | 2017-12-30 14:45:16,577 DEBUG    awx.main.migrations Removing all Azure InventorySource from database.
awx_awx.1.lhr605tdntah@laptop    | 2017-12-30 14:45:16,896 DEBUG    awx.main.migrations Removing all InventorySource that have no link to an Inventory from database.
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0007_v320_data_migrations... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0008_v320_drop_v1_credential_fields... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0009_v330_multi_credential... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0010_saved_launchtime_configs... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0011_blank_start_args... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0012_non_blank_workflow... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying main.0013_move_deprecated_stdout... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying sessions.0001_initial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying sites.0001_initial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying sites.0002_alter_domain_unique... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying social_django.0001_initial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying social_django.0002_add_related_name... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying social_django.0003_alter_email_max_length... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying social_django.0004_auto_20160423_0400... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying social_django.0005_auto_20160727_2333... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying social_django.0006_partial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying social_django.0007_code_timestamp... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying social_django.0008_partial_timestamp... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying sso.0001_initial... OK
awx_awx.1.lhr605tdntah@laptop    |   Applying sso.0002_expand_provider_options... OK
awx_awx.1.lhr605tdntah@laptop    | Default organization added.
awx_awx.1.lhr605tdntah@laptop    | Demo Credential, Inventory, and Job Template added.
awx_awx.1.lhr605tdntah@laptop    | Successfully registered instance 8444c30707e9
awx_awx.1.lhr605tdntah@laptop    | (changed: True)
awx_awx.1.lhr605tdntah@laptop    | Creating instance group tower
awx_awx.1.lhr605tdntah@laptop    | Added instance 8444c30707e9 to tower
awx_awx.1.lhr605tdntah@laptop    | (changed: True)

```

### 4
```
make e2e
docker stack deploy -c ./postgres.yml awx
Creating network awx_network
Creating service awx_postgres
docker stack deploy -c ./awx.yml awx
Creating service awx_rabbitmq
Creating service awx_memcached
Creating service awx_awx
Creating service awx_awx_web
docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                    PORTS
lgkjbnk82tjs        awx_awx             replicated          1/1                 ansible/awx_task:1.0.1   
k6vyndehzxht        awx_awx_web         replicated          1/1                 ansible/awx_web:1.0.1    *:80->8052/tcp
tha4ci0bh51g        awx_memcached       replicated          1/1                 memcached:alpine         
ak6efue4w83i        awx_postgres        replicated          1/1                 postgres:9.6             
kqlmmpqxmhjg        awx_rabbitmq        replicated          1/1                 rabbitmq:3               
docker stack rm awx
Removing service awx_awx
Removing service awx_awx_web
Removing service awx_memcached
Removing service awx_postgres
Removing service awx_rabbitmq
Removing network awx_network
sleep 10 
docker volume rm awx_postgres
awx_postgres

```
