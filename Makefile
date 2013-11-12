
# TODO:
# 	* Passwordless sudo supported only
#   * install ssh key with ssh-copy-id

-include .makerc

NO_COLOR=$(info -e "\x1b[0m" )
OK_COLOR=$(info -e "\x1b[32;01m")
ERROR_COLOR=$(info -e "\x1b[31;01m")
WARN_COLOR=$(info -e "\x1b[33;01m")

SSH_CREDS := ${CHEF_SERVER_USERNAME}@${CHEF_SERVER_HOSTNAME}
SSH	  := ssh -o StrictHostKeyChecking=no ${SSH_CREDS}

all: upload update

install: destroy install_base install_chef_server install_workstation
install_base: install_chef install_init
install_workstation: install_base install_chef install_init install_keys install_knife
install_chef_server: prepare_server server_destroy install_server run_server

install_chef:
	sudo apt-get install ruby1.9.3 make -y
	sudo gem install --verbose --no-ri --no-rdoc knife-solo berkshelf

install_init:
	knife solo init .
	-mkdir -p .chef/keys

prepare_server:
	ssh-copy-id ${CHEF_SERVER_USERNAME}@${CHEF_SERVER_HOSTNAME}
	ssh -o StrictHostKeyChecking=no -t -l ${CHEF_SERVER_USERNAME} ${CHEF_SERVER_HOSTNAME} "info '${CHEF_SERVER_USERNAME} ALL = (ALL) NOPASSWD: ALL' | sudo tee -a  /etc/sudoers "

install_server:
	cp nodes/my.cool.node.json.sample nodes/${CHEF_SERVER_HOSTNAME}.json
	knife solo prepare $(CHEF_SERVER_USERNAME)@$(CHEF_SERVER_HOSTNAME)
	knife solo cook $(CHEF_SERVER_USERNAME)@$(CHEF_SERVER_HOSTNAME)

run_server:
	${SSH} "sudo chef-server-ctl start"

install_keys:
	${SSH} "sudo chown -R ${CHEF_SERVER_USERNAME} /etc/chef-server/*.pem"
	scp ${SSH_CREDS}:/etc/chef-server/*.pem .chef/keys/

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

post_message:
$(info 																															)
$(info 	*******************************************************************************************************************  )
$(info 	BUG: Knife-configure problems 																					)
$(info	)
$(info	There's a problem with .chef/knife.rb after knife configure -i. Knife doesn't add path of many directories so hack is	)
$(info	)
$(info	cookbook_path    ["cookbooks", "site-cookbooks"]																	)
$(info	node_path        "nodes"																							)
$(info	role_path        "roles"																						)
$(info	environment_path "environments"																					)
$(info	data_bag_path    "data_bags"																					)
$(info	#encrypted_data_bag_secret "data_bag_key"																		)
$(info	)
$(info	knife[:berkshelf_path] = "cookbooks"																			)
$(info																												)
$(info	 Add this stuff to .chef/knife.rb manually, after make install failed. Then relaunch make install			)
$(info   ******************************************************************************************************************  )

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
