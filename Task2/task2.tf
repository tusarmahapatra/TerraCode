provider "aws" {
  region                  = "ap-south-1"
  profile                 = "Tushar08"
}


resource "aws_s3_bucket" "terrabucket0804199831415926" {
  bucket = "terrabucket0804199831415926"
  acl    = "private"

  tags = {
    Name        = "Terra-bucket1"
    Environment = "Dev"
  }
}



resource "aws_s3_bucket_public_access_block" "sbb" {

   depends_on = [
    aws_s3_bucket.terrabucket0804199831415926,
  ]
  
  bucket = aws_s3_bucket.terrabucket0804199831415926.id
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}



resource "aws_security_group" "secure2" {
  name        = "secure2"
  description = "created using terraform"
  vpc_id      = "vpc-d9fbe6b1"

  ingress {
    description = "ssh inbound rule using terraform"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks=["::/0"]
  }

  ingress {
    description = "http inbound rule using terraform"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks=["::/0"]
  }

  ingress {
    description = "custom tcp inbound rule using terraform"
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks=["::/0"]
  }
  
  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks=["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "secure2"
  }
}


resource "tls_private_key" "key-pair" {
algorithm = "RSA"
rsa_bits  = 4096 
}


resource "aws_key_pair" "Private" {
key_name = "Private"
public_key = tls_private_key.key-pair.public_key_openssh


depends_on = [ tls_private_key.key-pair , ]
}




resource "aws_efs_file_system" "efs1" {

  depends_on = [
    aws_security_group.secure2,
  ]
  
  creation_token = "TEFS_1"

  tags = {
    Name = "TEFS_1"
  }
}




resource "aws_efs_mount_target" "mt1" {
 
  depends_on = [
    aws_efs_file_system.efs1,
  ]
  file_system_id = aws_efs_file_system.efs1.id
  subnet_id      = "subnet-37142e5f"
  security_groups = [aws_security_group.secure2.id]
}



resource "aws_efs_mount_target" "mt2" {

  depends_on = [
    aws_efs_mount_target.mt1,
  ]
  file_system_id = aws_efs_file_system.efs1.id
  subnet_id      = "subnet-8a1ba9f1"
  security_groups = [aws_security_group.secure2.id]  
}



resource "aws_efs_mount_target" "mt3" {

  depends_on = [
    aws_efs_mount_target.mt2,
  ]
  file_system_id = aws_efs_file_system.efs1.id
  subnet_id      = "subnet-d50e6599"
  security_groups = [aws_security_group.secure2.id]
}




resource "aws_instance"  "i2" {

   depends_on = [
    aws_efs_mount_target.mt3,
	aws_cloudfront_distribution.sbc,
  ]
  
  ami           = "ami-005956c5f0f757d37"
  instance_type = "t2.micro"
  key_name	= "Private"
  security_groups =  [ "secure2" ] 
  availability_zone = "ap-south-1a"
  
  user_data = <<-EOF
		 #!/bin/bash
		 sudo yum install -y amazon-efs-utils
		 sudo yum install -y nfs-utils
		 file_system_id_1="${aws_efs_file_system.efs1.id}"
         mkdir /var/www
		 mkdir /var/www/html
         mount -t efs $file_system_id_1:/ /var/www/html
		 echo $file_system_id_1:/ /var/www/html efs defaults,_netdev 0 0 >> /etc/fstab
	EOF
	
  tags = {
    Name = "NewTerraOS1"
  }
}




locals {
  s3_origin_id = aws_s3_bucket.terrabucket0804199831415926.bucket
}

resource "aws_cloudfront_distribution" "sbc" {
	
	 depends_on = [
   aws_s3_bucket_object.sbo,
  ]
  
  origin {
    domain_name = "${aws_s3_bucket.terrabucket0804199831415926.bucket}.s3.amazonaws.com"
    origin_id   = aws_s3_bucket.terrabucket0804199831415926.bucket

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/E17QIG35HLFQBX"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = ""
  default_root_object = ""
  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.terrabucket0804199831415926.bucket

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = {
    Environment = "TerraCloud"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}




resource "aws_s3_bucket_policy" "sbp" {

  depends_on = [
   aws_s3_bucket_public_access_block.sbb,
  ]
  
  bucket = aws_s3_bucket.terrabucket0804199831415926.id
  policy = <<EOF
{
  "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "1",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity E17QIG35HLFQBX"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.terrabucket0804199831415926.bucket}/*"
        }
    ]
}
EOF
}




resource "aws_s3_bucket_object" "sbo" {

  depends_on = [
   aws_s3_bucket_policy.sbp,
  ]
  
  bucket = aws_s3_bucket.terrabucket0804199831415926.id
  key    = "img.jpg"
  source = "C:/Users/KIIT/Desktop/studies/JS wala part/img.jpg"
  content_type = "image/jpeg"
  content_disposition = "inline"
}




resource "null_resource" "nullresource"  {

 depends_on = [
   aws_instance.i2,
  ]

    connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.key-pair.private_key_pem
    host     = aws_instance.i2.public_ip
  }

provisioner "remote-exec" {

    inline = [
      "sudo yum install httpd  php git -y",
	  "sudo service httpd start",
	  "sudo service httpd enabled",
      "sudo rm -rf /var/www/html",
      "sudo git clone https://github.com/Tusar6701/TerraCode.git /var/www/html",
	  "sudo sed -i 's/domain_name/${aws_cloudfront_distribution.sbc.domain_name}/g' /var/www/html/INT.html" 
    ]
  }
}




resource "null_resource" "ncl"  {


depends_on = [
    null_resource.nullresource,
  ]

	provisioner "local-exec" {
	    command = "start chrome  http://${aws_instance.i2.public_ip}/INT.html"
  	}
}
