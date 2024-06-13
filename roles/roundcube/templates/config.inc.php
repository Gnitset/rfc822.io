<?php

$config['db_dsnw'] = 'pgsql://{{ db_user }}_roundcube:{{ password_postgres_roundcube }}@unix(/var/run/postgresql)/roundcubemail';
$config['imap_host'] = 'tls://{{ ansible_fqdn }}';
$config['smtp_host'] = 'tls://{{ ansible_fqdn }}';
$config['auto_create_user'] = true;
$config['login_autocomplete'] = 2;
$config['sent_mbox'] = 'Sent Messages';
$config['trash_mbox'] = 'Deleted Messages';
$config['message_show_email'] = true;
$config['proxy_whitelist'] = array('127.0.0.1', '172.17.0.1');

$config['plugins'] = array('archive', 'managesieve', 'zipdownload');
