Terraform configuration for deployment of EC2 instance with attached EFS Storage,RDS DB and Load Balancer
The EC2 Instance is configured to install BookStack PHP server(https://github.com/BookStackApp/BookStack)
You can login with the email 'admin@admin.com' and password of 'password'

The following elements are created:
VPC with  internet access
2 subnets for db multiple AZ deployments
2 subnets for lb multiple AZ deployments
1 subnet for web server
1 RDS Instance
1 Web Server Instance
1 Application Load Balancer
1 Sec. Group for RDS Access(restricted to Web Server)
1 Sec. Group for Web Servers(restricted to Load Balancer)
1 Sec. Group for LB(Open http access)
1 CloudWatch alarm for number of active connection on lb
1 EFS
1 AMI for further autoscale