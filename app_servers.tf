resource "aws_instance" "app" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[count.index].id
  key_name               = "task-tracker-key"
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = { Name = "url-shortener-app-${count.index}" }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/*noble*24.04*amd64*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
