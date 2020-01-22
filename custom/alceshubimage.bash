#!/bin/bash -ex

FLIGHT_APPLIANCE_MENU_BRANCH=dev/vpn
FLIGHT_GUI_BRANCH=master

########Base Packages###########
yum -y install patch autoconf automake bison bzip2 gcc-c++ libffi-devel libtool \
patch readline-devel ruby sqlite-devel zlib-devel glibc-headers glibc-devel openssl-devel make unzip wget git
yum -y install epel-release
yum -y install openvpn easy-rsa bind-utils

#########Install flight runway & related tools#########
wget https://openflighthpc.s3-eu-west-1.amazonaws.com/repos/openflight/openflight.repo -O /etc/yum.repos.d/openflight.repo
yum -y makecache
yum -y install flight-runway
yum -y install flight-cloud-client

########Install menu system##############
git clone https://github.com/alces-software/flight-appliance-menu.git -b $FLIGHT_APPLIANCE_MENU_BRANCH /opt/appliance

wget https://cache.ruby-lang.org/pub/ruby/2.6/ruby-2.6.3.tar.gz -O /tmp/ruby-2.6.3.tar.gz
cd /tmp
tar -zxvf ruby-2.6.3.tar.gz
cd ruby-2.6.3
./configure --prefix /opt/appliance/ruby-2.6.3
make -j4
make install
cd /opt/appliance
/opt/appliance/ruby-2.6.3/bin/bundle install --path vendor

########Users and groups for appliance ############ 
groupadd engineers
groupadd operators
groupadd vpn

#engineer user - for alces use
useradd engineer -G engineers -G operators
usermod -L engineer
usermod engineer --shell /sbin/nologin
mkdir -p /home/engineer/.ssh
cat << EOF > /home/engineer/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwLOsrj0oIyMKOKzSCpAA6EAYLivsVBUAeHJkc/xW+peoq9i1AfzVjEA3lgBnMrIksui9kvXbg0kQFgUegRlcb10mVR+KhLHRU8rmIrNzXfO8TVNaQhlF8WI71Q0oV5lWyH0CnPvr+LRJIhThXmzLou/lNd3frn1kTWlQKwPcaWFzniZzwJ7anWW2FlryVwUwPw+ki2b+D9o3QoVFn+eordKUDfMVIvdZjQfGSNJ1CXQh99XuOfUhphzpWH88fNEY8s3jk5SiOgf8s6dfl9wZEfNf6aU4MAViP1BKVd9wuLZ5Bv1tEMWUqN3Zp+hYiyzOkDYmviPPxk1BdqmAWUUQR
EOF
chmod 600 /home/engineer/.ssh/authorized_keys

#alces operator - default user account
useradd alces-operator -G operators
usermod alces-operator --shell /opt/appliance/bin/cli.rb
usermod -L alces-operator

#operator sudo rule to allow system commands
cat << EOF > /etc/sudoers.d/10-alces-appliance
Cmnd_Alias OPS = /sbin/usermod engineer --shell /bin/bash,/sbin/dmidecode,/sbin/usermod engineer --shell /sbin/nologin,/bin/at now + 1 hour -f /tmp/disable.sh,/sbin/useradd,/sbin/lid,/sbin/shutdown,/bin/passwd
%operators      ALL = NOPASSWD: OPS
EOF

###########Appliance GUI ##################

mkdir -p /appliance

if ! gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB ; then
    curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
    curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -
fi

curl -sSL https://get.rvm.io | bash -s stable --ruby
source /etc/profile.d/rvm.sh
rvm install ruby # Install standard ruby otherwise 2.5.0 install fails with "executable host ruby is required. use --with-baseruby option."
rvm install "ruby-2.5.0"

rvm --default use 2.5.0

yum -y install postgresql-server postgresql-devel

curl -sL https://rpm.nodesource.com/setup_8.x | bash -
yum -y install nodejs-8.12.0

curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo
yum -y install yarn

git clone https://github.com/alces-software/flight-terminal-service /appliance/flight-terminal-service
cat << EOF > /appliance/flight-terminal-service/.env
INTERFACE=127.0.0.1
CMD_EXE="/bin/sudo"
CMD_ARGS_FILE="cmd.args.json"
INTEGRATION=no-auth-localhost
EOF

cat << EOF > /appliance/flight-terminal-service/cmd.args.json
{
  "args": [
    "-u", "root",
    "TERM=linux",
    "/opt/flight/bin/flight", "shell"
  ]
}
EOF

cd /appliance/flight-terminal-service
yarn

yum -y -e0 install pam-devel
cd /appliance/
git clone https://github.com/alces-software/flighthub-gui.git -b $FLIGHT_GUI_BRANCH
cd flighthub-gui
cp .env.example .env
touch /appliance/cluster.md

cd /appliance/flighthub-gui

sed -i "s@APPLICATION_NAME=ABC@APPLICATION_NAME='$alces_APPLIANCE_NAME'@g;s@^#SECRET_KEY_BASE=.*@SECRET_KEY_BASE=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 25)@g" .env
sed -i 's@^export APPLIANCE_INFORMATION_FILE_PATH=ABC@export APPLIANCE_INFORMATION_FILE_PATH=/appliance/cluster.md@g;s@^#RAILS_SERVE_STATIC_FILES@RAILS_SERVE_STATIC_FILES@g;s@^export SSH_KEYS_FILE_PATH=ABC@export SSH_KEYS_FILE_PATH=/appliance/siteadmin/.ssh/authorized_keys@g;s@export NETWORK_VARIABLES_FILE_PATH=ABC@export NETWORK_VARIABLES_FILE_PATH=/appliance/scripts/vars.sh@g;s@export NETWORK_SETUP_SCRIPT_FILE_PATH=ABC@export NETWORK_SETUP_SCRIPT_FILE_PATH=/appliance/scripts/personality_base.sh@g' .env
alces_SITEADMIN_PASS='alcestest'

bundle install

cat << EOF > /usr/lib/systemd/system/flight-gui.service
[Unit]
Description=Alces Flight GUI Appliance
Requires=network.target postgresql.service
[Service]
Type=simple
User=root
WorkingDirectory=/appliance/flighthub-gui
ExecStart=/usr/bin/bash -lc 'bundle exec bin/rails server -e production --port 3000'
TimeoutSec=30
RestartSec=15
Restart=always
[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /usr/lib/systemd/system/flight-terminal.service
[Unit]
Description=Flight terminal service
Requires=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/appliance/flight-terminal-service
ExecStart=/usr/bin/bash -lc 'yarn run start'
TimeoutSec=30
RestartSec=15
Restart=always
[Install]
WantedBy=multi-user.target
EOF

chmod 644 /usr/lib/systemd/system/flight-gui.service /usr/lib/systemd/system/flight-terminal.service

systemctl enable flight-gui.service
systemctl enable flight-terminal.service

yum -y install nginx
rm -rf /etc/nginx/*

cat << 'EOF' > /etc/nginx/nginx.conf
user nobody;
worker_processes 1;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;
events {
    worker_connections 1024;
}
http {
    #include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    sendfile on;
    #tcp_nopush on;
    keepalive_timeout 65;
    gzip on;
    include /etc/nginx/http.d/*.conf;
}
EOF

mkdir /etc/nginx/http.d

cat << EOF > /etc/nginx/http.d/http.conf
server {
  listen 80 default;
  include /etc/nginx/server-http.d/*.conf;
}
EOF

cat << EOF > /etc/nginx/http.d/https.conf
server {
  listen 443 ssl default;
  include /etc/nginx/server-https.d/*.conf;
}
EOF

mkdir /etc/nginx/server-http{,s}.d

cat << EOF > /etc/nginx/server-https.d/ssl-config.conf
client_max_body_size 0;
# add Strict-Transport-Security to prevent man in the middle attacks
add_header Strict-Transport-Security "max-age=31536000";
ssl_certificate /etc/ssl/nginx/fullchain.pem;
ssl_certificate_key /etc/ssl/nginx/key.pem;
ssl_session_cache shared:SSL:1m;
ssl_session_timeout 5m;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_prefer_server_ciphers on;
EOF

mkdir /etc/ssl/nginx

# Generic key
openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/nginx/key.pem -out /etc/ssl/nginx/fullchain.pem -days 365 -nodes -subj "/C=UK/O=Alces Flight/CN=appliance.alces.network"

cat << 'EOF' > /etc/nginx/server-https.d/overware.conf
location / {
     proxy_pass http://127.0.0.1:3000;
     proxy_redirect off;
     proxy_set_header X-Real-IP  $remote_addr;
     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
     proxy_set_header Host $http_host;
     proxy_set_header X-NginX-Proxy true;
     proxy_set_header X-Forwarded-Proto $scheme;
     proxy_temp_path /tmp/proxy_temp;
}
EOF

cat << 'EOF' > /etc/nginx/server-https.d/flight-terminal.conf
location /terminal-service {
     proxy_pass http://127.0.0.1:25288;
     proxy_redirect off;
     proxy_set_header X-Real-IP  $remote_addr;
     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
     proxy_set_header Host $http_host;
     proxy_set_header X-NginX-Proxy true;
}
EOF

cat << 'EOF' > /etc/nginx/server-http.d/redirect-http-to-https.conf
return 307 https://$host$request_uri;
EOF

systemctl enable nginx

ln -snf /opt/appliance/bin/cli.rb /usr/bin/alces-appliance

mkdir -p  /var/lib/firstrun/scripts/
cat << EOF > /var/lib/firstrun/scripts/appliancegui.bash
cd /appliance/flighthub-gui

postgresql-setup initdb
sed -i 's/peer$/trust/g;s/ident$/trust/g' /var/lib/pgsql/data/pg_hba.conf
systemctl enable postgresql
systemctl restart postgresql

RAILS_ENV=production bin/rails db:create
RAILS_ENV=production bin/rails db:schema:load
RAILS_ENV=production bin/rails data:migrate
echo "bolt_on = BoltOn.find_by(name: 'VPN') ; bolt_on.enabled = true ; bolt_on.save! " |RAILS_ENV=production rails console
echo "bolt_on = BoltOn.find_by(name: 'Console') ; bolt_on.enabled = true ; bolt_on.save! " |RAILS_ENV=production rails console
rake assets:precompile

systemctl restart flight-gui
systemctl restart flight-terminal

EOF


####### Appliance VPN setup ########
rsync -pav /usr/share/easy-rsa/3/ /etc/openvpn/easyrsa
cat<< 'EOF' > /etc/openvpn/easyrsa/vars
if [ -z "$EASYRSA_CALLER" ]; then
    echo "You appear to be sourcing an Easy-RSA 'vars' file." >&2
    echo "This is no longer necessary and is disallowed. See the section called" >&2
    echo "'How to use this file' near the top comments for more details." >&2
    return 1
fi
set_var EASYRSA        "$PWD"
set_var EASYRSA_OPENSSL        "openssl"
set_var EASYRSA_PKI            "$EASYRSA/pki"
set_var EASYRSA_DN     "org"
set_var EASYRSA_REQ_COUNTRY    "UK"
set_var EASYRSA_REQ_PROVINCE   "Oxfordshire"
set_var EASYRSA_REQ_CITY       "Oxford"
set_var EASYRSA_REQ_ORG        "Alces Flight Ltd"
set_var EASYRSA_REQ_EMAIL      "ssl@alces-flight.com"
set_var EASYRSA_REQ_OU         "Infrastructure"
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_ALGO           rsa
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    3650
set_var EASYRSA_CRL_DAYS       180
set_var EASYRSA_TEMP_FILE      "$EASYRSA_PKI/extensions.temp"
set_var EASYRSA_BATCH 		"true"
EOF

chmod 744 /etc/openvpn/easyrsa/vars
#Do config
cat << EOF > /etc/openvpn/cluster.conf
port 1195
proto tcp
dev tun0
ca /etc/openvpn/easyrsa/pki/ca.crt
cert /etc/openvpn/easyrsa/pki/issued/hub.crt
key /etc/openvpn/easyrsa/pki/private/hub.key
dh /etc/openvpn/easyrsa/pki/dh.pem
crl-verify /etc/openvpn/easyrsa/pki/crl.pem
server 10.178.0.0 255.255.255.0
ifconfig-pool-persist ipp-cluster
keepalive 10 60
comp-lzo
persist-key
persist-tun
status openvpn-status.log
log-append  /var/log/openvpn-clusters.log
verb 3
client-cert-not-required
username-as-common-name
plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn-cluster
client-config-dir ccd-cluster
ccd-exclusive
client-to-client
EOF

cat << EOF > /etc/pam.d/openvpn-cluster
#%PAM-1.0
auth [user_unknown=ignore success=ok ignore=ignore default=bad] pam_securetty.so
auth       substack     system-auth
auth       include      postlogin
auth       required     pam_listfile.so onerr=fail item=user sense=allow file=/etc/openvpn/cluster.users
account    required     pam_nologin.so
account    include      system-auth
password   include      system-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    optional     pam_console.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      system-auth
session    include      postlogin
-session   optional     pam_ck_connector.so
EOF

#prep for our clients
mkdir /etc/openvpn/ccd-cluster
touch /etc/openvpn/ipp-cluster
touch /etc/openvpn/cluster.users

mkdir -p /var/lib/firstrun/scripts/
cat << EOF > /var/lib/firstrun/scripts/vpn.bash
cd /etc/openvpn/easyrsa
#Init things & build CA
./easyrsa init-pki  
./easyrsa build-ca nopass
./easyrsa gen-dh
./easyrsa gen-crl

#Generate hub keys
./easyrsa gen-req hub nopass
./easyrsa sign-req server hub

systemctl enable openvpn@cluster
systemctl restart openvpn@cluster
EOF

########FIREWALL##############
systemctl enable firewalld
firewall-offline-cmd --set-default-zone=external 
firewall-offline-cmd --add-port 1195/tcp --zone external
firewall-offline-cmd --new-zone clustervpn
firewall-offline-cmd --add-interface tun0 --zone clustervpn

