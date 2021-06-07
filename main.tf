terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 3.0"
        }
    }
}
provider "aws" {
    region = "us-west-1"
}


#Cloud
resource "aws_vpc" "poc_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "Coalfire POC VPC"
    }
}
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.poc_vpc.id
}


#subnets
resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.poc_vpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-west-1b"

    tags = {
        Name = "sub1 pub"
    }
}
resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.poc_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-west-1c"

    tags = {
        Name = "sub2 pub"
    }
}
resource "aws_subnet" "sub3" {
    vpc_id = aws_vpc.poc_vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-west-1b"

    tags = {
        Name = "sub3 priv"
    }
}
resource "aws_subnet" "sub4" {
    vpc_id = aws_vpc.poc_vpc.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "us-west-1c"

    tags = {
        Name = "sub4 priv"
    }
}

#routes
resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.poc_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.internet_gateway.id
    } 

    tags = {
        Name = "Public Routes"
    }
}
resource "aws_route_table" "private_route_table_1b" {
    vpc_id = aws_vpc.poc_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gateway_1b.id
    }
    tags = {
        Name = "Private Routes us-west-1b"
    }
}
resource "aws_route_table" "private_route_table_1c" {
    vpc_id = aws_vpc.poc_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gateway_1c.id 
    }

    tags = {
        Name = "Private Routes us-west-1c"
    }
}

resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.sub1.id
    route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "rta3" {
    subnet_id = aws_subnet.sub3.id
    route_table_id = aws_route_table.private_route_table_1b.id
}
resource "aws_route_table_association" "rta4" {
    subnet_id = aws_subnet.sub4.id
    route_table_id = aws_route_table.private_route_table_1c.id
}

#NAT gateway + EIP
resource "aws_eip" "eip_1b" {
    vpc = true
}
resource "aws_eip" "eip_1c" {
    vpc = true
}
resource "aws_nat_gateway" "nat_gateway_1b" {
    allocation_id = aws_eip.eip_1b.id
    subnet_id = aws_subnet.sub1.id
}
resource "aws_nat_gateway" "nat_gateway_1c" {
    allocation_id = aws_eip.eip_1c.id
    subnet_id = aws_subnet.sub2.id
}


#security groups
resource "aws_security_group" "public_traffic_sgroup" {

    name = "Public Traffic Security Group"
    description = "Allows inbound http(s) and ssh traffic"
    vpc_id = aws_vpc.poc_vpc.id

    ingress {
        description = "Inbound from HTTP"
        from_port = 80
        to_port = 80
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
    ingress {
        description = "Inbound from HTTPS"
        from_port = 443
        to_port = 443
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
    ingress {
        description = "Inbound from SSH"
        from_port = 22
        to_port = 22
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}
resource "aws_security_group" "private_traffic_sgroup" {
    name = "Private Traffic Security Group"
    description = "Allows inbound http traffic from local"
    vpc_id = aws_vpc.poc_vpc.id

    ingress {
        description = "Inbound from HTTP"
        from_port = 80
        to_port = 80
        protocol = "TCP"
        cidr_blocks = ["10.0.0.0/16"]
    }
    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}

# #instances
resource "aws_instance" "redhat_sub1_instance" {
    ami = "ami-e60f2486"
    instance_type = "t2.micro"
    key_name = "main-key-coalfire"
    subnet_id = aws_subnet.sub1.id
    security_groups = [aws_security_group.public_traffic_sgroup.id]
    associate_public_ip_address = true
    availability_zone = "us-west-1b"
    root_block_device {
      volume_size = 19 // 18.65 GiB ~== 20GBs
    }
   
}
resource "aws_instance" "redhat_sub3_instance" {
    ami = "ami-e60f2486"
    instance_type = "t2.micro"
    key_name = "main-key-coalfire"
    subnet_id = aws_subnet.sub3.id
    security_groups = [aws_security_group.private_traffic_sgroup.id]
    availability_zone = "us-west-1b"
    root_block_device {
      volume_size = 19 // 18.65 GiB ~== 20GB
    }
     user_data = <<-EOF
                #cloud-boothook
                #!/bin/bash
                sudo su
                yum update -y
                yum install httpd -y 
                echo "this is a temp landing page" > /var/www/html/index.html
                service httpd start
                EOF
}

// ALB 
resource "aws_lb_target_group" "alb_target_group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "alb-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.poc_vpc.id
}

resource "aws_lb" "alb" {
  name     = "ALB"
  internal = false
  security_groups = [aws_security_group.public_traffic_sgroup.id]
  subnets = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Name = "ALB"
  }

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.redhat_sub3_instance.id
  port             = 80
}
