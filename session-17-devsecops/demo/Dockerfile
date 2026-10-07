# Base image: current python:3.12-slim (Debian 13 "trixie").
# The older pinned python:3.12.3-slim (Debian 12.5) failed the Trivy
# HIGH/CRITICAL gate (expat, krb5, glibc, openssl CVEs) - see MyReadme.md.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Run as an unprivileged user instead of root
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

USER appuser

EXPOSE 5001

CMD ["python", "app/app.py"]
