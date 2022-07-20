variable "resource_group_name" {
  type = string
}


variable "resource_group_location" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type = string
}

variable "dns_label_prefix" {
  type = string
}

variable "ubuntu_os_version" {
  type = string
}

variable "admin_sshkey" {
  type = string
}
variable "key_vault_id" {
  type = string
}

variable key_vault_uri {
  description = "Name of the keyVault"
  default     = "testkeyVault123"
}

variable key_vault_key {
  description = "keyVault key id"
  default     = "testkeyVault123"
}

variable key_vault_key_url {
  description = "Name of the keyVault"
  default     = "testkeyVault123"
}