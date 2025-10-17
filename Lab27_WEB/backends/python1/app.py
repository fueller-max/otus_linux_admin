import time
import redis
from flask import Flask, render_template

app = Flask(__name__)

redis_host = '127.0.1.1'

cache = redis.Redis(host=redis_host, port=6379)

def get_hit_count():
    retries = 5
    while True:
        try:
            return cache.incr('hits')
        except redis.exceptions.ConnectionError as exc:
            if retries == 0:
                raise exc
            retries -= 1
            time.sleep(0.5)
            


@app.route('/')
def hello():
    count = get_hit_count()
    # Render the index.html template and pass the 'count' variable to it
    return render_template('index.html', count=count)    