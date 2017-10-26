## apigateway/lambda

Abstraction on top of API Gateway which integrates an endpoint/method 
with a lambda function.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

# /
resource "aws_api_gateway_rest_api" "main" {
  name        = "example-hello-world-api"
  description = "Example hello-world API."
}

# /hello
resource "aws_api_gateway_resource" "hello" {
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  parent_id   = "${aws_api_gateway_rest_api.main.root_resource_id}"
  path_part   = "hello"
}

# /hello/world
resource "aws_api_gateway_resource" "world" {
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  parent_id   = "${aws_api_gateway_resource.hello.id}"
  path_part   = "world"
}

module "hello_world" {
  source      = "github.com/TeliaSoneraNorge/divx-terraform-modules/apigateway/lambda"

  prefix      = "get-hello-world"
  api_id      = "${aws_api_gateway_rest_api.main.id}"
  resource_id = "${aws_api_gateway_resource.world.id}"
  http_method = "GET"
  lambda_arn  = "<your-lambda-arn>" 
}

output "http_method" {
  value = "${module.hello_world.http_method}"
}
```
