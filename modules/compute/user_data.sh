#!/bin/bash
apt update -y
apt install -y nginx
systemctl enable nginx
systemctl start nginx

cat <<HTML >/var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
<title>StartupHub</title>
</head>
<body>
<h1>Welcome to StartupHub 🚀</h1>
<p>Provisioned using Terraform.</p>
</body>
</html>
HTML
EOF
