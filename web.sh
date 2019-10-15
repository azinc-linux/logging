#!/bin/bash
if [ `hostname` == "web" ]; then
sed -i 's/.\*/.crit/g' /etc/rsyslog.conf
l=`grep -n 'Remote Logging' /etc/rsyslog.conf | cut -d: -f 1`
l=$(($l+1))
sed -i "${l}i *.* @@192.168.11.102:514" /etc/rsyslog.conf
l=$(($l+1))
sed -i "${l}i \$IncludeConfig /etc/rsyslog.d/*.conf" /etc/rsyslog.conf
cat <<EOF > /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/7/\$basearch/
gpgcheck=0
enabled=1
EOF
yum update -y
yum install -y nginx

sed -i 's/error_log/#error_log/g; s/access_log/#access_log/g' /etc/nginx/nginx.conf
l=`grep -n 'error_log' /etc/nginx/nginx.conf | cut -d: -f 1`
l=$(($l+1))
sed -i "${l}i error_log syslog:server=192.168.11.102:514,facility=local7,tag=nginx,severity=debug;" /etc/nginx/nginx.conf

l=`grep -n 'access_log' /etc/nginx/nginx.conf | cut -d: -f 1`
l=$(($l+1))
sed -i "${l}i access_log syslog:server=192.168.11.102:514,facility=local7,tag=nginx,severity=info;" /etc/nginx/nginx.conf

cat <<EOF > /etc/rsyslog.d/nginx.conf
if \$programname = 'nginx' and \$syslogseverity <=3 then
/var/log/nginx/error.log
& stop
EOF

yum install -y  audispd-plugins

sed -i 's/remote_server/#remote_server/g' /etc/audisp/audisp-remote.conf
l=`grep -n 'remote_server' /etc/audisp/audisp-remote.conf | cut -d: -f 1`
l=$(($l+1))
sed -i "${l}i remote_server = 192.168.11.102" /etc/audisp/audisp-remote.conf

systemctl restart rsyslog
systemctl restart nginx
service auditd restart
auditctl -w /etc/nginx/nginx.conf -k test_watch

else

l=`grep -n 'InputTCPServerRun' /etc/rsyslog.conf | cut -d: -f 1`
l=$(($l+1))
sed -i "${l}i \$ModLoad imtcp" /etc/rsyslog.conf
l=$(($l+1))
sed -i "${l}i \$InputTCPServerRun 514" /etc/rsyslog.conf
l=`grep -n 'remote-host' /etc/rsyslog.conf | cut -d: -f 1`
l=$(($l+1))
sed -i "${l}i \$template RemoteLogs,\"/var/log/%HOSTNAME%/%PROGRAMNAME%.log\"" /etc/rsyslog.conf
l=$(($l+1))
sed -i "${l}i *.3 ?RemoteLogs" /etc/rsyslog.conf
systemctl restart rsyslog
cat <<EOF >> /etc/audit/auditd.conf
tcp_listen_port = 60
tcp_listen_queue = 5
tcp_max_per_addr = 1
tcp_client_max_idle = 0
EOF
service  auditd restart
fi