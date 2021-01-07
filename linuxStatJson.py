from flask import Flask
from flask_restful import Resource, Api
import os, time, json
cmd = 'statgrab -o > statgrab.txt'
infile = 'statgrab.txt'
outfile = 'statgrab.json'
statedict = {}
app = Flask(__name__)
api = Api(app)
def modifyStat(infile):
            exec = os.system(cmd)
            if exec == 0:
                if os.path.isfile(infile):
                    print(f"command executed and file {infile} created")
                    with open(infile) as inFile:
                        for line in inFile:
                            line = line.strip().split('=')
                            statedict[f"{line[0]}"] = f"{line[1]}"
            return statedict

class Product(Resource):
    def get(self):
        return modifyStat(infile)
    
        

api.add_resource(Product, '/')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=True)













