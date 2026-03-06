aws_region       = "us-east-2"
instance_type    = "t3.micro"
project_tag      = "gameday-prep"
vpc_cidr         = "10.0.0.0/16"
subnet_cidrs     = ["10.0.0.0/24", "10.0.16.0/24", "10.0.32.0/24"]
desired_capacity = 3
min_size         = 2
max_size         = 5
