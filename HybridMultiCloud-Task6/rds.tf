//SECURITY GROUP
resource "aws_security_group" "secgrp-rds" {

  name        = "secgrp-rds"
  description = "Allow MySQL Port"
 
  ingress {
    description = "Allowing Connection for SSH"
    from_port   = 3306
    to_port     = 3306
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
    Name = "RDS"
  }
}

//RDS INSTANCE
resource "aws_db_instance" "rds" {
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  allocated_storage    = 10
  storage_type         = "gp2"
  name                 = "mydb"
  username             = "ishan"
  password             = "redhat123"
  parameter_group_name = "default.mysql5.7"
  publicly_accessible = true
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.secgrp-rds.id]
  tags = {
  name = "RDS"
   }
}
