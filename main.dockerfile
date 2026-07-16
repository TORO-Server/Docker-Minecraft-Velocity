ARG JAVA_VERSION=21
FROM gcr.io/distroless/java${JAVA_VERSION}-debian13

COPY velocity.jar app.jar

WORKDIR /app

CMD ["../app.jar"]
