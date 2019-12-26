resource "aws_vpc" "demo_vpc" {
  cidr_block       = "${var.vpc_cidr}"
  instance_tenancy = "default"
  tags = {
    Name = "demo_vpc"
  }
}
resource "aws_subnet" "public_subnet" {
  vpc_id            = "${aws_vpc.demo_vpc.id}"
  cidr_block        = "${var.public_subnet}"
  availability_zone = "${var.region}${var.available_zone}"
  tags = {
    Name = "demo-public"
  }
}

resource "aws_internet_gateway" "demo_gateway" {
  vpc_id = "${aws_vpc.demo_vpc.id}"
  tags = {
    Name = "demo_gateway"
  }
}

resource "aws_route_table_association" "demo_route_table_association" {
  subnet_id      = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.demo_route.id}"
}

resource "aws_route_table" "demo_route" {
  vpc_id = "${aws_vpc.demo_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.demo_gateway.id}"
  }
  tags = {
    Name = "demo_route_public"
  }
}


resource "aws_security_group" "nat_security_group" {
  name        = "vpc_nat"
  description = "kubernets Security Group"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.demo_vpc.id}"
  tags   = {
    Name = "NAT Security Group"
  }
}

resource "aws_key_pair" "key" {
  key_name   = "auth_key"
  public_key = "${file("key/auth_key.pub")}"
}

resource "aws_instance" "instance" {
  ami                         = "ami-04b9e92b5572fa0d1"
  availability_zone           = "${var.region}${var.available_zone}"
  instance_type               = "t2.medium"
  key_name                    = "${aws_key_pair.key.key_name}"
  vpc_security_group_ids      = ["${aws_security_group.nat_security_group.id}"]
  subnet_id                   = "${aws_subnet.public_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false
  count                       = "${var.instance_count}"

  user_data = <<-EOF
		#!/bin/bash
		sudo apt-get update
		sudo apt-get install -y python
        sudo hostnamectl set-hostname "${element(var.instance_tags, count.index)}"
        EOF
  tags = {
    Name  = "${element(var.instance_tags, count.index)}"
	}

    provisioner "local-exec" {
        command = "echo ${self.public_ip} >> hosts" 
    }
}


resource "null_resource" "example1" {
  provisioner "local-exec" {
    command = "sleep 120; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key key/auth_key -i hosts kubernetes.yml"
    }
}
