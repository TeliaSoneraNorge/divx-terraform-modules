# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "vpc" {
  count  = "${contains(var.services, "vpc") && var.iam_role_name != "" ? 1 : 0}"
  name   = "${var.prefix}-vpc-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.ec2.json}"
}

resource "aws_iam_user_policy" "vpc" {
  count  = "${contains(var.services, "vpc") && var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-vpc-policy"
  user   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.vpc.json}"
}

data "aws_iam_policy_document" "vpc" {

  statement {
      effect = "Allow"

      actions = [
                "ec2:CreateCustomerGateway",
                "ec2:CreateDhcpOptions",
                "ec2:CreateFlowLogs",
                "ec2:CreateInternetGateway",
                "ec2:CreateNatGateway",
                "ec2:CreateNetworkAcl",
                "ec2:CreateNetworkAcl",
                "ec2:CreateNetworkAclEntry",
                "ec2:CreateNetworkInterface",
                "ec2:CreateRoute",
                "ec2:CreateRouteTable",
                "ec2:CreateSubnet",
                "ec2:CreateTags",
                "ec2:CreateVpc",
                "ec2:CreateVpcEndpoint"
      ]

      resources = [
                "arn:aws:ec2:${var.region}:${var.account_id}:subnet/*",
                "arn:aws:ec2:${var.region}:${var.account_id}:vpc/*",
                "arn:aws:ec2:${var.region}:${var.account_id}:route-table/*",
                "arn:aws:ec2:${var.region}:${var.account_id}:natgateway/*",
                "arn:aws:ec2:${var.region}:${var.account_id}:dhcp-options/*",
                "arn:aws:ec2:${var.region}:${var.account_id}:internet-gateway/*",
      ]


      condition = {
        test     = "StringLike"
        variable = "ec2:ResourceTag/Name"
        values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
      }
  }

  statement {
    effect = "Allow"

    actions = [
                "ec2:AllocateAddress",
                "ec2:AssignPrivateIpAddresses",
                "ec2:AssociateAddress",
                "ec2:AssociateDhcpOptions",
                "ec2:AssociateRouteTable",
                "ec2:AttachClassicLinkVpc",
                "ec2:AttachInternetGateway",
                "ec2:AttachNetworkInterface",
                "ec2:DeleteCustomerGateway",
                "ec2:DeleteDhcpOptions",
                "ec2:DeleteFlowLogs",
                "ec2:DeleteInternetGateway",
                "ec2:DeleteNatGateway",
                "ec2:DeleteNetworkAcl",
                "ec2:DeleteNetworkAclEntry",
                "ec2:DeleteNetworkInterface",
                "ec2:DeleteRoute",
                "ec2:DeleteRouteTable",
                "ec2:DeleteSubnet",
                "ec2:DeleteTags",
                "ec2:DeleteVpc",
                "ec2:DeleteVpcEndpoints",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeClassicLinkInstances",
                "ec2:DescribeCustomerGateways",
                "ec2:DescribeDhcpOptions",
                "ec2:DescribeFlowLogs",
                "ec2:DescribeInstances",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeKeyPairs",
                "ec2:DescribeMovingAddresses",
                "ec2:DescribeNatGateways",
                "ec2:DescribeNetworkAcls",
                "ec2:DescribeNetworkInterfaceAttribute",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribePrefixLists",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSubnets",
                "ec2:DescribeTags",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeVpcClassicLink",
                "ec2:DescribeVpcEndpoints",
                "ec2:DescribeVpcEndpointServices",
                "ec2:DescribeVpcs",
                "ec2:DetachClassicLinkVpc",
                "ec2:DetachInternetGateway",
                "ec2:DetachNetworkInterface",
                "ec2:DisableVgwRoutePropagation",
                "ec2:DisableVpcClassicLink",
                "ec2:DisassociateAddress",
                "ec2:DisassociateRouteTable",
                "ec2:EnableVgwRoutePropagation",
                "ec2:EnableVpcClassicLink",
                "ec2:ModifyNetworkInterfaceAttribute",
                "ec2:ModifySubnetAttribute",
                "ec2:ModifyVpcAttribute",
                "ec2:ModifyVpcEndpoint",
                "ec2:MoveAddressToVpc",
                "ec2:ReleaseAddress",
                "ec2:ReplaceNetworkAclAssociation",
                "ec2:ReplaceNetworkAclEntry",
                "ec2:ReplaceRoute",
                "ec2:ReplaceRouteTableAssociation",
                "ec2:ResetNetworkInterfaceAttribute",
                "ec2:RestoreAddressToClassic",
                "ec2:UnassignPrivateIpAddresses"
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:subnet/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:vpc/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:route-table/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:natgateway/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:dhcp-options/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:internet-gateway/*",
    ]

    condition = {
      test     = "StringLike"
      variable = "ec2:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }

  }

}
