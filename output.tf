# Private Load Balancers

#output "galera_address" {
#  value = "${aws_elb.db_mysql.dns_name}"
#}

output "web-elb-dns-name" {
  value = "${aws_elb.web.dns_name}"
}

output "web-elb-zone-id" {
  value = "${aws_elb.web.zone_id}"
}
