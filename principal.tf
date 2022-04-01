terraform {
    required_version = ">= 0.13"
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = ">= 2.26"
        }
        null = {
          version = "~> 3.0.0"
        }
    }
}


provider "azurerm" {
    skip_provider_registration = true
    features {
      
    }
}

resource "azurerm_resource_group" "tarefa01" {
    name = var.name
    location = var.location  
}
resource "azurerm_virtual_network" "vnet-tarefa01" {
    name = "vnet-tarefa"
    location = azurerm_resource_group.tarefa01.location
    resource_group_name = azurerm_resource_group.tarefa01.name
    address_space = [ "10.0.0.0/16" ]
    tags = {
      environment = "Stage"
    }
}



resource "azurerm_subnet" "sub-tarefa01" {
    name = "sub-vnet-tarefa"
    resource_group_name = azurerm_resource_group.tarefa01.name
    virtual_network_name = azurerm_virtual_network.vnet-tarefa01.name
    address_prefixes = [ "10.0.0.0/1" ]
}

resource "azurerm_public_ip" "tarefa01-publicip" {
    name                         = "public-iptarefa"
    location                     = azurerm_resource_group.tarefa01.location
    resource_group_name          = azurerm_resource_group.tarefa01.name
    allocation_method            = "Static"
}

resource "azurerm_network_security_group" "mytarefa01nsg" {
    name                = "nsg-tarefa01"
    location            = azurerm_resource_group.tarefa01.location
    resource_group_name = azurerm_resource_group.tarefa01.name
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_interface" "nic-tarefa01" {
    name                      = "nic-tarefa"
    location                  = azurerm_resource_group.tarefa01.location
    resource_group_name       = azurerm_resource_group.tarefa01.name

    ip_configuration {
        name                          = "ip-tarefa01nic"
        subnet_id                     = azurerm_subnet.sub-tarefa01.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.tarefa01-publicip.id
    }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-terraform" {
  network_interface_id      = azurerm_network_interface.nic-tarefa01.id
  network_security_group_id = azurerm_network_security_group.mytarefa01nsg.id
}

resource "azurerm_storage_account" "storageterraform" {
    name                        = "storageaccountmyvm"
    resource_group_name         = azurerm_resource_group.tarefa01.name
    location                    = azurerm_resource_group.tarefa01.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}


resource "azurerm_virtual_machine" "vm-tarefa01" {
  name                  = "vm-tarefa01-machine"
  location              = azurerm_resource_group.tarefa01.location
  resource_group_name   = azurerm_resource_group.tarefa01.name
  network_interface_ids = [
    azurerm_network_interface.nic-tarefa01.id
  ]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "disktarefa"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = var.computer_name
    admin_username = var.username
    admin_password = var.secret_pwd
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}


data "azurerm_public_ip" "ip-tarefa01"{
    name = azurerm_public_ip.tarefa01-publicip.name
    resource_group_name = azurerm_resource_group.tarefa01.name
}



resource "null_resource" "install-apache" {
  
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-tarefa01.ip_address
    user = var.username
    password = var.secret_pwd
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt upgrade",
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }

  depends_on = [
    azurerm_virtual_machine.vm-tarefa01
  ]
}

resource "null_resource" "upload-app" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-tarefa01.ip_address
    user = var.username
    password = var.secret_pwd
  }

  provisioner "file" {
    source = "app"
    destination = "home/${var.username}"
  }
  // testando 
  provisioner "file" {
    source = "app"
    destination = "var/www/html/"
  }
  depends_on = [
    azurerm_virtual_machine.vm-tarefa01
  ]
}