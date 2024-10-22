FROM python:3.11

WORKDIR /opt/e2e

COPY ./e2e/requirements.txt .

RUN python -m pip install -r requirements.txt

COPY ./e2e/ .

ENTRYPOINT ["python", "-m", "unittest"]
