apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  default.conf: |
    server {
        listen 80;
        server_name {{ .Values.nginx.config.defaultServerName }};

        location /static/ {
            alias /app/static/;
        }

        location / {
            proxy_pass http://{{ .Values.django.service.name }}:{{ .Values.django.containerPort }};
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
