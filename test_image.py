import base64
import requests

with open("test.jpg", "rb") as f:
    img = f.read()

payload = {
    "image": base64.b64encode(img).decode()
}

r = requests.post("http://127.0.0.1:5000/analyze", json=payload)
print(r.text)
