provider "aws" {
 region ="ap-south-1"
 profile ="Tushar08"
}

resource "aws_vpc" "tera_vpc"{
 cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  tags = {
    Name = "tera_vpc"
  }
}

resource "aws_subnet" "subnet1a" {
  vpc_id     = aws_vpc.tera_vpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone="ap-south-1a"
  
  map_public_ip_on_launch= true

  tags = {
    Name = "subnet1a"
  }
}

resource "aws_subnet" "subnet1b" {
  vpc_id     = aws_vpc.tera_vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone="ap-south-1b"
 
  tags = {
    Name = "subnet1b"
  }
}

resource "aws_internet_gateway" "tera_gw" {
  vpc_id = aws_vpc.tera_vpc.id

  tags = {
    Name = "tera_gw"
  }
}

resource "aws_route_table" "tera_route" {
  vpc_id = aws_vpc.tera_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tera_gw.id
  }

  
  tags = {
    Name = "tera_route"
  }
}

resource "aws_route_table_association" "tera_asso" {
  subnet_id      = aws_subnet.subnet1a.id
  route_table_id = aws_route_table.tera_route.id
}

resource "aws_security_group" "wordpress_80" {
  name        = "wordpress_80"
  description = "Allows ssh,http"
  vpc_id      = aws_vpc.tera_vpc.id

 ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress_80"
  }
}

resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "Bastion host"
  vpc_id      = aws_vpc.tera_vpc.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
  
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name ="bastion"
  }
}

resource "aws_security_group" "mysqlsg" {
  name        = "sql_sec"
  description = "Allow mysql"
  vpc_id      = aws_vpc.tera_vpc.id

ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.wordpress_80.id]
  }
  
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}

  tags = {
    Name ="sql_sec"
  }
}


resource "aws_security_group" "bashion_allow" {
  name        = "bashion_allow"
  description = "Allow bashion"
  vpc_id      = aws_vpc.tera_vpc.id

ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}

  tags = {
    Name ="bashion_allow"
  }
}

resource "aws_eip" "eip"{
vpc=true
}


resource "aws_nat_gateway" "nat_gw"{
allocation_id= aws_eip.eip.id
subnet_id=aws_subnet.subnet1a.id
depends_on= [aws_internet_gateway.tera_gw]
}

resource "aws_route_table" "route_tb" {
  vpc_id = aws_vpc.tera_vpc.id

route{
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.nat_gw.id
  }

   tags = {
    Name = "route_table2"
  }
}

resource "aws_route_table_association" "route_asso" {
  subnet_id      = aws_subnet.subnet1b.id
  route_table_id = aws_route_table.route_tb.id
}

resource "aws_instance" "wordpress" {
  ami           = "ami-7e257211"
  instance_type = "t2.micro"
  key_name = "KEYSSS"
  vpc_security_group_ids =[aws_security_group.wordpress_80.id]
  subnet_id = aws_subnet.subnet1a.id
 

  tags = {
    Name = "wordpress"
  }
}

resource "aws_instance" "bashion" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  key_name = "KEYSSS"
  vpc_security_group_ids =[aws_security_group.bastion.id]
  subnet_id = aws_subnet.subnet1a.id
 

  tags = {
    Name = "bastion"
  }
}
resource "aws_instance" "mysql" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name = "KEYSSS"
  vpc_security_group_ids =[aws_security_group.mysqlsg.id,aws_security_group.bashion_allow.id]
  subnet_id = aws_subnet.subnet1b.id
 

  tags = {
    Name = "mysql"
  }
}
