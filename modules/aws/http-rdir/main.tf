terraform {
  required_version = ">= 0.10.0"
}

data "aws_region" "current" {
  current = true
}

resource "aws_key_pair" "http-rdir" {
  key_name = "http-rdir-key"
  public_key = "${file(var.ssh_public_key)}"
}

resource "aws_instance" "http-rdir" {
  // Currently, variables in provider fields are not supported :(
  // This severely limits our ability to spin up instances in diffrent regions 
  // https://github.com/hashicorp/terraform/issues/11578

  //provider = "aws.${element(var.regions, count.index)}"

  count = "${var.count}"
  
  tags = {
    Name = "http-rdir-${count.index}"
  }

  ami = "${lookup(var.amis, data.aws_region.current.name)}"
  instance_type = "${var.instance_type}"
  key_name = "${aws_key_pair.http-rdir.key_name}"
  vpc_security_group_ids = ["${aws_security_group.http-rdir.id}"]
  subnet_id = "${var.subnet_id}"
  associate_public_ip_address = true

  provisioner "remote-exec" {
    inline = [
        "apt-get update",
        "apt-get install -y tmux socat",
        "tmux new -d \"socat TCP4-LISTEN:80,fork TCP4:${element(var.http_c2_ips, count.index)}:80\" ';' split \"socat TCP4-LISTEN:443,fork TCP4:${element(var.http_c2_ips, count.index)}:443\""
    ]

    connection {
        type = "ssh"
        user = "admin"
        private_key = "${file(var.ssh_private_key)}"
    }
  }

}