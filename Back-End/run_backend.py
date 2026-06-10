import sys

from pathlib import Path



BASE_DIR = Path(__file__).resolve().parent

sys.path.insert(0, str(BASE_DIR / ".python_packages"))

sys.path.insert(0, str(BASE_DIR))



import uvicorn





if __name__ == "__main__":

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000)

