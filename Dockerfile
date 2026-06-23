FROM python:3.12-slim AS builder

# Cài Rust + build web-server
RUN apt-get update && apt-get install -y curl build-essential pkg-config libssl-dev
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app
COPY . .

# Build release web-server
RUN cargo build --release -p web-server

# Final stage (nhẹ)
FROM python:3.12-slim

WORKDIR /app

# Copy binary từ builder
COPY --from=builder /app/target/release/web-server /usr/local/bin/web-server

# Copy Python wrapper
COPY wrapper.py .

# Cài thêm nếu Python cần gì (ví dụ requests, flask...)
RUN pip install --no-cache-dir fastapi uvicorn  # hoặc cái gì bạn cần

EXPOSE 3000

# Chạy Python wrapper
CMD ["python", "wrapper.py"]
