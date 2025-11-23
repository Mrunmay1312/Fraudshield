FROM quay.io/quarkus/quarkus-micro-image:3.3.0.Final
COPY target/*-runner /work/application
EXPOSE 8080
CMD ["/work/application","-Dquarkus.http.host=0.0.0.0"]