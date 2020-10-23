import yt_video_data as yt
import subprocess
import flask
from flask import jsonify,request,Flask
import yt_video_data
from datetime import datetime
import redis
import socket
import requests as pyreq

app = Flask(__name__)

CLOUD_REDIS_IP = '159.89.164.202'
CLOUD_REDIS_PASSWORD = 'mirrorpassword'
CLOUD_REDIS_PORT = 6380
CLOUD_REDIS_DB = 2

cloudRedisConn = redis.Redis(host=CLOUD_REDIS_IP, port=CLOUD_REDIS_PORT, password=CLOUD_REDIS_PASSWORD, db=CLOUD_REDIS_DB)
hostname = socket.gethostname()
WHITELIST_IPS = ["14.98.241.14","122.160.157.77","122.160.56.167"]
ROUTER_OFF_URL = "http://10.10.10.18:5000/off"


@app.route('/')
def server_check():
	print ("server is running")
	return "server is running"

@app.route('/yt',methods=['GET'])
def getVideoDetails():
	try:
		start_time = datetime.now()
		args = request.args
		vid = args.get('vid')
		print("VID:",vid,"time",str(datetime.now()))
		if type(vid)!=str:
			return jsonify({"Error": "vid should be string..."}), 413
		if not vid:
			return jsonify({"Error": "vid should not be null..."}), 412

		yurl = 'https://www.youtube.com/watch?v='+vid
		yobject = yt_video_data.YoutubeVideo(yurl)
		print("TIME TAKEN1: ",str(datetime.now()-start_time))

		if yobject.response=='Blocked':
			print("Youtube blocked the IP of this server",str(datetime.now()))
			
			pubip = findPublicIp()
			key = hostname+'?ytapi?'+str(pubip)
			cloudRedisConn.set(key,'Blocked',ex=120)
			if pubip not in WHITELIST_IPS and len(pubip.split('.'))==4:
				try:
					pyreq.get(ROUTER_OFF_URL,timeout=5)
				except pyreq.exceptions.Timeout as te:
					print("ROUTER REBOOTED",str(datetime.now()))
			return jsonify({"Error": "Youtube Blocked"}), 429

		try:
			vid = yobject.id
		except AttributeError as ae:
			print("AttributeError: ",ae)
			return jsonify({"Error": "Updating youtube-dl"}), 414

		data = {
			"vid":yobject.id,
			"videourl":yobject.videourl,
			"viewcount":yobject.view_count,
			"keywords":yobject.tags,
			"resolution":yobject.resolution,
			"duration":yobject.duration,
			"is_live":yobject.is_live,
			"category": yobject.categories,
			"description":yobject.description,
			"channelid":yobject.channel_id,
			"likecount":yobject.like_count,
			"dislikecount":yobject.dislike_count,
			"title":yobject.title,
			"upload_date":yobject.upload_date,
			"creator":yobject.creator,
			"age_limit":yobject.age_limit,
			"thumbnail":yobject.thumbnail,
			"rating":yobject.average_rating
		}
		print("TIME TAKEN: ",str(datetime.now()-start_time))

		return jsonify(data), 200
	except Exception as e:
		print("Error in API:",str(e),str(datetime.now()))
		return jsonify({"Error": "Code fat gaya."}), 500

def findPublicIp():
	try:
		pubip = ''
		data = pyreq.get('http://checkip.amazonaws.com')
		if data.status_code==200:
			content = data.content.decode('utf-8')
			if content:
				pubip = content.split('\n')[0]
		return pubip

	except Exception as e:
		print("Exception in findPublicIp: ",str(e),str(datetime.now()))
		return ''

app.run(debug=True, port=8081,host='0.0.0.0')
