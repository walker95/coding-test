from flask import Flask
from flask_restful import Resource, Api
import os, time, json
app = Flask(__name__)
api = Api(app)
def modifyStat(infile):
            return "<Modified Dictionery/Graph>"

class Product(Resource):
    def get(self):
        return modifyStat(infile)

api.add_resource(Product, '/')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=True)

def upTime(seconds):
    seconds_in_day = 60 * 60 * 24
    seconds_in_hour = 60 * 60
    seconds_in_minute = 60
    days = seconds // seconds_in_day
    hours = (seconds - (days * seconds_in_day)) // seconds_in_hour
    minutes = (seconds - (days * seconds_in_day) - (hours * seconds_in_hour)) // seconds_in_minute
    return f"{days} days,{hours} hours,{minutes} minutes"

def get_size(bytes, suffix="B"):
    """Scale bytes to its proper format. e.g:
                                        1253656 => '1.20MB'
                                        1253656678 => '1.17GB'
                                        """
    factor = 1000
    for unit in ["", "K", "M", "G", "T", "P"]:
        if bytes < factor:
            return f"{bytes:.2f}{unit}{suffix}"
        bytes /= factor













