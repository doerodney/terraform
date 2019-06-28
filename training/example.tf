provider "aws" {
  profile = "default"
  region = "us-west-2"
}

resource "aws_instance" "example" {
  ami = "ami-b307ffd3"
  instance_type = "t2.micro" 
  subnet_id = "subnet-f8caf78e" 
  tags = {
    Name = "Created by doer using Terraform"
  }     
}
