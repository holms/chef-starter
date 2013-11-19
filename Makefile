
# TODO:
# 	* Passwordless sudo supported only
#   * install ssh key with ssh-copy-id

-include .makerc

SHELL 		:= /bin/bash

SSH_CREDS := ${CHEF_SERVER_USERNAME}@${CHEF_SERVER_HOSTNAME}
SSH	  := ssh -o StrictHostKeyChecking=no ${SSH_CREDS}

all: upload update

install: destroy install_base install_chef_server install_workstation post_message
install_base: install_chef install_init
install_workstation: install_base install_chef install_init install_keys install_knife
install_chef_server: server_destroy prepare_server install_server run_server

install_chef:
	@-echo -e "\n\e[31m Installing ruby and make packages ...\e[39m\n"
	sudo apt-get install ruby1.9.3 make -y
	@-echo -e "\n\e[31m Installing knife-solo and berkshelf gems ...\e[39m\n"
	sudo gem install --verbose --no-ri --no-rdoc knife-solo berkshelf

install_init:
	@-echo -e "\n\e[31m Initializing chef repository ...\e[39m\n"
	knife solo init .
	-mkdir -p .chef/keys
	cp Berksfile.sample Berksfile

prepare_server:
	@-echo -e "\n\e[31m Copying your public ssh key to chef-server ...\e[39m\n"
	ssh-copy-id ${CHEF_SERVER_USERNAME}@${CHEF_SERVER_HOSTNAME}
	@-echo -e "\n\e[31m Adding chef-server username to passwordless sudoers ...\e[39m\n"
	ssh -o StrictHostKeyChecking=no -t -l ${CHEF_SERVER_USERNAME} ${CHEF_SERVER_HOSTNAME} "echo '${CHEF_SERVER_USERNAME} ALL = (ALL) NOPASSWD: ALL' | sudo tee -a  /etc/sudoers "

install_server:
	@-echo -e "\n\e[31m Copying chef-server node template as node config ...\e[39m\n"
	cp nodes/chef.server.json.sample nodes/${CHEF_SERVER_HOSTNAME}.json
	@-echo -e "\n\e[31m Bootstraping chef-server ...\e[39m\n"
	knife solo prepare $(CHEF_SERVER_USERNAME)@$(CHEF_SERVER_HOSTNAME)
	@-echo -e "\n\e[31m Cooking chef-server ...\e[39m\n"
	knife solo cook $(CHEF_SERVER_USERNAME)@$(CHEF_SERVER_HOSTNAME)

run_server:
	@-echo -e "\n\e[31m Starting chef-server ...\e[39m\n"
	${SSH} "sudo chef-server-ctl start"

install_keys:
	@-echo -e "\n\e[31m Installing chef-server keys to your workstation ...\e[39m\n"
	${SSH} "sudo chown -R ${CHEF_SERVER_USERNAME} /etc/chef-server/*.pem"
	scp ${SSH_CREDS}:/etc/chef-server/*.pem .chef/keys/

install_knife:
	@-echo -e "\n\e[31m Configuring workstation ...\e[39m\n"
	knife configure -i --admin-client-key=./.chef/keys/admin.pem \
					   --admin-client-name=admin \
					   --server-url "https://${CHEF_SERVER_HOSTNAME}" \
					   --editor vim \
					   --repository ${CHEF_REPO_PATH} \
					   --user=${CHEF_NODE_USERNAME} \
					   --validation-client-name=chef-validator \
					   --validation-key=./.chef/keys/chef-validator.pem \
					   --print-after -y
	knife configure client .chef/

update:
	@-echo -e "\n\e[31m Installing cookbooks depedencies ...\e[39m\n"
	berks install --path ./cookbooks
	@-echo -e "\n\e[31m Uploading all cookbooks to chef server...\e[39m\n"
	knife upload cookbooks /cookbooks
	knife upload environments /environments/*.json
	knife upload nodes /nodes/*.json
	knife upload roles /roles/*.json


server_destroy:
	@-echo -e "\n\e[31m Unistalling chef-server ...\e[39m\n"
	-${SSH} "sudo chef-server-ctl uninstall"
	-${SSH} "sudo dpkg -P chef-server"
	-${SSH} "sudo apt-get autoremove -y"
	-${SSH} "sudo apt-get purge -y"
	-${SSH} "sudo pkill -f /opt/chef"
	-${SSH} "sudo pkill -f beam"
	-${SSH} "sudo  pkill -f postgres"
	-${SSH} "sudo rm -rf /etc/chef-server /etc/chef /opt/chef-server /opt/chef /root/.chef /var/opt/chef-server/ /var/chef /var/log/chef-server/"

server_debug:
	-${SSH} 'sudo cat /var/chef/cache/chef-stacktrace.out'

destroy:
	@-echo -e "\n\e[31m\e[5m WARNING! \e[25m\e[31m THIS WILL DESTROY CHEF-SERVER AND YOUR WORKSTATION CONFIGURATION, DO YOU REALLY WANT TO PROCESEED???!!111 IF NO - PRESS CTRL+C \e[39m\n"
	@-echo -e "Press enter to confirm: "; read confirm
	-rm -rf .chef
	-rm -rf Berksfile.lock
	-rm -rf cookbooks
	-rm -rf data_bags
	-rm -rf environments
	-rm -rf site-cookbooks
	-rm -rf tmp

post_message:

nodes := $(filter-out $(wildcard nodes/*$(CHEF_SERVER_HOSTNAME)* nodes/*.sample*   ),$(wildcard nodes/* ))
nodes := $(patsubst nodes/%.json,node_%,$(nodes))

.PHONY: cook
cook : $(nodes)
node_%:
	ssh -t ${CHEF_NODE_USERNAME}@$* "sudo chef-client run"

.PHONY: node_create
node_create:
	@-echo "New node FQDN: "; read node_fqdn; \
	echo -e "\n\e[31mCopying node template to $$node_fqdn.json ...\e[39m"; \
	cp nodes/my.cool.hostname.json.sample nodes/$$node_fqdn.json; \
	sed -i 's/  \"name\": \"\",/  \"name\": \"'$$node_fqdn'\",/g' nodes/$$node_fqdn.json; \
	vim nodes/$$node_fqdn.json; \
	echo -e "\n\e[31mCopying your public keys to node ...\n\e[39m"; \
	ssh-copy-id ${CHEF_NODE_USERNAME}@$$node_fqdn ; \
	echo -e "\n\e[31mAdding $$node_fqdn to chef server ...\n\e[39m"; \
	knife upload /nodes/$$node_fqdn.json ; \
	knife node from file nodes/$$node_fqdn.json; \
	echo -e "\n\e[31mCopying validation.pem and client.rb to node /etc/chef ...\n\e[39m"; \
	ssh ${CHEF_NODE_USERNAME}@$$node_fqdn "mkdir -p ~/.chef" ; \
	echo -e "\n\e[31mBootstraping $$node_fqdn ...\n\e[39m"; \
	knife bootstrap -x ${CHEF_NODE_USERNAME} $$node_fqdn --sudo

help:
	$(info		+-----------------------------------------------------------------+ )
	$(info  	|                  Chef automation utility                        | )
	$(info  	|-----------------------------------------------------------------| )
	$(info  	| Author: Roman Gorodeckij                                        | )
	$(info  	| Email:  Roman_Gorodeckij@dell.com                               | )
	$(info  	|                                                                 | )
	$(info  	| All available commands:                                         | )
	$(info  	|                                                                 | )
	$(info  	|    make           - will do make update && make upload          | )
	$(info  	|    make update    - will only update envs,nodes,roles           | )
	$(info  	|    make upload    - will only upload cookbooks                  | )
	$(info  	|    make install   - will deploy chef-server                     | )
	$(info  	|    make help      - shows this box                              + )
	$(info  	+                                                                 | )
	$(info  	|    Don't forget to rename .makerc.sample to .makerc             | )
	$(info  	|    Edit .makerc to set your chef-server hostname and username   | )
	$(info  	|    For now only ssh keys authorization supported.               | )
	$(info  	|                                                                 | )
	$(info  	|                                                                 | )
	$(info  	|                                                                 | )
	$(info  	+-----------------------------------------------------------------+ )
