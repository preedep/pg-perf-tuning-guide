# Build stage
FROM rust:alpine AS builder

RUN apk add --no-cache musl-dev openssl-dev openssl-libs-static pkgconfig

WORKDIR /app

COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY scripts ./scripts
COPY migrations ./migrations

RUN cargo build --release

# Runtime stage
FROM alpine:latest

RUN apk add --no-cache libgcc

WORKDIR /app

COPY --from=builder /app/target/release/pg-perf-tuning-guide /app/corebank-api
COPY --from=builder /app/target/release/seed-data /app/seed-data
COPY --from=builder /app/target/release/load-tester /app/load-tester
COPY --from=builder /app/migrations /app/migrations

ENV RUST_LOG=info

EXPOSE 8080

CMD ["/app/corebank-api"]
