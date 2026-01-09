locals { timestamp = formatdate("YYYY-MM-DD-hh-mm", timestamp()) }

variable "windows_username" {
  type        = string
  description = "Username when authenticating to Windows, default is Administrator."
  default     = "Administrator"
}

variable "windows_password" {
  type        = string
  description = "Password for the Windows user."
  sensitive   = true
}

variable "volume_size" {
  type        = number
  description = "The size of the root volume in GB."
  default     = 50
}

# tammy 
source "qemu" "proxmox-windows" {
  iso_checksum       = "6dae072e7f78f4ccab74a45341de0d6e2d45c39be25f1f5920a2ab4f51d7bcbb"
  iso_url           = "/home/ble/workspace/infra/windows-server-2019.iso"
  output_directory   = "output-windows"
  vm_name           = "windows-${local.timestamp}"
  disk_size         = var.volume_size
  format            = "qcow2"
  communicator      = "winrm"
  winrm_username    = var.windows_username
  winrm_password    = var.windows_password
  winrm_insecure    = true
  winrm_timeout     = "30m"  # Increased timeout
  winrm_use_ssl     = false
  shutdown_command  = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""
  shutdown_timeout  = "30m"

  # Boot configuration
  boot_wait        = "2m"
  boot_command = [
    "<wait>a<wait>"  # Press 'a' to boot from CD-ROM if prompted
  ]
  boot_key_interval = "100ms"

  # CPU and memory
  cpus      = 2
  memory    = 4096
  net_device = "virtio-net"

  # ISO and disk configuration
  disk_interface = "virtio"
  disk_discard = "unmap"
  disk_detect_zeroes = "unmap"
  disk_cache = "writeback"

  floppy_files = [
    "${path.root}/templates/autounattend.xml",
    "${path.root}/templates/winrm.ps1"
  ]

  qemuargs = [
    ["-drive", "file=/home/ble/workspace/infra/virtio-win-0.1.285.iso,media=cdrom,if=ide,index=2"],
    ["-boot", "order=cd,once=d"],  # First boot from CD, then hard drive
    ["-cpu", "host"],
    ["-m", "4096M"],
    ["-smp", "2"]
  ]
  
  # Headless mode - set to false if you need to see the VM console
  headless = false
}

build {
  sources = ["source.qemu.proxmox-windows"]
}