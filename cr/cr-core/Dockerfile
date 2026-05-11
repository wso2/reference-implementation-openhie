FROM ballerina/ballerina:2201.13.1 AS builder
WORKDIR /home/ballerina
COPY --chown=ballerina:ballerina . .
RUN bal build

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /home/ballerina/target/bin/*.jar app.jar
# TODO (production): remove this COPY and instead mount Config.toml at runtime,
# e.g. add to docker-compose.yml under core: volumes: - ./cr-core/Config.toml:/app/Config.toml:ro
# so credentials are never baked into the image layer.
COPY Config.docker.toml Config.toml
EXPOSE 9090
ENTRYPOINT ["java", "-jar", "app.jar"]
