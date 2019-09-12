FROM linuxserver/letsencrypt
COPY default /config/nginx/site-confs/
COPY krill.subdomain.conf /config/nginx/proxy-confs/

EXPOSE 80/tcp
EXPOSE 443/tcp
