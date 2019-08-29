NAME=test1
RAWIMAGE=/Users/steve/iso/CENTOS7BASE2908191321_generic.raw
EXTERNALBRIDGEADAPTER=en0
CONSOLE=1

VMPATH=/tmp/stevevm/${NAME}/

#PREPILATIONS
mkdir -p $VMPATH

VBoxManage convertdd ${RAWIMAGE} ${VMPATH}/disk.vdi --format VDI

#DOIFY
VBoxManage createvm --name ${NAME} --ostype RedHat_64 --register --basefolder $VMPATH
VBoxManage modifyvm ${NAME} --cpus 2 --memory 4096 --vrde on --vrdeport 5001

VBoxManage modifyvm ${NAME} --nic1 bridged --bridgeadapter1 ${EXTERNALBRIDGEADAPTER}

if [ "$CONSOLE" -gt 0 ]; then
  VBoxManage modifyvm ${NAME} --uart1 0x3F8 4 --uartmode1 server $VMPATH/${NAME}pipe
fi
VBoxManage storagectl ${NAME} --name "SATA" --add sata --portcount 2

VBoxManage modifymedium disk $VMPATH/disk.vdi --resize 16000

VBoxManage storageattach ${NAME} --storagectl SATA --port 1 --type hdd --medium $VMPATH/disk.vdi
VBoxManage startvm ${NAME} --type headless

echo "VM started - connect to console with minicom -D unix#/$VMPATH/${NAME}pipe"
