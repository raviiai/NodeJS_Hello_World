
####################################
## Create a VPC
####################################

resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "hello_world_ecs_vpc"
  }
}

####################################
## Create a subnet
####################################

resource "aws_subnet" "ecs_subnet" {
  vpc_id            = aws_vpc.ecs_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2b"
  tags = {
    Name = "ecs-subnet"
  }
}

####################################
## Create an internet gateway
####################################

resource "aws_internet_gateway" "ecs_igw" {
  vpc_id = aws_vpc.ecs_vpc.id
  tags = {
    Name = "ecs-igw"
  }
}

####################################
## Create a route table
####################################

resource "aws_route_table" "ecs_route_table" {
  vpc_id = aws_vpc.ecs_vpc.id
  tags = {
    Name = "ecs-route-table"
  }
}

####################################
## Create a route to the internet gateway
####################################

resource "aws_route" "ecs_route" {
  route_table_id         = aws_route_table.ecs_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ecs_igw.id
}

####################################
## Associate the route table with the subnet
####################################

resource "aws_route_table_association" "ecs_route_table_association" {
  subnet_id      = aws_subnet.ecs_subnet.id
  route_table_id = aws_route_table.ecs_route_table.id
}

####################################
## Create a security group for the ECS service
####################################

resource "aws_security_group" "ecs_security_group" {
  vpc_id      = aws_vpc.ecs_vpc.id
  name_prefix = "ecs-sg-"
  description = "Security group for ECS tasks"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

####################################
## Create an IAM role for the task execution
####################################

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Effect = "Allow",
        Sid = ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

####################################
## Create an IAM role for the task
####################################

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Effect = "Allow",
        Sid = ""
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name   = "ecsTaskPolicy"
  role   = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "ecs:Describe*",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

####################################
## Create an ECS cluster
####################################

resource "aws_ecs_cluster" "hello_world_cluster" {
  name = "hello-world-cluster"
}

####################################
## Define the ECS task definition
####################################

resource "aws_ecs_task_definition" "hello_world_task" {
  family                   = "hello-world-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "hello-world-app"
    image     = "raviiai/hello_world:latest"
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
  }])
}

####################################
## Create an ECS service
####################################

resource "aws_ecs_service" "hello_world_service" {
  name            = "hello-world-service"
  cluster         = aws_ecs_cluster.hello_world_cluster.id
  task_definition = aws_ecs_task_definition.hello_world_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [aws_subnet.ecs_subnet.id]
    security_groups = [aws_security_group.ecs_security_group.id]
  }
}


# added commetn