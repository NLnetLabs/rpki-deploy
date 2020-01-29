FROM nginx:1.17.8
COPY krill.conf /etc/nginx/conf.d/default.conf
WORKDIR /etc/ssl/certs
COPY certbundle.pem .
WORKDIR /etc/ssl/keys
COPY krill.key .
WORKDIR /root
EXPOSE 80/tcp
EXPOSE 443/tcp
