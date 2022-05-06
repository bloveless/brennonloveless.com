FROM alpine:3.15.4 as builder

RUN mkdir -p /go/tmp

WORKDIR /go/tmp

RUN wget https://github.com/gohugoio/hugo/releases/download/v0.98.0/hugo_0.98.0_Linux-ARM64.tar.gz && tar xvvf hugo_0.98.0_Linux-ARM64.tar.gz && mv hugo /usr/bin/local/

RUN mkdir -p /go/app

WORKDIR /go/app

COPY . /go/app

RUN hugo -D

FROM nginx:1.21-alpine

COPY --from=builder /go/app/public /usr/share/nginx/html
