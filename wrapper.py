import subprocess
import os
import time
import sys

def main():
    print("🚀 Python wrapper starting Tovek web-server...")

    # Có thể thêm logic: check env, health check, proxy, auth, logging...

    cmd = ["/usr/local/bin/web-server"]

    # Forward port từ Render (Render inject $PORT)
    port = os.getenv("PORT", "3000")
    # Nếu web-server đọc env PORT thì tốt, còn không thì bạn cần sửa code Rust hoặc dùng --port flag nếu có

    try:
        # Chạy Rust server
        process = subprocess.Popen(
            cmd,
            stdout=sys.stdout,
            stderr=sys.stderr,
            env=os.environ.copy()
        )

        print(f"✅ Tovek web-server started on port {port}")
        # Giữ process chạy
        process.wait()

    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
