# Unique name for the storage account
resource "random_id" "storage_account_name" {
  keepers = {
    # Generate a new id each time a new resource group is defined
    resource_group = "${var.resource_group_name}"
  }

  byte_length = 8
}


variable "config" {
  type = "map"

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
resource "azurerm_resource_group" "bb_win_noncompliant_resource_group" {
  name     = "${random_id.storage_account_name.keepers.resource_group}"
  location = "${var.resource_group_location}"
}

resource "azurerm_storage_account" "bb_win_noncompliant_storage_account1" {
  name                = "${random_id.storage_account_name.hex}"
  resource_group_name = "${azurerm_resource_group.bb_win_noncompliant_resource_group.name}"
  location            = "${var.resource_group_location}"
  account_type        = "${var.config["storage_account_type"]}"
}

# Need a storage container until managed disks supported by terraform provider
resource "azurerm_storage_container" "bb_win_noncompliant_storage_container1" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.bb_win_noncompliant_resource_group.name}"
  storage_account_name  = "${azurerm_storage_account.bb_win_noncompliant_storage_account1.name}"
  container_access_type = "private"
}

resource "azurerm_public_ip" "bb_win_noncompliant_public_ip1" {
  name                         = "${var.config["public_ip_address_name"]}"
  location                     = "${var.resource_group_location}"
  resource_group_name          = "${azurerm_resource_group.bb_win_noncompliant_resource_group.name}"
  public_ip_address_allocation = "${var.config["public_ip_address_type"]}"
  domain_name_label            = "${var.dns_label_prefix}"
}

resource "azurerm_virtual_network" "bb_win_noncompliant_virtual_network1" {
  name                = "${var.config["virtual_network_name"]}"
  address_space       = ["${var.config["address_prefix"]}"]
  location            = "${var.resource_group_location}"
  resource_group_name = "${azurerm_resource_group.bb_win_noncompliant_resource_group.name}"
}

resource "azurerm_subnet" "bb_win_noncompliant_subnet1" {
  name                 = "${var.config["subnet_name"]}"
  resource_group_name  = "${azurerm_resource_group.bb_win_noncompliant_resource_group.name}"
  virtual_network_name = "${azurerm_virtual_network.bb_win_noncompliant_bb_win_noncompliant_virtual_network1.name}"
  address_prefix       = "${var.config["subnet_prefix"]}"
}

resource "azurerm_network_interface" "bb_win_noncompliant_network_interface1" {
  name                = "${var.config["nic_name"]}"
  location            = "${var.resource_group_location}"
  resource_group_name = "${azurerm_resource_group.bb_win_noncompliant_resource_group.name}"

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${azurerm_subnet.bb_win_noncompliant_subnet1.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.bb_win_noncompliant_public_ip1.id}"
  }
}

resource "azurerm_virtual_machine" "bb_win_noncompliant_virtual_machine1" {
  name                  = "${var.config["vm_name"]}"
  location              = "${var.resource_group_location}"
  resource_group_name   = "${azurerm_resource_group.bb_win_noncompliant_resource_group.name}"
  network_interface_ids = ["${azurerm_network_interface.bb_win_noncompliant_network_interface1.id}"]
  vm_size               = "${var.config["vm_size"]}"

  os_profile {
    computer_name  = "${var.config["vm_name"]}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  storage_image_reference {
    publisher = "${var.config["image_publisher"]}"
    offer     = "${var.config["image_offer"]}"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name          = "osdisk1"
    vhd_uri       = "${azurerm_storage_account.bb_win_noncompliant_storage_account1.primary_blob_endpoint}${azurerm_storage_container.bb_win_noncompliant_storage_container1.name}/osdisk1.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  storage_data_disk {
    name          = "datadisk0"
    vhd_uri       = "${azurerm_storage_account.bb_win_noncompliant_storage_account1.primary_blob_endpoint}${azurerm_storage_container.bb_win_noncompliant_storage_container1.name}/datadisk0.vhd"
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
    storage_uri = "${azurerm_storage_account.bb_win_noncompliant_storage_account1.primary_blob_endpoint}"
  }
}

#IPAdress value only available with static IP Address
output "ipAddress" {
  value = ["${azurerm_public_ip.bb_win_noncompliant_public_ip1.ip_address}"]
}