#!/bin/bash

#Making sure this script runs with elevated privileges

if [ $EUID -ne 0 ]
	then
		echo "Please run this as root!" 
		exit 1
fi

DISTRO=`cat /etc/*release | grep 'ID=' | cut -d '=' -f 2 | head -1`

if [ "$DISTRO" != "Pop" ] 

#############################
# Ubuntu and Manjaro branch #
#############################
	then

#Finding device id of the device to be passed through

DEVICE_ID="00:02.0"

if [ "$1" != "" ]
	then 
		DEVICE_ID="$1"
fi 

GPU_ID=`lspci -n | grep $DEVICE_ID | cut -d ' ' -f 3`

#Finding the location of grub and creating a working copy

if [ -a /etc/sysconfig/grub ]
	then
		GRUB_LOCATION=/etc/sysconfig/grub
else
		GRUB_LOCATION=/etc/default/grub
fi		

cp $GRUB_LOCATION grub_copy

#Editing mkinitcpio. Only on Manjaro

if  [ -a /etc/mkinitcpio.conf ]
	then
		MKINITCPIO=`cat /etc/mkinitcpio.conf | grep 'MODULES="' | rev | cut -c 2- | rev`

		if [ "$MKINITCPIO" = 'MODULES="' ]
			then
				MKINITCPIO="$MKINITCPIO""vfio_pci vfio vfio_iommu_type1 vfio_virqfd\""
			else
				MKINITCPIO="$MKINITCPIO"" vfio_pci vfio vfio_iommu_type1 vfio_virqfd\""
		fi
cp /etc/mkinitcpio.conf mkinitcpio_copy

sed -i -e "s|^MODULES=\".*|${MKINITCPIO}|" mkinitcpio_copy

echo 
echo "/etc/mkinitcpio.conf was modified to look like this: "
echo `cat mkinitcpio_copy | grep "MODULES=\""`
echo 
echo "Do you want to edit it? y/n"
read YN_MKINITCPIO
	if [ $YN_MKINITCPIO = y ]
		then
			nano mkinitcpio_copy
	fi
fi

#Creating variables that correspond to intel_iommu=on, kvm.ignore_msrs=1 and vfio-pci.ids


NEW_GRUB_CMD=`cat grub_copy | grep GRUB_CMDLINE_LINUX_DEFAULT | cut -d '"' -f 1,2`
NEW_VFIO_PCI_ID="vfio-pci.ids=$GPU_ID"
IOMMU_ON=`cat grub_copy | grep intel_iommu=on | cut -d '"' -f 1,2`
IGNORE_MSRS=`cat grub_copy | grep kvm.ignore_msrs | cut -d '"' -f 1,2`
CHECK_VFIO_PCI=`cat grub_copy | grep vfio-pci.ids | cut -d '"' -f 1,2`
if [ "$IOMMU_ON" = "" ]
	then
		NEW_GRUB_CMD="$NEW_GRUB_CMD intel_iommu=on"		
		echo "Added intel_iommu=on to grub"
	else
		echo ""
		echo "intel_iommu=on already present"
		echo "Please edit grub manually"
		echo ""
		
fi

if [ "$IGNORE_MSRS" = "" ]
	then
		NEW_GRUB_CMD="$NEW_GRUB_CMD kvm.ignore_msrs=1"
		echo "Added kvm.ignore_msrs=1 to grub"
	else
		echo ""
		echo "kvm.ignore_msrs=1 already present"
		echo "Please edit grub manually"
		echo ""
fi

if [ "$CHECK_VFIO_PCI" = "" ]
	then
		NEW_GRUB_CMD="$NEW_GRUB_CMD $NEW_VFIO_PCI_ID"
		echo "Added $NEW_VFIO_PCI_ID to grub"
	else
		echo ""
		echo "vfio-pci.ids already present"
		echo "Please edit grub manually"
		echo ""	
fi


#Making sure that new grub is correct

NEW_GRUB_CMD="$NEW_GRUB_CMD\""

sed -i -e "s|^GRUB_CMDLINE_LINUX_DEFAULT.*|${NEW_GRUB_CMD}|" grub_copy
echo 
echo "Grub was modified to look like this: "
echo `cat grub_copy | grep "GRUB_CMDLINE_LINUX_DEFAULT"`
echo 
echo "Do you want to edit it? y/n"
read YN

if [ $YN = y ]
then
nano grub_copy
fi

#Creating backups of grub and mkinitcpio
#Overwriting old grub and mkinitcpio with new versions

cp $GRUB_LOCATION grub_backup
mv grub_copy $GRUB_LOCATION
		update-grub



if [ -a /etc/mkinitcpio.conf ]
	then 
	cp /etc/mkinitcpio.conf mkinitcpio_backup
	mv mkinitcpio_copy /etc/mkinitcpio.conf
	mkinitcpio -P
fi



#Creating uninstall script

 
echo "#!/bin/bash


#Making sure this script runs with elevated privileges
if [ \$EUID -ne 0 ]
	then
		echo "Please run this as root!" 
		exit 1
fi


if [ -a grub_backup ]
	then 
	mv grub_backup $GRUB_LOCATION
	
		update-grub
fi


if [ -a mkinitcpio_backup ]
	then 
	mv mkinitcpio_backup /etc/mkinitcpio.conf
	mkinitcpio -P
fi

echo "Passthrough helper was successfully uninstalled!"


" >> uninstall.sh


chmod +x uninstall.sh

#Installing required packages

echo "Installing required packages"


if [ "$DISTRO" == "Ubuntu" ] || [ "$DISTRO" == "LinuxMint" ]
	then
		apt install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager ovmf
		VIRT_USER=`logname`
		usermod -a -G libvirt $VIRT_USER
elif [ "$DISTRO" == "ManjaroLinux" ]
	then
		pacman -S vim qemu virt-manager ovmf dnsmasq ebtables iptables
fi

systemctl enable libvirtd.service
systemctl start libvirtd.service

else
#############
#PopOS branch
#############

echo "Please wait"

IDS="vfio-pci.ids=\""

DEVICE_ID="00:02.0"

if [ "$1" != "" ]
	then 
		DEVICE_ID="$1"
fi 

GPU_ID=`lspci -n | grep $DEVICE_ID | cut -d ' ' -f 3`

IDS="$IDS$GPU_ID"


#complete ids

IDS+="\""

echo
echo $IDS

#Back up old kernel options

OLD_OPTIONS=`cat /boot/efi/loader/entries/Pop_OS-current.conf | grep options | cut -d ' ' -f 4-`

#Execute kernelstub resulting in GRUB being updated with vfio-pci.ids="..."

echo 


kernelstub --add-options intel_iommu=on
kernelstub --add-options kvm.ignore_msrs=1
	echo "Set Intel IOMMU On"
echo $IDS

kernelstub --add-options $IDS

apt install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager ovmf
echo 
echo "Required packages installed"

#Create an uninstall script
echo '

#!/bin/bash

#Making sure this script runs with elevated privileges
if [ \$EUID -ne 0 ]
	then
		echo "Please run this as root!"
		exit 1
fi

echo "kernelstub -o \"$OLD_OPTIONS\"" > uninstall.sh


' >> uninstall.sh




chmod +x uninstall.sh

fi		


