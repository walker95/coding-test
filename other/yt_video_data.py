
# -*- encoding: utf-8 -*-


import subprocess
from datetime import datetime
from importlib import reload
import sys
import youtube_dl

youtube_dl_errors = ['ContentTooShortError', 'DownloadError', 'ENGLISH_MONTH_NAMES', 'ExtractorError', 'GeoRestrictedError','RegexNotFoundError', 'UnavailableVideoError', 'UnsupportedError', 'XAttrMetadataError', 'XAttrUnavailableError','YoutubeDLError']



def updateYoutubeDl():
	try:
		updateYtdl = subprocess.call('pip install --upgrade youtube-dl', shell=True)
		return True
	except Exception as e:
		print("Exception in updateYoutubeDl: ",str(e),str(datetime.now()))
		return False


class YoutubeVideo:
	def __init__(self, url):
		self.url = url
		ydl = youtube_dl.YoutubeDL({'outtmpl': '%(id)s%(ext)s'})
		
		with ydl:
			try:
				result = ydl.extract_info(url,download=False)
				self.result = result
			except youtube_dl.utils.DownloadError as de:
				if 'Unable to extract video data' in str(de):
					self.result = 'Blocked'
				else:
					print("DownloadError: ",str(de),str(datetime.now()))
					updateYoutubeDl()
			except youtube_dl.utils.RegexNotFoundError as re:
				print("RegexNotFoundError: ",str(re),str(datetime.now()))
				if 'Too Many Requests' in str(de):
					self.result = 'Blocked'
				else:
					print("RegexNotFoundError: ",str(de),str(datetime.now()))
					updateYoutubeDl()

			except youtube_dl.utils.ExtractorError as ee:
				print("ExtractorError: ",str(ee),str(datetime.now()))

				if 'Too Many Requests' in str(de):
					self.result = 'Blocked'
				else:
					print("ExtractorError: ",str(de),str(datetime.now()))
					updateYoutubeDl()

			except youtube_dl.utils.UnsupportedError as ue:
				print("UnsupportedError: ",str(ue),str(datetime.now()))

				if 'Too Many Requests' in str(de):
					self.result = 'Blocked'
					return
				updateYoutubeDl()
			except youtube_dl.utils.YoutubeDLError as ye:
				print("YoutubeDLError: ",str(ye),str(datetime.now()))
				if 'Too Many Requests' in str(de):
					self.result = 'Blocked'
				else:
					print("YoutubeDLError: ",str(de),str(datetime.now()))
					updateYoutubeDl()
			except Exception as e:
				print("Exception",str(e),str(datetime.now()))
				return None

	@property
	def download(self):
		ydl_opts = {
		'format': 'bestvideo/best',
		'ext': 'mp4'
		}
		with youtube_dl.YoutubeDL(ydl_opts) as ydl:
			d = ydl.download([self.url])

	@property
	def videourl(self):
		# cmd = 'youtube-dl -F ' + self.url
		# A = subprocess.call(cmd, shell=True)
		# print(A)
		
		v = self.result.get('formats')
		for i in range(len(v)-1,-1,-1):
			print(v[i].get('format_id'),i)
			if v[i].get('format_id') == str(22):
				x = v[i].get('url')
				return x		
						

	@property
	def width(self):
		v = self.result.get('width', None)
		return v
			

	@property
	def view_count(self):
		v = self.result.get('view_count', None)
		return v

	@property  
	def like_count(self):
		v = self.result.get('like_count', None)
		return v

	@property
	def dislike_count(self):
		v = self.result.get('dislike_count', None)
		return v

	@property
	def channel_id(self):
		v = self.result.get('channel_id', None)
		return v

	@property
	def format(self):
		v = self.result.get('format', None)
		return v

	@property
	def description(self):
		v = self.result.get('description', None)
		# x = v.replace("'","''")
		# y = x.replace('"',"'")
		return v

	@property
	def title(self):
		v = self.result.get('title', None)
		return v

	@property
	def duration(self):
		v = self.result.get('duration', None)
		return v

	@property
	def id(self):
		v = self.result.get('id', None)
		return v

	@property
	def uploader_id(self):
		v = self.result.get('uploader_id', None)
		return v

	@property
	def upload_date(self):
		v = self.result.get('upload_date', None)
		return v

	@property
	def uploader_url(self):
		v = self.result.get('uploader_url', None)
		return v

	@property
	def channel_url(self):
		v = self.result.get('channel_url', None)
		return v

	@property
	def release_year(self):
		v = self.result.get('release_year', None)
		return v

	@property
	def start_time(self):
		v = self.result.get('start_time', None)
		return v

	@property
	def playlist_index(self):
		v = self.result.get('playlist_index', None)
		return v

	@property
	def stretched_ratio(self):
		v = self.result.get('stretched_ratio', None)
		return v

	@property
	def tags(self):
		v = self.result.get('tags', None)
		return v

	@property
	def release_date(self):
		v = self.result.get('release_date', None)
		return v

	@property
	def resolution(self):
		v = self.result.get('resolution', None)
		#self.view=v
		return v	


	@property
	def ext(self):
		v = self.result.get('ext', None)
		#self.view=v
		return v	


	@property
	def vbr(self):
		v = self.result.get('vbr', None)
		#self.view=v
		return v	


	@property
	def creator(self):
		v = self.result.get('creator', None)
		#self.view=v
		return v	


	@property
	def license(self):
		v = self.result.get('license', None)
		#self.view=v
		return v	

	@property
	def age_limit(self):
		v = self.result.get('age_limit', None)
		#self.view=v
		return v	

	@property
	def  is_live(self):
		v = self.result.get('is_live')
		#self.view=v
		return v	

	@property
	def  average_rating(self):
		v = self.result.get('average_rating', None)
		#self.view=v
		return v	

	@property
	def  album(self):
		v = self.result.get('album', None)
		#self.view=v
		return v	


	@property
	def  chapters(self):
		v = self.result.get('chapters', None)
		#self.view=v
		return v	
		

	@property
	def  alt_title(self):
		v = self.result.get('alt_title', None)
		#self.view=v
		return v	

	@property
	def  annotations(self):
		v = self.result.get('annotations', None)
		#self.view=v
		return v	

	@property
	def  season_number(self):
		v = self.result.get('season_number', None)
		#self.view=v
		return v		


	@property
	def  categories(self):
		v = self.result.get('categories', None)
		#self.view=v
		return v

	@property
	def  thumbnail(self):
		v = self.result.get('thumbnail', None)
		#self.view=v
		return v

	@property
	def best(self):
		v = self.result.get('best')
		return v

	@property
	def response(self):
		return self.result
	




