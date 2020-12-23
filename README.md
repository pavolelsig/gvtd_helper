GVT-d Helper

For a guide, visit:

*This is a helper for passing through a supported Intel iGPU to a KVM virtual machine
*Supported OSes: Ubuntu 20.04 and 20.10, Manjaro and PopOS

If you need to manually edit mkinitcpio, add this: "vfio_pci vfio vfio_iommu_type1 vfio_virqfd"
If you need to manually edit grub, add this: "intel_ioimmu=on kvm.ignore_msrs=1 vfio-pci.ids="[iGPU id]"

To display your VM, you'll need to download Looking Glass: https://looking-glass.hostfission.com/
