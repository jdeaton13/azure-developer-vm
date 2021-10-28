variable "region" {
  default = "East US"
}

variable "cidr_block" {
  default = ["10.0.0.0/16"]
}

variable "public_subnet" {
  type    = list(any)
  default = ["10.0.1.0/24"]
}

variable "private_subnet" {
  type    = list(any)
  default = ["10.0.10.0/24"]
}

variable "vm_username" {
  description = "Vm administrator username"
  type        = string
  sensitive   = true
}

variable "vm_password" {
  description = "Vm administrator password"
  type        = string
  sensitive   = true
}
