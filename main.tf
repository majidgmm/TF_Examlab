terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

//Create S3 Bucket

resource "aws_s3_bucket" "metroexamlab" {
  bucket = aws_s3_bucket.b.id
 }

//Create IAM Role and attach a policy

data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "instance_role"
  path               = "/system/"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}

//Create a Security Group

resource "aws_security_group" "rds_sg" {
  name        = "allow 3306"
  description = "Allow SQL inbound traffic"
  vpc_id      = "vpc-0e228ab9afd13e62f"

  ingress {
    description = "SQL from Anywhere"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #source_security_group_id = aws_security_group.alb_sg.id
  }

  tags = {
    Name = "allow_tls"
  }
}

//Creae RDS

resource "aws_db_instance" "myrds" {
  allocated_storage    = 20
  db_name              = "metrodb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  //db_subnet_group_name = aws_db_subnet_group.rdssubnetgroupmajid.id
  //multi_az = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

//AWS Glue Job

resource "aws_glue_job" "example" {
  name     = "example"
  role_arn = aws_iam_role.example.arn

  command {
    script_location = "s3://${aws_s3_bucket.example.bucket}/example.py"
  }
}

//Create a KMS Key

resource "aws_kms_key" "a" {
  description             = "KMS key 1"
  deletion_window_in_days = 10
}

//Security Group for ALB

resource "aws_security_group" "alb_sg" {
  name        = "allow_http_ssh"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from Anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

//Create Application Load Balancer

resource "aws_lb" "alb" {
  name               = "web-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public1.id,aws_subnet.public3.id]

  tags = {
    Environment = "production"
  }
}

//Create Launch template and Auto Scaling Group

resource "aws_launch_template" "LT" {
  name_prefix   = "LT"
  image_id      = "ami-00b6fcfc5204b62ed"
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "ASG" {
  availability_zones = ["ca-central-1a","ca-central-1b" ]
  desired_capacity   = 2
  max_size           = 2
  min_size           = 2

  launch_template {
    id      = aws_launch_template.LT.id
    version = "$Latest"
  }
}