# Cloud Provider details
provider "aws" {
    region="ap-south-1"
    profile="default"
}

#To create security group with http and ssh
resource "aws_security_group" "webapp-sg" {
  name        = "webapp-sg"
  description = "allow ssh and http traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  
 }

}

# creating an EBS Volume
resource "aws_ebs_volume" "mywebApp-ebs" {
  availability_zone = "ap-south-1a"
  size              = 5
  type              = "gp2"
  tags = {
    Name = "webApp-ebs"
  }
}

#variable to store the AMI name
variable "ami_name" {
  type    = string
  default = "ami-0732b62d310b80e97"
}

# To create instance 
resource "aws_instance" "mywebApp-Instance" {
	ami		   = var.ami_name
	availability_zone  = "ap-south-1a"
	instance_type	   = "t2.micro"
	key_name	   = "mtabishkawskey"
	security_groups	   = ["${aws_security_group.webapp-sg.name}"]
	user_data	   = <<-EOF
			       #! /bin/bash
			       sudo su - root
			       yum install httpd -y
			       yum install php -y
			       yum install git -y
			       yum update -y
			       systemctl start httpd
			       systemctl enable httpd
	EOF
    tags = {
    Name = "webApp-Instance"
  }
}

# Attach the EBS volume
resource "aws_volume_attachment" "ebs_att" {
	device_name  = "/dev/sdh"
	volume_id    = "${aws_ebs_volume.mywebApp-ebs.id}"
	instance_id  = "${aws_instance.mywebApp-Instance.id}"
    force_detach = true
}

#To format mount and download git data into dir
resource "null_resource" "format_drive_git" {

	connection {
		type  = "ssh"
		user  = "ec2-user"
		private_key  = file("C:/Users/mtabi/Desktop/aws-task1/mtabishkawskey.pem")
		host  = aws_instance.mywebApp-Instance.public_ip
	}
	provisioner "remote-exec" {
		inline = [ 
			     "sudo mkfs.ext4 /dev/xvdh",
			     "sudo mount /dev/xvdh /var/www/html",
			     "sudo rm -rf /var/www/html/*",
			     "sudo git clone https://github.com/mtabishk/HybridMultiCloud-Task1.git /var/www/html/",
		]
		
	}
	depends_on  = [
        "aws_volume_attachment.ebs_att"
        ]
}
#To create S3 bucket
resource "aws_s3_bucket" "mywebappbucket777" {
  bucket = "mywebappbucket777"
  acl    = "public-read"
  force_destroy  = true
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["https://mywebappbucket777"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
#To upload data to S3 bucket
resource "null_resource" "upload_to_s3_bucket" {
  provisioner "local-exec" {
    command = "C:/Users/mtabi/Desktop/aws-task1/upload_s3.bat"
  }
  depends_on  = ["aws_s3_bucket.mywebappbucket777"]
}

# Create Cloudfront distribution
resource "aws_cloudfront_distribution" "distribution" {
    origin {
        domain_name = "${aws_s3_bucket.mywebappbucket777.bucket_regional_domain_name}"
        origin_id = "S3-${aws_s3_bucket.mywebappbucket777.bucket}"
 
        custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }
    # By default, show index.php file
    default_root_object = "hybrid1.png"
    enabled = true
    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-${aws_s3_bucket.mywebappbucket777.bucket}"


        #Not Forward all query strings, cookies and headers
        forwarded_values {
            query_string = false
	    cookies {
		forward = "none"
	    }
            
        }


        viewer_protocol_policy = "redirect-to-https"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }


    # Distributes content to all
    price_class = "PriceClass_All"


    # Restricts who is able to access this content
    restrictions {
        geo_restriction {
            # type of restriction, blacklist, whitelist or none
            restriction_type = "none"
        }
    }


    # SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}
# printing the url of the cloudfront distribution
output "cloudfront_ip_addr" {
  value = aws_cloudfront_distribution.distribution.domain_name
}


 




