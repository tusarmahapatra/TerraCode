
provider "aws" {
  region = "ap-south-1"
  profile = "Tushar08"
}



resource "tls_private_key" "key-pair" {
algorithm = "RSA"
}


resource "aws_key_pair" "Private" {
key_name = "Private"
public_key = tls_private_key.key-pair.public_key_openssh


depends_on = [ tls_private_key.key-pair ,]
}



resource "aws_security_group" "secure1" {
   
	name        = "secure1"
  	description = "Allow TLS inbound traffic"
  	vpc_id      = "vpc-d9fbe6b1"


  	ingress {
    		description = "SSH"
    		from_port   = 22
    		to_port     = 22
    		protocol    = "tcp"
    		cidr_blocks = [ "0.0.0.0/0" ]
  	}

  	ingress {
    		description = "HTTP"
    		from_port   = 80
    		to_port     = 80
    		protocol    = "tcp"
    		cidr_blocks = [ "0.0.0.0/0" ]
  	}

  	egress {
    		from_port   = 0
    		to_port     = 0
    		protocol    = "-1"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

  	tags = {
    		Name = "secure1"
  	}
}

resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "Private"
  security_groups = [ "secure1" ]
  
  tags = {
    Name = "NewTerraOS"
  }

}


resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "my_ebs"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvdt"
  volume_id   = aws_ebs_volume.esb1.id
  instance_id = aws_instance.web.id
  force_detach = true
}

resource "aws_s3_bucket" "terrabucket08"{
	bucket = "terrabucket08"
	acl = "public-read"

	
}

resource "aws_s3_bucket_object" "file_upload" {
	depends_on = [
    		aws_s3_bucket.terrabucket08,
  	]
  	bucket = "${aws_s3_bucket.terrabucket08.bucket}"
  	key    = "img.jpg"
  	source = "C:/Users/KIIT/Desktop/studies/JS wala part/img.jpg"
	content_type = "image/jpeg"
    content_disposition = "inline"
	acl="public-read"
}


locals {
  s3_origin_id = aws_s3_bucket.terrabucket08.bucket
}






resource "aws_cloudfront_distribution" "s3_distribution" {
	depends_on = [
		aws_volume_attachment.ebs_att,
    		aws_s3_bucket_object.file_upload,
  	]

	origin {
		domain_name = "${aws_s3_bucket.terrabucket08.bucket}.s3.amazonaws.com"
		origin_id = aws_s3_bucket.terrabucket08.bucket 
		
         s3_origin_config{
            origin_access_identity="origin-access-identity/cloudfront/E17QIG35HLFQBX"
         }


       
        }
	enabled = true
	is_ipv6_enabled = true
        default_root_object = "INT.html"
	
	restrictions {
		geo_restriction {
			restriction_type = "none"
 		 }
 	    }

	default_cache_behavior {
		allowed_methods = ["HEAD", "GET"]
		cached_methods = ["HEAD", "GET"]
                target_origin_id=aws_s3_bucket.terrabucket08.bucket
		forwarded_values {
			query_string = false
			cookies {
				forward = "none"
			}
		}
		default_ttl = 86400
		max_ttl = 31536000
		min_ttl = 0
		viewer_protocol_policy = "redirect-to-https"
		}

	price_class = "PriceClass_All"

	 viewer_certificate {
   		 cloudfront_default_certificate = true
  	}		
}

resource "null_resource" "nullremote3"  {
connection {
    		type     = "ssh"
    		user     = "ec2-user"
   		 private_key = tls_private_key.key-pair.private_key_pem
    		host     ="${aws_instance.web.public_ip}"
  	}

	provisioner "remote-exec" {
    		inline = [
				"sudo yum install httpd php git -y",
				"sudo service httpd start",
				"sudo mkfs.ext4  /dev/xvdt -y",
				"sudo mount  /dev/xvdt  /var/www/html",
				"sudo rm -rf /var/www/html",
      			"sudo git clone  https://github.com/Tusar6701/TerraCode.git   /var/www/html/",
				"sudo sed -i 's/domain_name/${aws_cloudfront_distribution.s3_distribution.domain_name}/g' /var/www/html/INT.html",
				"sudo echo ${aws_cloudfront_distribution.s3_distribution.domain_name}"
    		]
	  }
	  
				
}


resource "null_resource" "nulllocal1"  {
	depends_on = [
    		null_resource.nullremote3,
  	]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.web.public_ip}/INT.html"
  	}
}

