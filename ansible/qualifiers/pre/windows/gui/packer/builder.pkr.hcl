build {
  name = "windows-builder"

  sources = ["source.qemu.proxmox-windows"]

  provisioner "powershell" {
    scripts = [
      "./scripts/ansible.ps1",
      "./scripts/setup.ps1",
    ]
  }

  provisioner "ansible" {
    playbook_file   = "../ansible/playbook.yml"
    user            = var.windows_username
    use_proxy       = false
    extra_arguments = [
      "-e",
      "ansible_winrm_server_cert_validation=ignore",
      "-e",
      "ansible_winrm_read_timeout_sec=150",
      "-e",
      "ansible_winrm_operation_timeout_sec=120"
    ]
  }


  provisioner "file" {
    content = templatefile("${path.root}/templates/agent-config.pkrtpl.hcl", {
      windows_username = var.windows_username,
      windows_password = var.windows_password
    })
    destination = "C:\\agent-config.yml"
  }

  provisioner "powershell" {
    inline = [
      "Start-Process -Wait -FilePath 'C:\\Windows\\System32\\Sysprep\\Sysprep.exe' -ArgumentList '/oobe /generalize /shutdown'"
    ]
  }
}
