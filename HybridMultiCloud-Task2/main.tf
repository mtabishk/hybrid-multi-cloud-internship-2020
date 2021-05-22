# Cloud Provider details
provider "aws" {
    region="ap-south-1"
    profile="default"
}

# Creating a key pair 
variable "key_name" { 
    default = "key1"
}
	
resource "tls_private_key" "example" {
	  algorithm = "RSA"
	  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
	  depends_on = [
	    tls_private_key.example
	  ]
	  key_name   = "${var.key_name}"
	  public_key = "${tls_private_key.example.public_key_openssh}"
}

#To create security group with http and ssh
resource "aws_security_group" "allow_tls" {
	  name        = "allow_tls"
	  description = "Allow TLS inbound traffic"
	
	  ingress {
	    description = "SSH"
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
	    Name = "allow_tls"
	  }
}

#variable to store the AMI name
variable "ami_name" {
  type    = string
  default = "ami-0447a12f28fddb066"
}

# creating EC2 instance and configuring the webserver
resource "aws_instance" "web" {
	  ami             = "${var.ami_name}"
	  instance_type   = "t2.micro"
	  key_name        = aws_key_pair.generated_key.key_name
	  security_groups = [ "${aws_security_group.allow_tls.name}" ]
	  
      connection {
	    type     = "ssh"
	    user     = "ec2-user"
	    private_key = tls_private_key.example.private_key_pem
	    host     = aws_instance.web.public_ip
      }
	
	  provisioner "remote-exec" {
	    inline = [
	      "sudo yum install httpd  php git -y",
	      "sudo systemctl restart httpd",
	      "sudo systemctl enable httpd",
	    ]
	  }
	

	  tags = {
	    Name = "redhat_webserver_terr"
	  }
}

# Creating EFS Server
resource "aws_efs_file_system" "web_vol" {
	  creation_token = "webserver-efs-file-system"
	

	  tags = {
	    Name = "webserver_vol"
	  }
}

resource "aws_efs_mount_target" "efs-mount" {
	  file_system_id = "${aws_efs_file_system.web_vol.id}"
	  subnet_id      = "subnet-0f20d73e825bd2692"
}

resource "null_resource" "git_code"  {
	

	depends_on = [
	    aws_efs_mount_target.efs-mount,
	  ]
	


	  connection {
	    type     = "ssh"
	    user     = "ec2-user"
	    private_key = tls_private_key.example.private_key_pem
	    host     = aws_instance.web.public_ip
	  }
	

	  provisioner "remote-exec" {
	    inline = [
	      "sudo mkfs.ext4  /dev/xvdh",
	      "sudo mount  /dev/xvdh  /var/www/html",
	      "sudo rm -rf /var/www/html/*",
	      "sudo git clone https://github.com/mtabishk/HybridMultiCloud-Task2.git /var/www/html/"
	    ]
	  }
}

# Creating S3 bucket
resource "aws_s3_bucket" "b" {
	  bucket = "webserver-bucket-terr-12345"
	  region = "ap-south-1"
	  force_destroy = true
	  tags = {
	    Name        = "web_bucket"
	    Environment = "Dev"
	  } 
}
	

	

resource "aws_s3_bucket_object" "s3_object" {
	  depends_on = [
	    aws_s3_bucket.b,
	  ]
	  bucket = aws_s3_bucket.b.id
	  key    = "hybrid2.jpg"
	  acl    = "public-read"
	  source = "C:/Users/mtabi/Desktop/aws-task2/hybrid2.jpg"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
	  comment = "webserver_cloud_front"
	}
	

resource "aws_cloudfront_distribution" "s3_distribution" {
	  origin {
	    domain_name = "${aws_s3_bucket.b.bucket_regional_domain_name}"
	    origin_id   = "S3-webserver-bucket-terr-12345"
	

	    s3_origin_config {
	      origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
	    }
	  }
	

	  enabled             = true
	  is_ipv6_enabled     = true
	  default_root_object = "hybrid2.jpg"
	

	  default_cache_behavior {
	    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
	    cached_methods   = ["GET", "HEAD"]
	    target_origin_id = "S3-webserver-bucket-terr-12345"
	

	    forwarded_values {
	      query_string = false
	

	      cookies {
	        forward = "none"
	      }
	    }
	

	    viewer_protocol_policy = "allow-all"
	    min_ttl                = 0
	    default_ttl            = 3600
	    max_ttl                = 86400
	  }
	

	  price_class = "PriceClass_100"
	

	  restrictions {
	    geo_restriction {
	      restriction_type = "whitelist"
	      locations        = ["IN"]
	    }
	  }
	

	  tags = {
	    Environment = "production"
	  }
	

	  viewer_certificate {
	    cloudfront_default_certificate = true
	  }
	

	  connection {
	    type     = "ssh"
	    user     = "ec2-user"
	    private_key = tls_private_key.example.private_key_pem
	    host     = aws_instance.web.public_ip
	  }
	

	  provisioner "remote-exec" {
	    inline = [
	      "sudo chmod +x /tmp/script.sh",
	      "sudo su << EOF" ,
	      "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.s3_object.key}' height='200px' width='200px'>\" >> /var/www/html/index.php",
	      "EOF" 
	    ]
	  }  
}

data "aws_iam_policy_document" "s3_policy" {
	  statement {
	    actions   = ["s3:GetObject"]
	    resources = ["${aws_s3_bucket.b.arn}/*"]
	

	    principals {
	      type        = "AWS"
	      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
	    }
	  }
	  statement {
	    actions   = ["s3:ListBucket"]
	    resources = [aws_s3_bucket.b.arn]
	

	    principals {
	      type        = "AWS"
	      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
	    }
	  }
}
	

resource "aws_s3_bucket_policy" "bucket_policy" {
	  bucket = aws_s3_bucket.b.id
	  policy = data.aws_iam_policy_document.s3_policy.json
}