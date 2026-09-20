from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello():
    return """<!DOCTYPE html>
<html>
<head><title>Python Hello World</title></head>
<body>
  <h1>Hello World from Python + Docker!</h1>
</body>
</html>"""


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
