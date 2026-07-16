ARG JAVA_VERSION=21
ARG DEBIAN_VERSION=13
FROM gcr.io/distroless/java${JAVA_VERSION}-debian${DEBIAN_VERSION}

COPY velocity.jar app.jar

WORKDIR /app

CMD ["../app.jar"]
