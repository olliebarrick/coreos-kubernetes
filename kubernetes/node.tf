data "ignition_file" "resolv_conf" {
  filesystem = "root"
  path = "/etc/resolv.conf"
  mode = 420
  content {
    content = "nameserver 1.1.1.1"
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm   = "RSA"
  rsa_bits = "2048"
}

data "ignition_file" "ssh_key" {
  filesystem = "root"
  path = "/etc/ansible/ssh_key"
  mode = 384
  content {
    content = "${tls_private_key.ssh_key.private_key_pem}"
  }
}

data "ignition_systemd_unit" "ansible-bootstrap" {
    name = "ansible-bootstrap.service"

    content = <<EOF
[Unit]
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/docker run --net=host -v /etc/ansible/ssh_key:/etc/ansible/ssh_key:ro --entrypoint ansible-runner justinbarrick/ansible-test -p /opt/ansible/playbook.yaml --inventory /etc/ansible/hosts run /tmp/private

[Install]
WantedBy=multi-user.target
EOF
}

locals {
  systemd = [
    "${data.ignition_systemd_unit.ansible-bootstrap.id}"
  ]

  files = [
    "${data.ignition_file.metadata.id}",
    "${data.ignition_file.resolv_conf.id}",
    "${data.ignition_file.etcd_ca_cert.id}",
    "${data.ignition_file.etcd_client_cert.id}",
    "${data.ignition_file.etcd_client_key.id}",
    "${data.ignition_file.ssh_key.id}",
  ]
}

data "ignition_config" "master" {
  systemd = ["${local.systemd}"]

  files = [
    "${data.ignition_file.ca_cert.id}",
    "${data.ignition_file.ca_key.id}",
    "${data.ignition_file.front_proxy_ca_cert.id}",
    "${data.ignition_file.front_proxy_ca_key.id}",
    "${data.ignition_file.sa_key.id}",
    "${data.ignition_file.sa_pub.id}",
    "${data.ignition_file.etcd_cert.id}",
    "${data.ignition_file.etcd_key.id}",
    "${local.files}"
  ]
}

data "ignition_config" "worker" {
  systemd = ["${local.systemd}"]
  files = ["${local.files}"]
}
