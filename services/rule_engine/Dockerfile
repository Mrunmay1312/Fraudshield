FROM golang:1.20-alpine AS build
WORKDIR /src
COPY . .
RUN go build -o rule_engine main.go
FROM alpine:3.18
COPY --from=build /src/rule_engine /usr/local/bin/rule_engine
EXPOSE 8080
CMD ["/usr/local/bin/rule_engine"]