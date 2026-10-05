# Sayfadaki örneklerin derlendiği ortam: Cortex-M için arm-none-eabi-gcc, çalıştırılan örnekler için yerel gcc.
# Kullanım: docker build -t volatile-ornek . && docker run --rm volatile-ornek
FROM debian:13-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc gcc-arm-none-eabi libc6-dev \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /ornek
COPY . .
CMD ["bash", "demo.sh"]
