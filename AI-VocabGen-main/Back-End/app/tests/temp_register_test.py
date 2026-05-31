from fastapi.testclient import TestClient
from app.main import app
client = TestClient(app)
res = client.post('/register', json={'name':'testuser','email':'test@example.com','password':'secret'})
print(res.status_code)
print(res.text)
