FROM nlnetlabs/routinator:latest
COPY entrypoint.sh /opt/
ENTRYPOINT ["/opt/entrypoint.sh"]
# Use the same defaults as the upstream:
CMD ["server", "--rtr", "0.0.0.0:3323", "--http", "0.0.0.0:9556"]
