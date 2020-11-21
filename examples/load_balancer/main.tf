terraform {
  required_version = "= 0.12.19"
}

provider "aws" {
  version = "= 2.58"
  region = "us-west-1"
}

module "load_balance" {
  source       = "../../modules/load_balancer"
  download_url = "https://github.com/digolds/digolds_sample/archive/v0.0.1.tar.gz"
  package_base_dir         = "digolds_sample-0.0.1"
  app_dir = "personal-blog"
  envs     = ["USER_NAME=slz", "PASSWORD=abc"]
  wsgi_app = "wsgiapp:wsgi_app"
}

output "alb_dns_name" {
  value       = module.load_balance.alb_dns_name
  description = "The domain name of the load balancer"
}