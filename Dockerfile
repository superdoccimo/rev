# Dockerfile
FROM nginx:alpine

# Copy Nginx configuration files into the container
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Add additional operations here as needed
# RUN apk add --no-cache ...

# Run Nginx in the foreground when the container starts
CMD ["nginx", "-g", "daemon off;"]
