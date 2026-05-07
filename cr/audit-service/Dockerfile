FROM ballerina/ballerina:2201.13.1 AS builder
WORKDIR /home/ballerina
COPY --chown=ballerina:ballerina . .
RUN bal build

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /home/ballerina/target/bin/*.jar app.jar
RUN mkdir -p /tmp/audit-logs && chown -R appuser:appgroup /app /tmp/audit-logs
RUN apk add --no-cache wget
EXPOSE 9096
USER appuser
ENTRYPOINT ["java", "-jar", "app.jar"]
