prefix = "concourse-ci"

domain          = ""
zone_id         = ""
certificate_arn = ""
web_protocol    = "HTTP"
web_port        = "80"

concourse_keys = "${path.root}/keys"
instance_key   = ""
pem_bucket     = "your-key-bucket"
pem_path       = "example-key.pem"

authorized_keys = [
  "ssh-rsa <your-public-key>",
]

basic_auth_username = "admin"
basic_auth_password = "SomePassword123"
postgres_password   = "SomePassword234"
encryption_key      = "SomePassword345"

github_client     = ""
github_secret     = ""
github_users      = []
github_teams      = []

tags   = {
  terraform   = "True"
  environment = "dev"
}

