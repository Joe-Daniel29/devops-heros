FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app

# run as a non-root user
RUN useradd --create-home --uid 10001 appuser

COPY app/ ./app/

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

CMD ["python", "-m", "app.server"]
