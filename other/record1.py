import pyaudio
import wave
from datetime import datetime,date
import os, socket
import signal
import traceback
from subprocess import call, PIPE, STDOUT
import multiprocessing as mp
from multiprocessing.dummy import Pool as ThreadPool
import json, sys, httplib2, random, subprocess, signal, threading, Queue
from datetime import datetime, date, timedelta
from time import time, sleep
# FrameQueue = Queue.Queue(maxsize=200)
# OrbQueue = Queue.Queue(maxsize=200)
# ResultAPIQueue = Queue.Queue(maxsize=200)
def mainFunc():
    global recfile, WavQueue, subprocesses, systemInterupt,RecordingStatus,RecordingDuration,RecordingDirectory, stopEvent
    WavQueue = Queue.Queue(maxsize=200)
    subprocesses = [1]
    systemInterupt = False
    RecordingStatus = True
    RecordingDuration = 20.0
    RecordingDirectory  = '/home/sp/audioRecording/'
    stopEvent= threading.Event()
    
    try:
        d1 = threading.Thread(name='daemon', target=daemon)
        # d1.setDaemon(True)
        d1.start()
        d1.join(1.0)
        while True and RecordingStatus and not stopEvent.is_set():
            try:
                pool = ThreadPool(len(subprocesses))
                resultsMainThreads = pool.map(execSubprocess,subprocesses)
                pool.close()
                pool.join()
            except Exception as e:
                print 'Error in mainFunc=> ' , e
                exception_logger()
            '''tHour = datetime.now().hour
            tMinute = datetime.now().minute
            tSecond = datetime.now().second
            fileTime = ("%02d" % tHour)+("%02d" % tMinute)+("%02d" % tSecond)
            datedir = '/home/sp/audioRecording/'+str(date.today())
            if not os.path.isdir(datedir):
                os.makedirs(datedir)
            rec = Recorder(channels=2)
            Dir = datedir+'/'+fileTime
            # mp3Dir = datedir+'/'+fileTime+'.mp3'
            pool = ThreadPool(len(subprocesses))
            print '10'
            resultsMainThreads = pool.map(execSubprocess,subprocesses)
            pool.close()
            print '11'
            #Not setting timeout as I want the threads to work parallely but wait for all threads completion
            pool.join()
            print '12'
            with rec.open(Dir+'.wav', 'wb') as recfile:
                print 'here= ', Dir
                recfile.record(duration=60.0)
                WavQueue.put_nowait(Dir+'.wav')'''
                # cmd1 = 'ffmpeg -i '+Dir+'.wav'+' -vn -ar 44100 -ac 2 -ab 128k -f mp3 '+Dir+'.mp3'+' -y -loglevel error -nostdin'
                # rsl1 = subprocess.call(cmd1, shell=True)
                # try:
                #   if os.path.isfile(Dir+'.wav'):
                #       os.remove(Dir+'.wav')
                # except Exception as e:
                #   print 'error', e
                #   raise e
    except Exception as e:
        print 'Error in mainFunc 1',e
        # raise e
        exception_logger()
def execSubprocess(sub):
    print 'subprocess', sub;
    try:
        global WavQueue, systemInterupt,RecordingDuration,RecordingStatus, stopEvent
        if sub == 1:
            print 'systemInterupt', systemInterupt
            count =1;
            while systemInterupt == False and RecordingStatus and not stopEvent.is_set():
                try:
                    print 'WavQueue',WavQueue.qsize()
                    if WavQueue.empty():
                        print 'empty'
                        sleep(RecordingDuration)
                        # if count >=3:
                        #   RecordingStatus=False
                        # count+=1
                        return 0
                    else:
                        wavefile = WavQueue.get_nowait()
                        print 'wavefile', wavefile
                        if os.path.isfile(wavefile):
                            mp3file = wavefile.split('.')[0]+'.mp3'
                            cmd1 = 'ffmpeg -i '+wavefile+' -vn -ar 44100 -ac 2 -ab 128k -f mp3 '+mp3file+' -y -loglevel error -nostdin'
                            rsl1 = subprocess.call(cmd1, shell=True)
                            # os.remove(wavefile)
                            return 1
                        # if count >=3:
                        #   RecordingStatus=False
                        #   sys.exit(1)
                        count+=1
                except Exception as e:
                    print 'Error in execSubprocess=>1', e
                    # raise e
                    exception_logger()
    except Exception as e:
        print 'error in execSubprocess=>2', e
        # raise e
        exception_logger()
def daemon():
    global recfile, WavQueue, subprocesses, systemInterupt,RecordingStatus,RecordingDuration,RecordingDirectory, stopEvent
    try:
        count =1;
        while RecordingStatus and not stopEvent.is_set():
            tHour = datetime.now().hour
            tMinute = datetime.now().minute
            tSecond = datetime.now().second
            fileTime = ("%02d" % tHour)+("%02d" % tMinute)+("%02d" % tSecond)
            hostname = socket.gethostname()
            datedir = RecordingDirectory+str(date.today())
            if not os.path.isdir(datedir):
                os.makedirs(datedir)
            rec = Recorder(channels=2)
            Dir = datedir+'/'+ hostname + '_' + fileTime
            # mp3Dir = datedir+'/'+fileTime+'.mp3'
            print '12'
            with rec.open(Dir+'.wav', 'wb') as recfile:
                print 'here= ', Dir
                recfile.record(duration=RecordingDuration)
                WavQueue.put_nowait(Dir+'.wav')
            count += 1
            if count > 1:
                stopEvent.set()
    except Exception as e:
        print 'Error in Daemon ',e
        exception_logger()

def convertToMp3(dr):
    try:
        print dr
        for wavefile in os.listdir(dr):
            print wavefile
            tempAudioFile = dr+wavefile
            mp3file = tempAudioFile.split('.')[0]+'.mp3'
            if os.path.isfile(tempAudioFile):
                cmd1 = 'ffmpeg -i '+tempAudioFile+' -vn -ar 44100 -ac 2 -ab 128k -f mp3 '+mp3file+' -y -loglevel error -nostdin'
                rsl1 = subprocess.call(cmd1, shell=True)
        return 1
    except Exception as e:
        print 'error', e
        # raise e
        exception_logger()

class Recorder(object):
    '''A recorder class for recording audio to a WAV file.
    Records in mono by default.
    '''
    def __init__(self, channels=1, rate=44100, frames_per_buffer=1024):
        self.channels = channels
        self.rate = rate
        self.frames_per_buffer = frames_per_buffer
    def open(self, fname, mode='wb'):
        return RecordingFile(fname, mode, self.channels, self.rate,
                            self.frames_per_buffer)
class RecordingFile(object):
    def __init__(self, fname, mode, channels, 
                rate, frames_per_buffer):
        self.fname = fname
        self.mode = mode
        self.channels = channels
        self.rate = rate
        self.frames_per_buffer = frames_per_buffer
        self._pa = pyaudio.PyAudio()
        self.wavefile = self._prepare_file(self.fname, self.mode)
        self._stream = None
    def __enter__(self):
        return self
    def __exit__(self, exception, value, traceback):
        self.close()
    def record(self, duration):
        # Use a stream with no callback function in blocking mode
        self._stream = self._pa.open(format=pyaudio.paInt16,
                                        channels=self.channels,
                                        rate=self.rate,
                                        input=True,
                                        frames_per_buffer=self.frames_per_buffer)
        for _ in range(int(self.rate / self.frames_per_buffer * duration)):
            audio = self._stream.read(self.frames_per_buffer)
            self.wavefile.writeframes(audio)
        return None
    def start_recording(self):
        # Use a stream with a callback in non-blocking mode
        self._stream = self._pa.open(format=pyaudio.paInt16,
                                        channels=self.channels,
                                        rate=self.rate,
                                        input=True,
                                        frames_per_buffer=self.frames_per_buffer,
                                        stream_callback=self.get_callback())
        self._stream.start_stream()
        return self
    def stop_recording(self):
        self._stream.stop_stream()
        return self
    def get_callback(self):
        def callback(in_data, frame_count, time_info, status):
            self.wavefile.writeframes(in_data)
            return in_data, pyaudio.paContinue
        return callback

    def close(self):
        self._stream.close()
        self._pa.terminate()
        self.wavefile.close()
    def _prepare_file(self, fname, mode='wb'):
        wavefile = wave.open(fname, mode)
        wavefile.setnchannels(self.channels)
        wavefile.setsampwidth(self._pa.get_sample_size(pyaudio.paInt16))
        wavefile.setframerate(self.rate)
        return wavefile
def exception_logger():
    exception_log = traceback.format_exc().splitlines()
    exception_log.append(str(datetime.now()))
    print exception_log
    return exception_log
# def handler():
# signal.signal(signal.SIGINT, handler)
mainFunc()