# Nginx Reverse Proxy with Auto SSL

A simple toolkit for setting up Nginx reverse proxy with automatic SSL certificate management.

## Quick Start Guide

1. Edit `init-letsencrypt.sh` to configure your settings:
   ```bash
   # Edit these settings in init-letsencrypt.sh
   domains=(your-domain.com)    # Your domain name
   email="your-email@example.com"
   staging=1                    # Set to 1 for testing, 0 for production
   ```

2. Clone this repository:
   ```bash
   git clone https://github.com/superdoccimo/rev.git
   cd rev
   ```

3. Add execute permission to the script:
   ```bash
   chmod +x init-letsencrypt.sh
   ```

4. Run the setup script:
   ```bash
   sudo ./init-letsencrypt.sh
   ```

5. After successful test (staging=1), change to production mode:
   - Edit `init-letsencrypt.sh` and set `staging=0`
   - Run the script again:
     ```bash
     sudo ./init-letsencrypt.sh
     ```

## Requirements

* Docker
* Docker Compose
* A domain name pointing to your server's IP address

## Features

* Automatic SSL certificate setup with Let's Encrypt
* Secure SSL configuration
* Automatic certificate renewal
* Easy setup with a single script
* Supports both staging (test) and production environments

## Configuration

The default configuration includes:
* HTTP to HTTPS redirection
* TLS 1.2 and 1.3 support
* Modern cipher suite configuration
* Optional ads.txt support
* Websocket support

## Troubleshooting

If you encounter any issues:

1. Check the Nginx logs:
   ```bash
   docker compose logs nginx-proxy
   ```

2. Verify your domain DNS settings:
   ```bash
   ping your-domain.com
   ```

3. Ensure ports 80 and 443 are open:
   ```bash
   sudo netstat -tulpn | grep -E ':(80|443)'
   ```

## Additional Resources

* [Tutorial Blog](https://showa.fun/reverse-proxy-docker)
* [Tutorial Blog(Japanese)](https://minokamo.tokyo/2025/01/04/8344/)
* [Tutorial Blog(Hindi)](https://minokamo.in/reverse-proxy-ssl)
* [Video Tutorial](https://youtu.be/4flonaHs4mE)
* [Video Tutorial(Japanese)](https://youtu.be/z0VjHrVSv34)

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.