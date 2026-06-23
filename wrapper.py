import subprocess
import os
import sys

def main():
    print("🚀 Python wrapper đang khởi động Tovek web-server...")

    cmd = ["/usr/local/bin/web-server"]

    # Render tự động inject biến $PORT
    port = os.getenv("PORT", "3000")
    print(f"🌐 Server sẽ chạy trên port: {port}")

    try:
        # Forward tất cả environment variables
        env = os.environ.copy()
        
        # Nếu web-server không tự đọc $PORT, bạn có thể pass argument (sửa sau nếu cần)
        # cmd.extend(["--port", port])

        process = subprocess.Popen(
            cmd,
            stdout=sys.stdout,
            stderr=sys.stderr,
            env=env
        )

        print("✅ Tovek web-server đã khởi động thành công!")
        process.wait()

    except Exception as e:
        print(f"❌ Lỗi khi chạy server: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
