rfc822.io
=========

An ansible setup for The Perfect Mailserver(tm) ;)

* apt install python-pip
* pip install ansible
* ansible-playbook mailserver.yml

* python3 -c 'import crypt,getpass; print(crypt.crypt(getpass.getpass(), crypt.mksalt(crypt.METHOD_SHA512)))'
