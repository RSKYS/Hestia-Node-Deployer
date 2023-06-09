#!/bin/bash

# Hestia build script for Linux Distribution

# Copyright 2022-2023 Pouria Rezaei <Pouria.rz@outlook.com>
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

if [[ $(id -u) != "0" ]]; then
	echo "Script needs to run under superuser."
	exit 1
fi

# Check
read -r -p "Enter the port: " Port
mkdir -p /usr/local/hestia/data/templates/web/nginx

( cd /usr/local/hestia/data/templates/web/nginx # The Start

# rm -f node-*.*
cat > "node-$Port.tpl" <<TPL
server {
        listen %ip%:%proxy_port%;
        server_name %domain_idn% %alias_idn%;
        error_log /var/log/%web_system%/domains/%domain%.error.log error;

        location / {
                proxy_pass http://127.0.0.1:$Port;
                proxy_http_version 1.1;
                proxy_set_header Upgrade \$http_upgrade;
                proxy_set_header Connection 'upgrade';
                proxy_set_header Host \$host;
                proxy_cache_bypass \$http_upgrade;
            }

        location /error/ {
                 alias %home%/%user%/web/%domain%/document_errors/;
        }

        location @fallback {
                 proxy_pass http://127.0.0.1:$Port:/\$1;
        }

        location ~ /\.ht {return 404;}
        location ~ /\.svn/ {return 404;}
        location ~ /\.git/ {return 404;}
        location ~ /\.hg/ {return 404;}
        location ~ /\.bzr/ {return 404;}
        include %home%/%user%/conf/web/nginx.%domain%.conf*;
}
TPL

cat > "node-$Port.stpl" <<STPL
server {
        listen %ip%:%proxy_port%;
        server_name %domain_idn%
        return 301 https://%domain_idn%\$request_uri;
}

server {
        listen %ip%:%proxy_ssl_port% http2 ssl;
        server_name %domain_idn%;
        ssl_certificate %ssl_pem%;
        ssl_certificate_key %ssl_key%;
        error_log /var/log/%web_system%/domains/%domain%.error.log error;
        gzip on;
        gzip_min_length 1100;
        gzip_buffers 4 32k;
        gzip_types image/svg+xml svg svgz text/plain application/x-javascript text/xml text/css;
        gzip_vary on;

        location / {
                proxy_pass http://127.0.0.1:$Port;
                proxy_http_version 1.1;
                proxy_set_header Upgrade \$http_upgrade;
                proxy_set_header Connection 'upgrade';
                proxy_set_header Host \$host;
                proxy_cache_bypass \$http_upgrade;
        }

        location /error/ {
                alias %home%/%user%/web/%domain%/document_errors/;
        }

        location @fallback {
                proxy_pass https://127.0.0.1:$Port:/\$1;
        }

        location ~ /\.ht {return 404;}
        location ~ /\.svn/ {return 404;}
        location ~ /\.git/ {return 404;}
        location ~ /\.hg/ {return 404;}
        location ~ /\.bzr/ {return 404;}
        include %home%/%user%/conf/web/s%proxy_system%.%domain%.conf*;

}
STPL

cat > "node-$Port.sh" <<SH
#!/bin/bash
user=\$1
domain=\$2
ip=\$3
home=\$4
docroot=\$5

mkdir "\$home/\$user/web/\$domain/nodeapp"
chown -R \$user:\$user "\$home/\$user/web/\$domain/nodeapp"
rm "\$home/\$user/web/\$domain/nodeapp/app.sock"
runuser -l \$user -c "pm2 start \$home/\$user/web/\$domain/nodeapp/app.js"
sleep 5
chmod 777 "\$home/\$user/web/\$domain/nodeapp/app.sock"
SH

chmod +x node-$Port.*

) # The End
