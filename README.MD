# Load Balance

1. Nginx
2. gunicorn
3. supervisor
4. digwebs
5. dynamodb
6. ELB

```terraform
terraform {
  required_version = "= 0.12.19"
}

provider "aws" {
  version = "= 2.58"
  region = "ap-northeast-1"
}

module "load_balance" {
  source       = "github.com/2cloudlab/module_load_balancer//modules/load_balancer?ref=v0.0.1"
}

output "alb_dns_name" {
  value       = module.load_balance.alb_dns_name
  description = "The domain name of the load balancer"
}
```
