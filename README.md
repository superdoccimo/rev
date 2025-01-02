# Nginx Reverse Proxy with Auto SSL

A simple toolkit for setting up Nginx reverse proxy with automatic SSL certificate management.

## Quick Start Guide

1.  Edit `init-letsencrypt.sh` to set your domain. Make sure your domain name is properly linked to your IP address.

2.  Clone this repository:

    ```bash
    git clone https://github.com/superdoccimo/rev.git

    cd rev 
    ```

3.  Add execute permissions to the scripts:

    ```bash
    chmod +x init-letsencrypt.sh enable-https.sh
    ```

4.  Run the initial setup script:

    ```bash
    sudo ./init-letsencrypt.sh
    ```

5.  Enable HTTPS:

    ```bash
    sudo ./enable-https.sh
    ```

## Requirements

*   Docker
*   Docker Compose
*   A domain name pointing to your server's IP address

## Additional Resources

*   [Tutorial Blog](ここにチュートリアルのブログ記事へのリンク)
*   [Setup Guide Blog Post](ここにセットアップガイドのブログ記事へのリンク)
*   [Video Tutorial](ここにビデオチュートリアルへのリンク)
*   [Setup Guide Video](ここにセットアップガイドビデオへのリンク)