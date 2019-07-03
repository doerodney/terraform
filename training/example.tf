provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

resource "aws_instance" "example" {
  ami           = "ami-0f2176987ee50226e"
  instance_type = "t2.micro"
  key_name      = "inftools_sandbox"
  subnet_id     = "subnet-f8caf78e"
  tags = {
    Name = "Created by doer using Terraform"
  }

  vpc_security_group_ids = ["${aws_security_group.instance.id}"]
}

resource "aws_security_group" "instance" {
  description = "Allow tcp traffic on port 8080"
  name = "terraform-example-instance"
  vpc_id = "vpc-d7b04eb0"

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
