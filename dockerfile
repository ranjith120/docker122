FROM nginx
RUN apt-get update
RUN apt-get install ubuntu -y
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
