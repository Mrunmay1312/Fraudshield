FROM maven:3.9.4-eclipse-temurin-17 AS build

WORKDIR /build
COPY . .
RUN mvn -DskipTests package

FROM eclipse-temurin:17
WORKDIR /app
COPY --from=build /build/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]

