resource "digitalocean_ssh_key" "my_public_key" {
	name = "my_public_key"
	public_key = file(var.my_public_key)
}

data "external" "ssh_rebrain" {
	program = ["bash", "./key.sh"]
	query = {
		do_token = var.do_token
	}
}

data "aws_route53_zone" "primary" {
        name = "devops.rebrain.srwx.net"
}


resource "digitalocean_droplet" "droplet" {
  for_each = { for droplet in var.droplets : droplet.name => droplet } 
  name     = each.value.name
  image    = each.value.image
  region   = var.region
  size     = each.value.size
  ssh_keys = [digitalocean_ssh_key.my_public_key.fingerprint , data.external.ssh_rebrain.result.fingerprint]
  tags     = [var.email, "devops", var.task_name]
}

resource "aws_route53_record" "ansible_7" {
  depends_on = [digitalocean_droplet.droplet]
  for_each   = digitalocean_droplet.droplet
  zone_id    = data.aws_route53_zone.primary.zone_id
  name       = "${each.key}-ansible7.devops.rebrain.srwx.net"
  type       = "A"
  ttl        = 300
  records    = [each.value.ipv4_address]
}




resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tftpl",
    {
		names = [for d in var.droplets: d.name]#
	        ips =  values(digitalocean_droplet.droplet)[*].ipv4_address 

    }
  )
  filename = "ansible/inventory.yml"
}

