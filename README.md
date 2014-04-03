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

If you won't follow these requirements, Makefile will fail.

* Currently chef-server provisioning only works in RHEL!
* Proper FQDN on your chef-server! If you're in intranet, set one in /etc/hosts
* You required to have public key in your ~/.ssh/ directory. It will be copied to a chef-server node.
* SUDO enabled unix. Notice: For cloud users: Don't forget to comment ```#Default requiretty``` in your sudoers file or else Makefile will fail
* Your sudo user must be the same on all the nodes as server machine (propose for better practise in issue)


Debian/Ubuntu support:
----------------------

Should work out of the box.

OSX support:
------------

    * Install macports
    * Install bash via macports (Default bash won't work)

Currently there's no support for homebrew, feel free to contribute.

BUG: there's a strange problem which occurs on my iMac, but never happens on macbook air, with totally indentical version of software. If knife command won't be found when you launched Makefile, add this to your ```~/.profile```

```
export GEM_HOME="/opt/local/lib/ruby1.9/gems/1.9.1/"
export GEM_PATH="/opt/local/lib/ruby1.9/gems/1.9.1/"
export PATH=/opt/local/lib/ruby1.9/gems/1.9.1/bin:$PATH
```

RHEL support:
-------------

System-wide RVM will be installed and ruby will be compiled. If RVM already exists, then ruby will and rubygems will be upgraded. Currently ```ruby2``` is used.

After you run ```make install``` and ```rvm``` will be installed, you'll have to log-out and log-in to shell again. This is due to environment variables, a requirement from ```rvm```

Configure
---------

Create .makerc
```
cp .makerc.sample .makerc
```
Set your chef-server hostname and username, repo path, and you ready to go.


This will setup chef-server and workstation
```
make install
```

This will only install chef-solo
```
make install_solo
```

Congrats! Now you have ./repo folder ready, it's completely ignored, you can create a git repo out of it.

Usage
-----


Run updates: get cookbooks, upload all cookbooks, update envs/roles/nodes

```
make # or make update
```

Create and bootstrap a node
```
make node
```



Rebootstrap node
```
make rebootstrap
```

Cook specified node, you will be asked to enter node name, and node list will be shown
```
make cook
```


Destroy everything that's been generated
```
make destroy
```

Remove chef installation on server
```
make server_destroy
```



