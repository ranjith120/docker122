FROM ubuntu
RUN apt-get update
RUN apt-get install ubuntu -y
EXPOSE 80
CMD ["ubuntu", "-g", "daemon off;"]
