resource "aws_db_subnet_group" "main" {
  name       = "url-shortener-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "url-shortener-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier             = "url-shortener-db"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "urlshortener"
  username                = "shortener"
  password                = "<password>"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false

  tags = { Name = "url-shortener-db" }
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "url-shortener-cache-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "url-shortener-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  tags = { Name = "url-shortener-cache" }
}
