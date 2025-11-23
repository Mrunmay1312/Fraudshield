FROM registry.access.redhat.com/ubi8/openjdk-17-runtime:1.17

WORKDIR /app

# Copy Quarkus app structure
COPY target/quarkus-app/lib/ /app/lib/
COPY target/quarkus-app/app/ /app/app/
COPY target/quarkus-app/quarkus/ /app/quarkus/
COPY target/quarkus-app/quarkus-run.jar /app/

EXPOSE 8080

CMD ["java", "-jar", "/app/quarkus-run.jar"]

