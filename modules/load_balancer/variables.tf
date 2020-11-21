
variable "download_url" {
  type = string
}

variable "package_base_dir" {
  type = string
}

variable "app_dir" {
  type = string
}

variable "wsgi_app" {
  type = string
}

variable "envs" {
  type = list
}

variable "min_instances_number" {
  type = number
  default = 0
}

variable "max_instances_number" {
  type = number
  default = 0
}

variable "desired_instances_number" {
  type = number
  default = 0
}

variable "instance_type" {
  type = string
  default = "t2.micro"
}