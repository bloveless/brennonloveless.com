FROM golang:1.17.6 as builder

RUN go install github.com/gohugoio/hugo@v0.92.0

RUN mkdir -p /go/app

WORKDIR /go/app

COPY . /go/app

RUN hugo -D

FROM nginx:1.21

COPY --from=builder /go/app/public /usr/share/nginx/html
