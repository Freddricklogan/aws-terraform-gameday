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

Terraform uses four primary block types. Understanding when to use each one is essential -- during Game Day you'll be reading and modifying all four.

### Resource Block -- Creates Infrastructure

Resource blocks are the core of Terraform. Each one tells AWS to create, update, or delete an actual piece of infrastructure. The naming convention is `<provider>_<type>` followed by a local name you choose. The local name is how you reference this resource elsewhere in your code -- it never appears in AWS itself.

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

Data blocks don't create anything. They look up information that already exists in AWS and make it available in your Terraform code. This is critical for things like finding the latest Ubuntu AMI ID (which changes frequently) or listing available availability zones in your region. If you hardcode an AMI ID, it will break when AWS publishes a new image. A data block keeps it dynamic.

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

Variables make your Terraform code reusable. Instead of hardcoding `"t3.micro"` everywhere, you define a variable once and reference it with `var.instance_type`. This means you can change the instance type in one place (`terraform.tfvars`) and it propagates everywhere. During Game Day, check the variables file first to understand what values the infrastructure is using.

```hcl
variable "<name>" {
  type        = string    # string, number, bool, list, map, set
  description = "What this variable is for"
  default     = "value"
}
```

### Output Block -- Displays Values After Apply

Outputs show you important information after `terraform apply` completes -- things like the load balancer URL, VPC ID, or instance IPs. Without outputs, you'd have to dig through the AWS Console or run CLI commands to find these values. During Game Day, outputs are your fastest way to get the URL you need to test.

```hcl
output "<name>" {
  value       = aws_vpc.main.id
  description = "The VPC ID"
}
```

## Referencing Resources

This is how Terraform knows about dependencies. When one resource references another, Terraform automatically builds a dependency graph and creates resources in the right order. For example, if your subnet references `aws_vpc.main.id`, Terraform knows the VPC must exist before the subnet can be created. You almost never need to specify ordering manually -- just reference what you need and Terraform figures it out.

The pattern is `<type>.<name>.<attribute>` for resources, `data.<type>.<name>.<attribute>` for data sources, and `var.<name>` for variables.

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

When debugging during Game Day, follow the references to trace the dependency chain. If a security group references the wrong VPC, every resource downstream will be in the wrong network.

## Common Data Types

Terraform is strongly typed. Knowing the difference between a list and a set matters because some AWS resources require one or the other. Lists preserve order and allow duplicates (useful for subnet CIDRs where position maps to an AZ). Maps are key-value pairs (used heavily for resource tags). Sets are unordered and deduplicated, which is what many AWS resources expect for things like security group IDs.

| Type | Example | Usage |
|------|---------|-------|
| `string` | `"t3.micro"` | Instance types, names, CIDR blocks |
| `number` | `3` | Counts, ports, sizes |
| `bool` | `true` | Enable/disable features |
| `list(string)` | `["a", "b", "c"]` | Multiple CIDR blocks, AZ names |
| `map(string)` | `{Name = "web"}` | Tags |
| `set(string)` | `toset(["sg-123"])` | Security group IDs |

If you see a Terraform error about type mismatch during Game Day, check whether the resource expects a list or a set. The fix is usually wrapping the value in `toset()` or `tolist()`.

## Loops and Dynamic Blocks

Terraform gives you two ways to create multiple copies of a resource: `count` and `for_each`. Choosing the right one matters.

**Count** creates resources by index number (0, 1, 2...). It's simple and works well when you have an ordered list, like our subnet CIDRs where position 0 maps to AZ "a", position 1 to AZ "b", etc. The downside: if you remove an item from the middle of the list, Terraform renumbers everything after it and wants to destroy and recreate those resources.

**For each** creates resources by key (a name or value). It's more resilient to changes because removing one item doesn't affect the others. Use `for_each` when the items are independent and you might add or remove them individually. Use `count` when order matters or you just need N copies of something.

### Count
```hcl
resource "aws_subnet" "public" {
  count      = 3
  cidr_block = var.subnet_cidrs[count.index]
  # Referenced as: aws_subnet.public[0], aws_subnet.public[1], etc.
  # All of them: aws_subnet.public[*].id
}
```

### For Each
```hcl
resource "aws_subnet" "public" {
  for_each   = toset(var.subnet_cidrs)
  cidr_block = each.value
  # Referenced as: aws_subnet.public["10.0.0.0/24"], etc.
  # All of them: values(aws_subnet.public)[*].id
}
```

## File Functions

These functions read external files into your Terraform configuration. The most important one for Game Day is `filebase64()` -- AWS requires user_data (bootstrap scripts) to be base64-encoded. If you use `file()` instead, the script will be passed as plain text and AWS won't execute it. The `templatefile()` function is useful when you need to inject Terraform variables into a script or config file before sending it to an instance.

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
