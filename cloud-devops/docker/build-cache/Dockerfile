# Önce: bütün klasör kopyalanır. .dockerignore yoksa hangi dosya değişirse değişsin derleme yeniden koşar.
FROM golang:1.26-alpine
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /out/app .
