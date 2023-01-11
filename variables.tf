variable "profile" {
    description = "Profile to use"
  type = string
}

variable "region" {
    description = "region to use"
  type = string
}

variable "vpc_cidr" {
  description = "vpc cidr"
  type = string
  default = "10.0.0.0/16"
}

variable "vpc_cidr_important" {
  description = "vpc cidr"
  type = string
  default = "10.1.0.0/16"
}

variable "vpc_name" {
  description = "vpc name"
  type = string
  default = "Application_vpc"
}