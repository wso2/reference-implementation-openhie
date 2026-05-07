FROM ballerina/ballerina:2201.13.1 AS builder
WORKDIR /home/ballerina
COPY --chown=ballerina:ballerina . .
RUN bal build

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /home/ballerina/target/bin/*.jar app.jar
RUN mkdir -p /tmp/audit-logs
EXPOSE 9096
ENTRYPOINT ["java", "-jar", "app.jar"]
