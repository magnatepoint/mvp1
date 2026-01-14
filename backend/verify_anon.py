import jwt
import base64

anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ3YWd0aWtweGJoanJmZm9scnFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3ODE0NDksImV4cCI6MjA3NDM1NzQ0OX0.cYevGkIj1HkjKv7iC14TgR7ItGF6YnXJi5Qw6ONYmcQ"
secret = "F0xPm1pBCc2mJNjoOaC6+8yEN2J/XTMbIYc8RFx8RVPcGSlY2GR/crEyzPO64corMVNCgToYQRlDQ6uQ4mXWFQ=="

print("--- Testing Anon Key with raw secret ---")
try:
    decoded = jwt.decode(anon_key, secret, algorithms=["HS256"], options={"verify_aud": False})
    print("Success with raw string!")
except Exception as e:
    print(f"Failed with raw string: {e}")

print("\n--- Testing Anon Key with decoded base64 secret ---")
try:
    decoded_secret = base64.b64decode(secret)
    decoded = jwt.decode(anon_key, decoded_secret, algorithms=["HS256"], options={"verify_aud": False})
    print("Success with decoded base64!")
except Exception as e:
    print(f"Failed with decoded base64: {e}")
