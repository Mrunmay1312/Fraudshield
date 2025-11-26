FROM golang:1.21 AS build

WORKDIR /src

COPY go.mod ./
COPY main.go ./

# Download dependencies AND auto-generate a valid go.sum
RUN go mod tidy

# Then copy everything else (if more files exist)
COPY . .

RUN go build -o rule_engine main.go

FROM alpine:latest
WORKDIR /app

COPY --from=build /src/rule_engine .
EXPOSE 7000

CMD ["./rule_engine"]

