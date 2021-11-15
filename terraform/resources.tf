terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  backend "remote" {
    organization = "josh-deaton-personal"

    workspaces {
      name = "azure-developer-vm"
    }
  }
}
provider "azurerm" {
  features {

  }
}

data "azurerm_resources" "kv_development_sandbox" {
  resource_group_name = "rg-keyvault"
  name                = "kv-development-sandbox"
}


resource "azurerm_resource_group" "rg_development_sandbox" {
  name     = "rg-development-sandbox"
  location = var.region
}

resource "azurerm_virtual_network" "vnet_development_sandbox" {
  resource_group_name = azurerm_resource_group.rg_development_sandbox.name
  name                = "vnet-development-sandbox"
  location            = azurerm_resource_group.rg_development_sandbox.location
  address_space       = var.cidr_block
}

resource "azurerm_subnet" "snet_development_sandbox_public" {
  resource_group_name  = azurerm_resource_group.rg_development_sandbox.name
  name                 = "snet-development-sandbox-public"
  virtual_network_name = azurerm_virtual_network.vnet_development_sandbox.name
  address_prefixes     = var.public_subnet
}

resource "azurerm_public_ip" "pip_development_sandbox" {
  resource_group_name = azurerm_resource_group.rg_development_sandbox.name
  name                = "pip-development-sandbox"
  location            = azurerm_resource_group.rg_development_sandbox.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic_development_sandbox_public" {
  resource_group_name = azurerm_resource_group.rg_development_sandbox.name
  name                = "nic-development-sandbox-public"
  location            = azurerm_resource_group.rg_development_sandbox.location

  ip_configuration {
    name                          = "public"
    subnet_id                     = azurerm_subnet.snet_development_sandbox_public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_development_sandbox.id
  }
}

resource "azurerm_network_interface" "nic_development_sandbox_internal" {
  resource_group_name = azurerm_resource_group.rg_development_sandbox.name
  name                = "nic-development-sandbox-internal"
  location            = azurerm_resource_group.rg_development_sandbox.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_development_sandbox_public.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "nsg-development-sandbox" {
  resource_group_name = azurerm_resource_group.rg_development_sandbox.name
  name                = "nsg-development-sandbox-internal"
  location            = azurerm_resource_group.rg_development_sandbox.location

  security_rule = [
    {
      description                                = "rdp"
      access                                     = "Allow"
      direction                                  = "Inbound"
      protocol                                   = "tcp"
      name                                       = "rdp"
      source_port_range                          = "*"
      source_address_prefix                      = ""
      destination_port_range                     = "3389"
      destination_address_prefix                 = azurerm_network_interface.nic_development_sandbox_public.private_ip_address
      priority                                   = "100"
      destination_address_prefixes               = []
      destination_application_security_group_ids = []
      destination_port_ranges                    = []
      source_address_prefixes                    = ["168.149.138.72"]
      source_application_security_group_ids      = []
      source_port_ranges                         = []
    },
    {
      description                                = "winrm"
      access                                     = "Allow"
      direction                                  = "Inbound"
      protocol                                   = "tcp"
      name                                       = "winrm"
      source_port_range                          = "*"
      source_address_prefix                      = ""
      destination_port_range                     = "5986"
      destination_address_prefix                 = azurerm_network_interface.nic_development_sandbox_public.private_ip_address
      priority                                   = "200"
      destination_address_prefixes               = []
      destination_application_security_group_ids = []
      destination_port_ranges                    = []
      source_address_prefixes                    = ["168.149.141.72"]
      source_application_security_group_ids      = []
      source_port_ranges                         = []
    }
  ]
}

resource "azurerm_network_interface_security_group_association" "assoc-nic-nsg" {
  network_interface_id      = azurerm_network_interface.nic_development_sandbox_internal.id
  network_security_group_id = azurerm_network_security_group.nsg-development-sandbox.id
}

resource "azurerm_windows_virtual_machine" "vm_development_sandbox" {
  resource_group_name = azurerm_resource_group.rg_development_sandbox.name
  name                = "vm-development-sandbox"
  location            = azurerm_resource_group.rg_development_sandbox.location
  size                = "Standard_D2ds_v4"
  admin_username      = var.vm_username
  admin_password      = var.vm_password
  license_type        = "Windows_Client"
  computer_name       = "DevSandbox"
  network_interface_ids = [
    azurerm_network_interface.nic_development_sandbox_public.id
  ]

  source_image_reference {
    publisher = "microsoftwindowsdesktop"
    offer     = "windows-11"
    sku       = "win11-21h2-entn"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  winrm_listener {
    protocol        = "Https"
    certificate_url = "https://kv-development-sandbox.vault.azure.net/secrets/winrm-certificate/1939febe7d004fb091755373cc92a82b"
  }

  secret {
    certificate {
      store = "My"
      url   = "https://kv-development-sandbox.vault.azure.net/secrets/winrm-certificate/1939febe7d004fb091755373cc92a82b"
    }
    key_vault_id = data.azurerm_resources.kv_development_sandbox.resources[0].id
  }
}
