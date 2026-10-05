# Sonra: çok aşamalı build. Son imaja yalnız çalışmak için gereken dosyalar taşınır.
# Hedef aşama --target ile seçilir: alpine · distroless · scratch-bare · scratch

# --- 1. aşama: derleme ------------------------------------------------------
FROM golang:1.26-alpine AS build
WORKDIR /src
# Bağımlılık katmanı kaynak koddan önce: kod değişince modüller yeniden indirilmez.
COPY go.mod ./
RUN go mod download
COPY main.go ./
# -s -w: sembol ve debug tablolarını atar · -trimpath: binary'ye yerel dosya yollarını gömmez.
ARG GO_LDFLAGS="-s -w"
RUN CGO_ENABLED=0 go build -trimpath -ldflags="${GO_LDFLAGS}" -o /out/app .

# --- 2. aşama seçenekleri ---------------------------------------------------

# Alpine: shell ve paket yöneticisi var; saat dilimi veritabanı yok.
FROM alpine:3.24 AS alpine
COPY --from=build /out/app /app
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["/app"]

# Distroless static: shell yok; CA sertifikaları, saat dilimleri ve nonroot kullanıcı hazır.
FROM gcr.io/distroless/static-debian12:nonroot AS distroless
COPY --from=build /out/app /app
EXPOSE 8080
ENTRYPOINT ["/app"]

# Karşı örnek: scratch boştur. Binary çalışır ama sertifika ve saat dilimi bulamaz.
FROM scratch AS scratch-bare
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]

# Scratch, eksikler elle eklenmiş hali.
FROM scratch AS scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /usr/local/go/lib/time/zoneinfo.zip /zoneinfo.zip
ENV ZONEINFO=/zoneinfo.zip
COPY --from=build /out/app /app
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["/app"]
