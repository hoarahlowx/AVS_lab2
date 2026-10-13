FROM python:3.9-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-client curl iputils-ping \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY process_and_request.py /app/process_and_request.py

CMD ["sleep", "infinity"]
