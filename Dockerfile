# === Builder stage ===
FROM rust:1.85-slim AS builder

# Cài thêm dependencies
RUN apt-get update && apt-get install -y \
    pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Cài nightly toolchain đúng phiên bản
RUN rustup toolchain install nightly-2024-12-15 --component rust-src
RUN rustup default nightly-2024-12-15

WORKDIR /app
COPY . .

# Build release web-server
RUN cargo build --release -p web-server

# === Final stage (nhẹ) ===
FROM python:3.12-slim

WORKDIR /app

# Copy binary từ builder
COPY --from=builder /app/target/release/web-server /usr/local/bin/web-server

# Copy Python wrapper
COPY wrapper.py .

# Cài Python packages nếu cần
RUN pip install --no-cache-dir fastapi uvicorn

EXPOSE 3000

CMD ["python", "wrapper.py"]
