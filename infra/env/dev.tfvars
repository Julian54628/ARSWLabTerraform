prefix              = "lab8"
location            = "canadacentral"
vm_count            = 2
admin_username      = "student"
ssh_public_key      = "~/.ssh/id_ed25519.pub"
allow_ssh_from_cidr = "179.13.167.114/32"
tags = { owner = "julian.arenas", course = "ARSW", env = "dev", expires = "2026-04-30" }
