ARG JAVA_VERSION=21
ARG DEBIAN_VERSION=13

# distroless には OpenSSL が無い。Geyser の NetherNet (libdatachannel) が libcrypto.so.3 を要求するので、
# 同じ Debian 世代の libssl (と libcrypto が依存する libzstd) だけを取り出して持ち込む
FROM debian:${DEBIAN_VERSION}-slim AS openssl
RUN apt-get update \
    && for pkg in libssl3t64 libssl3 libssl1.1; do \
         if apt-cache show "$pkg" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$pkg" libzstd1 && break; fi; \
       done \
    && mkdir /out \
    && cd / \
    && cp --parents -a usr/lib/*-linux-gnu/libssl.so.* usr/lib/*-linux-gnu/libcrypto.so.* usr/lib/*-linux-gnu/libzstd.so.* /out/

FROM gcr.io/distroless/java${JAVA_VERSION}-debian${DEBIAN_VERSION}

COPY --from=openssl /out/ /

COPY velocity.jar app.jar

WORKDIR /app

CMD ["../app.jar"]
