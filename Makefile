
# TODO:
#	* Passwordless sudo supported only

-include .makerc

SSH_CREDS := ${CHEF_SERVER_USERNAME}@${CHEF_SERVER_HOSTNAME}
SSH	  := ssh -t -o StrictHostKeyChecking=no ${SSH_CREDS}
SHELL	  := /bin/bash 

rvm  	  := $(shell { type rvm; } 2>/dev/null)
gem       := $(shell { type gem; } 2>/dev/null)
user 	  := $(shell { whoami; } )
sshcopyid := $(shell { type ssh-copy-id; } 2>/dev/null)


ports := $(shell { type port; } 2>/dev/null)
apt   := $(shell { type apt-get; } 2>/dev/null)
yum   := $(shell { type yum; } 2>/dev/null)

# OSX SUPPORT
ifdef ports
	SHELL := /opt/local/bin/bash  # must be installed from macports, or else bash colors won't work
	OSX   := true
endif

# DEBIAN/UBUNTU SUPPORT
ifdef apt
	DEB   := true
endif

# RHEL SUPPORT
ifdef yum
	RHEL  := true
endif


all: update
install_workstation: install_keys install_knife
install_chef_server: install_ssh_key destroy_server prepare_server install_server run_server

install_solo: destroy_local install_chef install_init
install: checks install_solo install_chef_server install_workstation post_message

checks:
ifeq ("$(wildcard ./.makerc)", "")
	@echo -e "\n\e[31m .makerc IS NOT FOUND! Please copy .makerc.example to .makerc and edit it! \e[39m\n"
	@exit 1
endif

install_ssh_key:
ifndef sshcopyid
	sudo scp -r ${SSH_CREDS}:/usr/bin/ssh-copy-id /usr/bin
	sudo chmod +x /usr/bin/ssh-copy-id
endif
	@echo -e "\n\e[31m Copying your public ssh key to chef-server ...\e[39m\n"
	ssh-copy-id ${SSH_CREDS}

install_chef:
	@-echo -e "\n\e[31m Installing ruby and make packages ...\e[39m\n"

ifdef OSX
	sudo port -v install ruby19 +nosuffix
	sudo port select --set ruby ruby19
	sudo port -v install gmake rb19-bundler
	-sudo ln -s /opt/local/bin/gem-1.9 /opt/local/bin/gem
	-sudo ln -s /opt/local/bin/irb-1.9 /opt/local/bin/irb
	-sudo ln -s /opt/local/bin/bundle-1.9 /opt/local/bin/bundle
endif

ifdef DEB
	sudo apt-get install ruby1.9.3 make  -y
	sudo gem install --no-ri --no-rdoc bundler
endif

ifdef RHEL

ifndef gem
ifdef rvm
	@-echo -e "\n\e[31m Ruby 2.1.1 will be compiled.... \e[39m\n"
	@-rvmsudo rvm get stable --auto-dotfiles
	@-rvmsudo rvm install ruby-2
	@-rvmsudo rvm alias create default ruby-2.1.1
	-@echo -e "\n \e[33m"
	-@echo -e "    +--------------------------------------------+"
	-@echo -e "    |	    Ruby is installed!              |"
	-@echo -e "    |--------------------------------------------|"
	-@echo -e "    | Please login and logout from shell to	    |"
	-@echo -e "    | activate ruby env. And launch make install |"
	-@echo -e "    | command again. Blame rvm devs for this     |"
	-@echo -e "    +--------------------------------------------+"
	-@echo -e ""
	-@echo -e " Exiting..."
	-@echo -e "\e[39m"
	@exit 1
endif
endif

ifndef rvm
	@-echo -e "\n\e[31m RVM will be installed.... \e[39m\n"
	-\curl -sSL https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer | sudo bash -s stable
	-sudo usermod -a -G rvm $(user)
	-@echo -e "\n \e[33m"
	-@echo -e "    +-------------------------------------------+"
	-@echo -e "    |	    RVM is installed!                  |"
	-@echo -e "    |-------------------------------------------|"
	-@echo -e "    | Please login and logout from shell to	   |"
	-@echo -e "    | activate rvm profile. And launch make	   |"
	-@echo -e "    | intall command again                      |"
	-@echo -e "    +-------------------------------------------+"
	-@echo -e ""
	-@echo -e " Exiting..."
	-@echo -e "\e[39m"
	@exit 1
endif


endif

	@-echo -e "\n\e[31m Installing knife-solo and berkshelf gems ...\e[39m\n"
ifdef RHEL
	rvmsudo bundle install
endif
ifndef RHEL
	sudo bundle install
endif

install_init:
	@-echo -e "\n\e[31m Initializing chef repository ...\e[39m\n"
	knife solo init repo
	@-if [ ! -f Berksfile ] ; \
	then \
	   cp Berksfile.sample repo/Berksfile; \
	fi;
	-rm -rf repo/cookbooks
	-cd repo ; berks vendor cookbooks
	-mkdir -p repo/.chef/keys

prepare_server:
ifneq ($(CHEF_SERVER_USERNAME),root)
	@-echo -e "\n\e[31m Adding chef-server username to passwordless sudoers ...\e[39m\n"
	ssh -o StrictHostKeyChecking=no -t -l ${CHEF_SERVER_USERNAME} ${CHEF_SERVER_HOSTNAME} "echo '${CHEF_SERVER_USERNAME} ALL = (ALL) NOPASSWD: ALL' | sudo tee -a  /etc/sudoers "
endif

install_server:
	@-echo -e "\n\e[31m Copying chef-server node template as node config ...\e[39m\n"
	-cd repo/nodes ; cp ../../.nodes/chef.server.json ${CHEF_SERVER_HOSTNAME}.json
	-cd repo/nodes ; cp ../../.nodes/my.cool.hostname.json.sample ./
	-cd repo/roles ; cp ../../.roles/my.cool.role.json.sample my.cool.role.json.sample
	-cd repo/roles ; cp ../../.roles/chef-server.json chef-server.json
	@-echo -e "\n\e[31m Bootstraping chef-server ...\e[39m\n"
	cd repo ; knife solo prepare $(SSH_CREDS)
	@-echo -e "\n\e[31m Cooking chef-server ...\e[39m\n"
	cd repo ; knife solo cook $(SSH_CREDS)

run_server:
	@-echo -e "\n\e[31m Starting chef-server ...\e[39m\n"
	-${SSH} "sudo chef-server-ctl start"

install_keys:
	@-echo -e "\n\e[31m Installing chef-server keys to your workstation ...\e[39m\n"
	${SSH} "sudo chown -R ${CHEF_SERVER_USERNAME} /etc/chef-server/*.pem"
	scp ${SSH_CREDS}:/etc/chef-server/*.pem repo/.chef/keys/

install_knife:
	@-echo -e "\n\e[31m Configuring workstation ...\e[39m\n"
	cd repo ; knife configure -i --admin-client-key=./.chef/keys/admin.pem \
					   --admin-client-name=admin \
					   --server-url "https://${CHEF_SERVER_HOSTNAME}" \
					   --editor vim \
					   --repository ${CHEF_REPO_PATH} \
					   --user=${CHEF_NODE_USERNAME} \
					   --validation-client-name=chef-validator \
					   --validation-key=./.chef/keys/chef-validator.pem \
					   --print-after -y
	cd repo ; knife configure client .chef/

update:
	@-echo -e "\n\e[31m Installing cookbooks depedencies ...\e[39m\n"
	-rm -rf repo/Berksfile.lock
	-cd repo ; berks install
ifdef CHEF_SERVER_HOSTNAME
	@-echo -e "\n\e[31m Uploading all cookbooks to chef server...\e[39m\n"
	rm -rf repo/cookbooks
	cd repo ; berks vendor cookbooks
	cd repo ; knife cookbook upload -a --force -o  cookbooks/
	#cd repo ; berks upload --ssl-verify=false
	#cd repo ; knife upload cookbooks /cookbooks
	#cd repo ; knife upload cookbooks /site-cookbooks
	cd repo ; knife upload environments /environments/*.json
	@-echo -e "\n\e[33m **** Nodes update depricated and it destroys node state, other cookbook may fail because of this  *****\e[39m\n"
	#knife upload nodes /nodes/*.json
	cd repo ; knife upload roles /roles/*.json
endif

destroy_server:
	@-echo -e "\n\e[31m\e[5m WARNING! \e[25m\e[31m THIS WILL DESTROY CHEF-SERVER, DO YOU REALLY WANT TO PROCESEED???!!111 IF NO - PRESS CTRL+C \e[39m\n"
	@-echo -e "Press enter to confirm: "; read confirm
	@-echo -e "\n\e[31m Unistalling chef-server ...\e[39m\n"
	-${SSH} "sudo chef-server-ctl uninstall"
ifeq ($(CHEF_SERVER_OS),debian)
	-${SSH} "sudo dpkg -P chef-server; sudo apt-get autoremove -y; sudo apt-get purge -y"
endif
ifeq ($(CHEF_SERVER_OS),rhel)
	-${SSH} "sudo rpm -e \`rpm -qa | grep chef-server\`"
endif
	-${SSH} "sudo pkill -f /opt/chef"
	-${SSH} "sudo pkill -f beam"
	-${SSH} "sudo pkill -f postgres"
	-${SSH} "sudo rm -rf /etc/chef-server /etc/chef /opt/chef-server /opt/chef /root/.chef /root/chef-solo /usr/bin/chef* /var/opt/chef-server/ /var/chef /var/log/chef-server/ /tmp/hsperfdata_chef_server"

server_debug:
	-${SSH} 'sudo cat /var/chef/cache/chef-stacktrace.out'

destroy_local:
	@-echo -e "\n\e[31m\e[5m WARNING! \e[25m\e[31m THIS WILL DESTROY YOUR WORKSTATION CONFIGURATION, DO YOU REALLY WANT TO PROCESEED???!!111 IF NO - PRESS CTRL+C \e[39m\n"
	@-echo -e "Press enter to confirm: "; read confirm
	-rm -rf repo
	-rm -rf .chef
	-rm -rf Berksfile
	-rm -rf Berksfile.lock
	-rm -rf tmp


post_message:
	@-echo -e "\n\e[31m We done! \e[39m\n"

nodes := $(filter-out $(wildcard nodes/*$(CHEF_SERVER_HOSTNAME)* nodes/*.sample*   ),$(wildcard nodes/* ))
nodes := $(patsubst nodes/%.json,node_%,$(nodes))

.PHONY: cook-all
cook-all : $(nodes)
node_%:
	ssh -t ${CHEF_NODE_USERNAME}@$* "sudo chef-client"

.PHONY: cook
cook:
	@-echo -e "\n\e[31mHere's a list of your nodes: "
	@-echo -e "\e[33m "
	@-cd repo ; knife node list
	@-echo -e "\e[39m"
	@-echo "Node FQDN: "; read node_fqdn; \
	ssh -t ${CHEF_NODE_USERNAME}@$$node_fqdn "sudo chef-client"

.PHONY: node
node:
	@-echo "New node FQDN: "; read node_fqdn; \
	echo -e "\n\e[31mCopying node template to $$node_fqdn.json ...\e[39m"; \
	cp repo/nodes/my.cool.hostname.json.sample repo/nodes/$$node_fqdn.json; \
	sed -i 's/  \"name\": \"\",/  \"name\": \"'$$node_fqdn'\",/g' repo/nodes/$$node_fqdn.json; \
	vim repo/nodes/$$node_fqdn.json; \
	echo -e "\n\e[31mCopying your public keys to node ...\n\e[39m"; \
	ssh-copy-id ${CHEF_NODE_USERNAME}@$$node_fqdn ; \
	echo -e "\n\e[31mAdding $$node_fqdn to chef server ...\n\e[39m"; \
	cd repo ; knife upload nodes/$$node_fqdn.json ; \
	cd repo ; knife node from file nodes/$$node_fqdn.json; \
	echo -e "\n\e[31mCopying validation.pem and client.rb to node /etc/chef ...\n\e[39m"; \
	ssh -t ${CHEF_NODE_USERNAME}@$$node_fqdn "mkdir -p ~/.chef" ; \
	echo -e "\n\e[31mBootstraping $$node_fqdn ...\n\e[39m"; \
	cd repo ; knife bootstrap -x ${CHEF_NODE_USERNAME} $$node_fqdn --sudo; \
	cd repo ; knife upload /nodes/$$node_fqdn.json

rebootstrap:
	@-echo -e "\n\e[31mHere's a list of your nodes: "
	@-echo -e "\e[33m "
	@-cd repo ; knife node list
	@-echo -e "\e[39m "
	@-echo "Enter node FQDN: "; read node_fqdn; \
	echo -e "\n\e[31mRemoving chef-client from  $$node_fqdn.json ...\e[39m"; \
	cd repo ; knife node delete $$node_fqdn; \
	knife client delete $$node_fqdn; \
	ssh-copy-id ${CHEF_NODE_USERNAME}@$$node_fqdn; \
	ssh -t ${CHEF_NODE_USERNAME}@$$node_fqdn  "sudo rm -rf /etc/chef /var/chef /opt/chef; rm -rf ~/.chef"; \
	echo -e "\n\e[31mBootstraping $$node_fqdn.json ...\e[39m"; \
	knife bootstrap -x ${CHEF_NODE_USERNAME} $$node_fqdn --sudo;\
	echo -e "\n\e[31mUploading your node configuration ... \n\e[39m\n"; \
	knife upload /nodes/$$node_fqdn.json

