# Sayfadaki örneklerin çalıştığı ortam: temiz bir Debian ve on iki komutun paketleri.
# Kullanım: docker build -t gunluk-komutlar . && docker run --rm gunluk-komutlar
FROM debian:13-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl less openssh-client procps rsync \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /calisma
COPY demo.sh /usr/local/bin/demo.sh
CMD ["bash", "/usr/local/bin/demo.sh"]
