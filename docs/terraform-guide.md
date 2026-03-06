# Terraform Quick Reference

## Core Commands

| Command | Purpose |
|---------|---------|
| `terraform init` | Download provider libraries (run once per project) |
| `terraform validate` | Check syntax errors |
| `terraform plan` | Preview what will be created/changed/destroyed |
| `terraform apply` | Deploy the infrastructure (type 'yes' to confirm) |
| `terraform destroy` | Tear down all infrastructure (type 'yes' to confirm) |
| `terraform fmt` | Auto-format .tf files |
| `terraform state list` | List all managed resources |
| `terraform state show <resource>` | Show details of a specific resource |
| `terraform output` | Display output values |

## Block Types

### Resource Block -- Creates Infrastructure
```hcl
resource "<provider>_<type>" "<local_name>" {
  # configuration
}
```
Example:
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

### Data Block -- Queries Existing Information
```hcl
data "<provider>_<type>" "<local_name>" {
  # filters
}
```
Example:
```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
}
```

### Variable Block -- Defines Input Variables
```hcl
variable "<name>" {
  type        = string    # string, number, bool, list, map, set
  description = "What this variable is for"
  default     = "value"
}
```

### Output Block -- Displays Values After Apply
```hcl
output "<name>" {
  value       = aws_vpc.main.id
  description = "The VPC ID"
}
```

## Referencing Resources

Resources reference each other using: `<type>.<name>.<attribute>`

```hcl
# Reference a resource attribute
aws_vpc.main.id
aws_subnet.public.cidr_block
aws_security_group.web.id

# Reference a data source
data.aws_ami.ubuntu.id
data.aws_availability_zones.available.names

# Reference a variable
var.instance_type
var.project_tag
```

## Common Data Types

| Type | Example | Usage |
|------|---------|-------|
| `string` | `"t3.micro"` | Instance types, names, CIDR blocks |
| `number` | `3` | Counts, ports, sizes |
| `bool` | `true` | Enable/disable features |
| `list(string)` | `["a", "b", "c"]` | Multiple CIDR blocks, AZ names |
| `map(string)` | `{Name = "web"}` | Tags |
| `set(string)` | `toset(["sg-123"])` | Security group IDs |

## Loops and Dynamic Blocks

### Count
```hcl
resource "aws_subnet" "public" {
  count      = 3
  cidr_block = var.subnet_cidrs[count.index]
}
```

### For Each
```hcl
resource "aws_subnet" "public" {
  for_each          = toset(var.subnet_cidrs)
  cidr_block        = each.value
}
```

## File Functions

| Function | Purpose |
|----------|---------|
| `file("path")` | Read file contents as string |
| `filebase64("path")` | Read file and base64 encode (for user_data) |
| `templatefile("path", vars)` | Read file with variable substitution |

## Provider Documentation

The Terraform AWS Provider docs are your primary reference:
https://registry.terraform.io/providers/hashicorp/aws/latest/docs

Every AWS service has:
- **Resource** docs (creating things)
- **Data Source** docs (querying things)
- Examples, argument reference, and attribute reference
