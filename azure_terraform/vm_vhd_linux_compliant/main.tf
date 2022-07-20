# Unique name for the storage account
resource "random_id" "storage_account_name" {
  keepers = {
    # Generate a new id each time a new resource group is defined
    resource_group = "${var.resource_group_name}"
  }

  byte_length = 8
}

#"The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version."
variable "ubuntu_os_version_map" {
  type = map

  default = {
    "12.04.5-LTS" = "12.04.5-LTS"
    "14.04.5-LTS" = "14.04.5-LTS"
    "15.10"       = "15.10"
    "16.04.0-LTS" = "16.04.0-LTS"
  }
}

variable "config" {
  type = map

  default = {
    "image_publisher"        = "Canonical"
    "image_offer"            = "UbuntuServer"
    "nic_name"               = "myVMNic"
    "address_prefix"         = "10.0.0.0/16"
    "subnet_name"            = "Subnet"
    "subnet_prefix"          = "10.0.0.0/24"
    "storage_account_type"   = "Standard_LRS"
    "public_ip_address_name" = "myPublicIP"
    "public_ip_address_type" = "Dynamic"
    "vm_name"                = "acctvm"
    "vm_size"                = "Standard_A1"
    "virtual_network_name"   = "MyVNET"
  }
}

# Need to add resource group for Terraform
resource "azurerm_resource_group" "bb_compliant_resource_group" {
  name     = "${random_id.storage_account_name.keepers.resource_group}"
  location = "${var.resource_group_location}"
}

resource "azurerm_storage_account" "bb_compliant_storage_account1" {
  name                = "${random_id.storage_account_name.hex}"
  resource_group_name = "${azurerm_resource_group.bb_compliant_resource_group.name}"
  location            = "${var.resource_group_location}"
  account_type        = "${var.config["storage_account_type"]}"
}

# Need a storage container until managed disks supported by terraform provider
resource "azurerm_storage_container" "bb_compliant_storage_container1" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.bb_compliant_resource_group.name}"
  storage_account_name  = "${azurerm_storage_account.bb_compliant_storage_account1.name}"
  container_access_type = "private"
}

resource "azurerm_public_ip" "bb_compliant_public_ip1" {
  name                         = "${var.config["public_ip_address_name"]}"
  location                     = "${var.resource_group_location}"
  resource_group_name          = "${azurerm_resource_group.bb_compliant_resource_group.name}"
  public_ip_address_allocation = "${var.config["public_ip_address_type"]}"
  domain_name_label            = "${var.dns_label_prefix}"
}

resource "azurerm_virtual_network" "bb_compliant_virtual_network1" {
  name                = "${var.config["virtual_network_name"]}"
  address_space       = ["${var.config["address_prefix"]}"]
  location            = "${var.resource_group_location}"
  resource_group_name = "${azurerm_resource_group.bb_compliant_resource_group.name}"
}

resource "azurerm_subnet" "bb_compliant_subnet1" {
  name                 = "${var.config["subnet_name"]}"
  resource_group_name  = "${azurerm_resource_group.bb_compliant_resource_group.name}"
  virtual_network_name = "${azurerm_virtual_network.bb_compliant_bb_compliant_virtual_network1.name}"
  address_prefix       = "${var.config["subnet_prefix"]}"
}

resource "azurerm_network_interface" "bb_compliant_network_interface1" {
  name                = "${var.config["nic_name"]}"
  location            = "${var.resource_group_location}"
  resource_group_name = "${azurerm_resource_group.bb_compliant_resource_group.name}"

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${azurerm_subnet.bb_compliant_subnet1.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.bb_compliant_public_ip1.id}"
  }
}

resource "azurerm_virtual_machine" "bb_compliant_virtual_machine1" {
  name                  = "${var.config["vm_name"]}"
  location              = "${var.resource_group_location}"
  resource_group_name   = "${azurerm_resource_group.bb_compliant_resource_group.name}"
  network_interface_ids = ["${azurerm_network_interface.bb_compliant_network_interface1.id}"]
  vm_size               = "${var.config["vm_size"]}"

  os_profile {
    computer_name  = "${var.config["vm_name"]}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  storage_image_reference {
    publisher = "${var.config["image_publisher"]}"
    offer     = "${var.config["image_offer"]}"
    sku       = "${lookup(var.ubuntu_os_version_map, var.ubuntu_os_version)}"
    version   = "latest"
  }

  storage_os_disk {
    name          = "osdisk1"
    vhd_uri       = "${azurerm_storage_account.bb_compliant_storage_account1.primary_blob_endpoint}${azurerm_storage_container.bb_compliant_storage_container1.name}/osdisk1.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  storage_data_disk {
    name          = "datadisk0"
    vhd_uri       = "${azurerm_storage_account.bb_compliant_storage_account1.primary_blob_endpoint}${azurerm_storage_container.bb_compliant_storage_container1.name}/datadisk0.vhd"
    disk_size_gb  = "1023"
    create_option = "Empty"
    lun           = 0
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${var.admin_sshkey}"
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.bb_compliant_storage_account1.primary_blob_endpoint}"
  }
}

resource "azurerm_virtual_machine_extension" "linux_vm_disk_encryption_compliant" {
  name                       = "bbtest-linux-diskenc-ext"
  virtual_machine_id         = azurerm_virtual_machine.bb_compliant_virtual_machine1.id
  publisher                  = "Microsoft.Azure.Security"
  type                       = "AzureDiskEncryptionForLinux"
  type_handler_version       = "1.1"

  settings = <<SETTINGS
    {
      "EncryptionOperation": "EnableEncryption",
      "KeyVaultURL": "${var.key_vault_uri}",
      "KeyVaultResourceId": "${var.key_vault_id}",					
      "KeyEncryptionKeyURL": "${var.key_vault_key_url}",
      "KekVaultResourceId": "${var.key_vault_key}",				
      "KeyEncryptionAlgorithm": "RSA-OAEP",
      "VolumeType": "All"
    }
  SETTINGS
}

#IPAdress value only available with static IP Address
output "ipAddress" {
  value = ["${azurerm_public_ip.bb_compliant_public_ip1.ip_address}"]
}