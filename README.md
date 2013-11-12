Chef-Starter
============

This is PRE-ALPHA! For testing only!
Please fork and help a project, if you can do better makefile scripting, or found something to fix.

Use-case
--------

Primary use-case I had, is to deploy chef-server from my own workstation with minimal fuss.
Also this prolly would be good for initialising new chef repo and setuping workstation too.

Requirements
------------

* This setup requires a proper FQDN. If you're in intranet, set one in /etc/hosts
* For now you have to have ```sudo``` other options will be added later
* For now ssh key is required, other options will be added later

Usage
-----

Create .makerc

```
cp .makerc.sample .makerc
```
Set your chef-server hostname and username, repo path, and you ready to go.

Launch chef-server and your workstation setup:

```
make install
```

Check other available commands inside Makefile or just ```make help```

BUG: Knife-configure problems
-----------------------------

There's a problem with .chef/knife.rb after knife configure -i. Knife doesn't add path of many directories so hack is

```
cookbook_path    ["cookbooks", "site-cookbooks"]
node_path        "nodes"
role_path        "roles"
environment_path "environments"
data_bag_path    "data_bags"
#encrypted_data_bag_secret "data_bag_key"

knife[:berkshelf_path] = "cookbooks"

```

so add this stuff to .chef/knife.rb manually after ```make install``` is finished.



=======
chef-starter
============

Makefile for automating chef-server and chef-workstation setup
