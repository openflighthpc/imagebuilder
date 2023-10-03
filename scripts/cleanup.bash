# Clean up
yum clean all
truncate -c -s 0 /var/log/yum.log

rm -rf /tmp/*
rm -rf /var/tmp/*
