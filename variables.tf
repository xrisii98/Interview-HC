#Subnets
variable "web_sub_cidr" {
  default = "10.0.1.0/24"
}
variable "db_sub_cidr" {
  default = "10.0.2.0/24"
}
variable "db_sub_cidr_1" {
  default = "10.0.3.0/24"
}
variable "lb_sub_cidr" {
  default = "10.0.4.0/24"
}
variable "lb_sub_cidr_1" {
  default = "10.0.5.0/24"
}


#Web Server Vars
variable "web_instance" {
  default = "t2.micro"
}
#Ubuntu 20.04
variable "web_ami" {
  default = "ami-0d2a4a5d69e46ea0b"
}

#DB Vars
variable "db_instance" {
  default = "db.t3.micro"
}
variable "db_engine" {
  default = "mysql"
}
variable "db_engine_version" {
  default = "8.0"
}
variable "db_name" {
  default = "dev"
}
variable "db_username" {
  default = "admin"
}
variable "db_password" {
  default = "password"
}

variable "db_allocated_storage" {
  default = "20"
}
