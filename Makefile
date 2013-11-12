# TODO:
# 	* Passwordless sudo supported only
#   * install ssh key with ssh-copy-id

-include .makerc

all: upload update

install: install_base install_chef_server install_workstation
install_base: install_chef install_init
install_workstation: install_base install_chef install_init install_keys install_knife
install_chef_server: install_server run_server

install_chef:
	sudo gem install knife-solo berkshelf

install_init:
	knife solo init .
	-mkdir -p .chef/keys

install_server:
	cp nodes/my.cool.node.json.sample nodes/${CHEF_SERVER_HOSTNAME}.json
	knife solo prepare $(CHEF_SERVER_USERNAME)@$(CHEF_SERVER_HOSTNAME)
	knife solo cook $(CHEF_SERVER_USERNAME)@$(CHEF_SERVER_HOSTNAME)

run_server:
ifneq (`echo $(chef_server_username)`,root)
			ssh -o StrictHostKeyChecking=no -l ${CHEF_SERVER_USERNAME} ${CHEF_SERVER_HOSTNAME} "sudo chef-server-ctl start"
else
			ssh -o StrictHostKeyChecking=no -l ${CHEF_SERVER_USERNAME} ${CHEF_SERVER_HOSTNAME} "chef-server-ctl start"
endif

install_keys:
ifneq (`echo $(CHEF_SERVER_USERNAME)`,root)
	ssh -o StrictHostKeyChecking=no -l ${CHEF_SERVER_USERNAME} ${CHEF_SERVER_HOSTNAME} "sudo chown -R ${CHEF_SERVER_USERNAME} /etc/chef-server/*.pem"
endif
	scp ${CHEF_SERVER_USERNAME}@${CHEF_SERVER_HOSTNAME}:/etc/chef-server/*.pem .chef/keys/

install_knife:
	knife configure -i --admin-client-key=./.chef/keys/admin.pem \
					   --admin-client-name=admin \
					   --server-url "https://${CHEF_SERVER_HOSTNAME}:443" \
					   --editor vim \
					   --repository ${CHEF_REPO_PATH} \
					   --user=ubuntu  \
					   --validation-key=./.chef/keys/chef-validator.pem \
					   --print-after \
					   --validation-client-name=chef-validator -y
upload:
	berks install
	knife cookbook upload -a

update: upload update_envs update_nodes update_roles

update_envs:
	knife environment from file environments/*
update_nodes:
	knife node from file nodes/*
update_roles:
	knife role from file roles/*

server_destroy:
	ssh ${CHEF_SERVER_USERNAME}@${CHEF_SERVER_HOSTNAME} 'sudo rm -rf /opt/chef /var/chef/ /etc/chef /etc/chef-server /root/chef-solo /root/install.sh'

server_debug:
	ssh ${CHEF_SERVER_USERNAME}@${CHEF_SERVER_HOSTNAME} 'sudo cat /var/chef/cache/chef-stacktrace.out'

destroy:
	-rm -rf .chef
	-rm -rf Berksfile.lock
	-rm -rf cookbooks
	-rm -rf data_bags
	-rm -rf environments
	-rm -rf nodes/*.json
	-rm -rf nodes/*.rb
	-rm -rf nodes/*.json
	-rm -rf site-cookbooks
	-rm -rf tmp

help:
	$(info      +-----------------------------------------------------------------+ )
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
