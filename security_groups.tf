resource "aws_security_group" "app" {
  name   = "url-shortener-app-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP from ALB"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # tightened to the ALB's SG once that exists
  }

  ingress {
    description = "SSH"
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

  tags = { Name = "url-shortener-app-sg" }
}

resource "aws_security_group" "rds" {
  name   = "url-shortener-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "Postgres from app servers only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "url-shortener-rds-sg" }
}

resource "aws_security_group" "redis" {
  name   = "url-shortener-redis-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "Redis from app servers only"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "url-shortener-redis-sg" }
}
