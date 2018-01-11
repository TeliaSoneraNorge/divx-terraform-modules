#! /bin/bash

set -euo pipefail

export AWS_DEFAULT_REGION=eu-west-1

latest_ami() {
    local name=$1
    local owner_id=$2

    aws ec2 describe-images \
        --filters \
        "Name=name,Values=${name}" \
        "Name=owner-id,Values=${owner_id}" \
        "Name=architecture,Values=x86_64" \
        "Name=virtualization-type,Values=hvm" \
        "Name=root-device-type,Values=ebs" \
        --query 'Images[*].[ImageId,CreationDate]' \
        --output text \
        | sort -k2 -r \
        | head -n1
}

amazon_linux_2=$(latest_ami amzn2-ami*ebs 137112412989)
echo "Latest Amazon Linux 2:"
echo ${amazon_linux_2}

coreos=$(latest_ami CoreOS-stable* 595879546273)
echo "Latest CoreOS:"
echo ${coreos}

