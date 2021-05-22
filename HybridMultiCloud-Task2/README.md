# HybridMultiCloud-Task2

Hello World!

This task was on End-to-End #automation for creating/launching Applications on AWS Cloud (EC2, EFS, S3, Cloudfront) using Terraform

Problem Statement:
1. Create Security group which allow the port 80.

2. Launch EC2 instance.

3. In this Ec2 instance use the existing key or provided key and security group which we have created in step 1.

4. Launch one Volume using the EFS service and attach it in your vpc, then mount that volume into /var/www/html

5. Developer have uploded the code into github repo also the repo has some images.

6. Copy the github repo code into /var/www/html

7. Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.

8 Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to update in code in /var/www/html

Link: https://www.linkedin.com/pulse/launching-webapp-aws-cloud-ec2-efs-s3-cloudfront-using-khanday/
