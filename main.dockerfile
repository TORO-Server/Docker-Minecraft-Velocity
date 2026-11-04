ARG JAVA_VERSION=21
ARG DEBIAN_VERSION=13

# Java の実行環境を jlink で作る。入れるモジュールは Temurin の JRE と同じ (JDK の開発ツールだけを外す。
# プラグインが何を使うか分からないので、それ以上は削らない)。小さくなるのは次の 3 つの分:
#  - モジュールのファイルを圧縮する (--compress)
#  - ロケールを en と ja だけにする (--include-locales)
#  - CDS の保存ファイルを入れない (Temurin の JRE には 4 つで 57 MB ある。無くても起動が 1 秒ほど遅くなるだけ)
FROM eclipse-temurin:${JAVA_VERSION}-jdk AS jre
ARG JAVA_VERSION
RUN set -eu; \
    modules=$(java --list-modules | sed 's/@.*//' \
      | grep -vE '^jdk\.(attach|compiler|editpad|graal\.compiler.*|hotspot\.agent|internal\.(ed|jvmstat|le|md|opt|vm\..*)|jartool|javadoc|jcmd|jconsole|jdeps|jdi|jlink|jpackage|jshell|jstatd)$' \
      | paste -sd,); \
    compress=zip-9; \
    if [ "$JAVA_VERSION" -lt 21 ]; then compress=2; fi; \
    mkdir -p /out/usr/lib/jvm /out/usr/bin; \
    jlink --add-modules "$modules" --include-locales=en,ja --compress="$compress" \
      --strip-debug --no-man-pages --no-header-files --output /out/usr/lib/jvm/jre; \
    ln -s ../lib/jvm/jre/bin/java /out/usr/bin/java; \
    # eMudhra の中間 CA の鍵が漏れた件 (JDK-8395690)。OpenJDK の案内 (https://openjdk.org/emudhra) のとおり、関係するルートを外す
    cacerts=/out/usr/lib/jvm/jre/lib/security/cacerts; \
    keytool -list -keystore "$cacerts" -storepass changeit 2>/dev/null \
      | grep -iE '^(emsign|comodoaaa|aaa ?certificate)' | cut -d, -f1 \
      | while read -r alias; do keytool -delete -keystore "$cacerts" -storepass changeit -alias "$alias"; done; \
    install -d -o 65532 -g 65532 /out/app

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

# java-base: distroless/java から JRE だけを除いたもの (フォント、fontconfig、CA 証明書など、JRE が使うものは入っている)
FROM gcr.io/distroless/java-base-debian${DEBIAN_VERSION}

COPY --from=jre /out/ /
COPY --from=openssl /out/ /

COPY velocity.jar /app.jar

# 非 root で動かす。/app をマウントするときは、その持ち主を --user で渡す
USER 65532:65532
WORKDIR /app

ENTRYPOINT ["/usr/bin/java", "-jar"]
CMD ["../app.jar"]
