FROM python:3.12-slim

WORKDIR /srv/ai_service

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN python scripts/train_model.py

EXPOSE 5000
CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT:-5000} --workers 2 wsgi:app"]
