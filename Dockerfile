FROM linuxserver/qbittorrent:latest

# Copy your entrypoint script that handles VPN + kill switch
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
