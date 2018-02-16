# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix used for resource names."
}

variable "api_id" {
  description = "Gateway REST API ID."
}

variable "resource_id" {
  description = "Gateway resource ID."
}

variable "key_required" {
  description = "Flag with true if the method requires an API key."
  default     = "false"
}

variable "http_method" {
  description = "HTTP method to accept in the Gateway resource."
}

variable "request_parameters" {
  description = "Map of request parameters for the method."
  type        = "map"
  default     = {}
}

variable "request_template" {
  description = ""
  default     = "{}"
}

variable "lambda_arn" {
  description = "ARN of the lambda function to integrate with."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_api_gateway_method" "request_method" {
  rest_api_id        = "${var.api_id}"
  resource_id        = "${var.resource_id}"
  http_method        = "${var.http_method}"
  api_key_required   = "${var.key_required}"
  authorization      = "NONE"
  request_parameters = "${var.request_parameters}"
}

resource "aws_api_gateway_integration" "request_integration" {
  rest_api_id             = "${var.api_id}"
  resource_id             = "${var.resource_id}"
  http_method             = "${aws_api_gateway_method.request_method.http_method}"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.lambda_arn}/invocations"
  passthrough_behavior    = "WHEN_NO_TEMPLATES"
  integration_http_method = "POST"

  request_templates = {
    "application/json" = "${var.request_template}"
  }
}

resource "aws_api_gateway_method_response" "response_method" {
  rest_api_id = "${var.api_id}"
  resource_id = "${var.resource_id}"
  http_method = "${aws_api_gateway_integration.request_integration.http_method}"
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "response_integration" {
  rest_api_id = "${var.api_id}"
  resource_id = "${var.resource_id}"
  http_method = "${aws_api_gateway_method_response.response_method.http_method}"
  status_code = "${aws_api_gateway_method_response.response_method.status_code}"

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_lambda_permission" "invoke" {
  function_name = "${var.lambda_arn}"
  statement_id  = "${var.prefix}-invoke-permission"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.api_id}/*/${aws_api_gateway_method.request_method.http_method}*"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "http_method" {
  value = "${aws_api_gateway_integration_response.response_integration.http_method}"
}
