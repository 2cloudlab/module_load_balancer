#!/bin/bash
sudo su
export APP_PATH=/srv/digolds
export UNIX_SOCK=unix:$APP_PATH/www/digolds.sock
export GROUP=www-data
export USER=www-data
export PATH=$PATH:/usr/local/bin
mkdir $APP_PATH
groupadd $GROUP
adduser -g $GROUP $USER

yum update -y
yum -y install epel-release
yum -y install wget
yum -y install nginx
yum -y install python3

wget https://github.com/digolds/digolds_sample/archive/v0.0.1.tar.gz -P /tmp
tar xf /tmp/v0.0.1.tar.gz -C $APP_PATH
ln -s $APP_PATH/digolds_sample-0.0.1/personal-blog $APP_PATH/www
chown $USER:$GROUP $APP_PATH/www
chown -R $USER:$GROUP $APP_PATH/digolds_sample-0.0.1/personal-blog
#python3 -m venv $APP_PATH/digolds_sample-0.0.1
#source $APP_PATH/digolds_sample-0.0.1/bin/activate
pip3 install gunicorn
pip3 install supervisor
pip3 install -r $APP_PATH/digolds_sample-0.0.1/requirements.txt

OUTPUT=$(which gunicorn)
export GUNICORN_BIN_NAME=$OUTPUT

gunicorn_config="[supervisord]
logfile=/srv/digolds/supervisord.log    ; supervisord log file
logfile_maxbytes=50MB                           ; maximum size of logfile before rotation
logfile_backups=10                              ; number of backed up logfiles
loglevel=error                                  ; info, debug, warn, trace
pidfile=/var/run/supervisord.pid                ; pidfile location
nodaemon=false                                  ; run supervisord as a daemon
minfds=1024                                     ; number of startup file descriptors
minprocs=200                                    ; number of process descriptors
user=root                                       ; default user
childlogdir=/srv/digolds/               ; where child log files will live

[unix_http_server]
file=/tmp/supervisor.sock

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[program:gunicorn]
command=$GUNICORN_BIN_NAME -b $UNIX_SOCK wsgiapp:wsgi_app
directory=$APP_PATH/www
user=$USER
autostart=true
autorestart=true
redirect_stderr=true"

nginx_config="
user $USER $GROUP;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;
events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    # include /etc/nginx/conf.d/*.conf;

    upstream digolds_server {
            # fail_timeout=0 means we always retry an upstream even if it failed
            # to return a good HTTP response

            # for UNIX domain socket setups
            server $UNIX_SOCK fail_timeout=0;
            # for a TCP configuration
            # server 192.168.0.7:8000 fail_timeout=0;
        }

    server {
        listen       80 default_server;

        # Load configuration files for the default server block.

        location / {
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header Host \$http_host;
            # we don't want nginx trying to do something clever with
            # redirects, we set the Host: header above already.
            proxy_redirect off;
            proxy_pass http://digolds_server;
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
    }
}"

echo "$gunicorn_config" > $APP_PATH/www/gunicorn.conf
echo "$nginx_config" > /etc/nginx/nginx.conf

setenforce Permissive
supervisord -c $APP_PATH/www/gunicorn.conf
# supervisorctl -c $APP_PATH/www/gunicorn.conf start gunicorn
systemctl start nginx