# Use the official Alpine image as the base
FROM nginx:alpine

# Install Nginx
RUN apk update &&  apk add nginx

# Copy default settings for Nginx
#COPY default.conf /etc/nginx/conf.d/

# Copy custom HTML file to the Nginx directory
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

# Start Nginx when the container starts
CMD ["nginx", "-g", "daemon off;"]
