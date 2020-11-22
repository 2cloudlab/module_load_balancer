# required variables

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

# optional variables with default value

variable "envs" {
  type = list
  default = []
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