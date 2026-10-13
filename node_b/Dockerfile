FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY ml_service.py /app/ml_service.py

EXPOSE 5000
CMD ["python", "/app/ml_service.py"]
