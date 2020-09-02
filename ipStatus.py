from datetime import datetime
from icmplib import ping
import time, pymongo 

mongoClient = pymongo.mongoClient("mongodb://localhost:27017")
db = mongoClient['ipStatus']
collection = db['IPs']


























