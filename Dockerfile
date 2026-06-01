FROM python:3.12-slim

WORKDIR /app

COPY AI-VocabGen-main/Back-End/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY AI-VocabGen-main/Back-End/ .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
