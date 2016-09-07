package com.flashphoner.api2.media
{
	import com.flashphoner.Logger;
    import com.flashphoner.api2.Main;
	
	import flash.media.Camera;
	import flash.net.NetStream;

    import flash.media.Microphone;
    import flash.media.SoundCodec;
    import flash.media.SoundTransform;
    import flash.system.Capabilities;
	
	import flashx.textLayout.debug.assert;
	
	import mx.controls.Alert;
	import mx.controls.VideoDisplay;
	import mx.core.Application;

	/**
	 * Control class for local media devices
	 **/
	public class LocalMediaControl
	{
        //video
		private var display:VideoDisplay;
		private var cam:Camera;
		private var FPS:int = 15;
		private var KEEP_RATIO:Boolean = true;
		private var KEY_INT:int = 48;
		private var QUALITY:int = 80;
		private var MOTION_LEVEL:int = 2000;
		private var BANDWIDTH:int = 0;
		private var width:int = 320;
		private var height:int = 240;
		private var configuration:Object;

        //audio
        private var mic:Microphone;
        private var micIndex:int = -1;
        private var currentGain:int = -1;

		public function LocalMediaControl(display:VideoDisplay){
            this.display = display;
		}
		
		private function getIntConfigurationProperty(value:String, def: int):int{
			if (value != null){
				return int (value);
			}else{
				return def;
			}			 
		}
		
		private function getBooleanConfigurationProperty(value:String, def: Boolean):Boolean{
			if (value != null){
				return Boolean (value);
			}else{
				return def;
			}			 
		}
		
		/**
		 * Init width,height,fps and other parameters
		 **/ 
		public function init(constraints:Object):Boolean{
			if (constraints == null) {
				if (this.cam != null && this.mic != null) {
					return true;
				}
				constraints = {};
				constraints.video = {};
				constraints.audio = true;
			}
			if (constraints.hasOwnProperty("video") && constraints.video is Object) {
				var videoConstraints:Object = constraints.video;
				this.width = getIntConfigurationProperty(videoConstraints.width, this.width);
				this.height = getIntConfigurationProperty(videoConstraints.height, this.height);
				this.FPS = getIntConfigurationProperty(videoConstraints.frameRate, this.FPS);
				var cameraId:String = videoConstraints.deviceId;
				var cameraName:String = null;
				if (cameraId != null && Camera.names.length > int(cameraId)) {
					cameraName = Camera.names[int(cameraId)];
				}
				if (this.cam != null) {
					removeLocalMedia();
				}
				Logger.info("Init camera " + cameraId + ":" + cameraName + ", resolution " + this.width + "x" + this.height + ", fps " + this.FPS);
				this.cam = Camera.getCamera(cameraId);
				if (this.cam == null) {
					//failed to get camera
					Logger.info("Failed to get camera");
					return false;
				}
				//init
				this.cam.setMode(this.width,this.height,FPS,KEEP_RATIO);
				this.cam.setKeyFrameInterval(KEY_INT);
				this.cam.setQuality(BANDWIDTH,QUALITY);
				this.cam.setMotionLevel(0,this.MOTION_LEVEL);
			}

			if (constraints.hasOwnProperty("audio")) {
				var micId:int = -1;
				if (!(constraints.audio is Boolean)) {
					micId = getIntConfigurationProperty(constraints.audio.deviceId, -1);
				}
				this.mic = defineMicrophone(true, micId);
				if (this.mic == null) {
					Logger.info("Failed to get microphone");
					return false;
				}
				initMic(this.mic);
			}
			return true;
		}		
		
		private function supportedResolutions(camera:Camera, resolutions:String):void {					
			var resolutionsSplit:Array = resolutions.split(",");
			var flag:Boolean = true;
			for (var i:int=0;i<resolutionsSplit.length;i++){
				var res:String = resolutionsSplit[i];
				var resSplit:Array = res.split("x");
				var w:int = int(resSplit[0]);
				var h:int = int(resSplit[1]);
				camera.setMode(w,h,30,true);
				if ((w==camera.width)&&(h==camera.height)){
					Logger.info("Resolution is supported: "+w+"x"+h);
					if ((w<=this.width)&&(h<=this.height)&&flag){
						this.width=w;
						this.height=h;
						flag=false;
					}
				}else{
					Logger.info("Resolution is NOT supported: "+w+"x"+h+", used: "+camera.width+"x"+camera.height);
				}
			}
		}
		
		public function getCam():Camera {
			return cam; 			
		}
		
		public function setCamParams(bandwidth:int, quality:int):void {
			this.cam.setQuality(
				(bandwidth <= 0) ? this.BANDWIDTH : bandwidth, 
				(quality <= 0) ? this.QUALITY : quality);
			Logger.info("Set camera params, b="+cam.bandwidth+" ; q="+cam.quality);
		}

		public function attachStream(stream:NetStream, hasAudio:Boolean, hasVideo:Boolean):void{
            if (hasAudio) {
                stream.attachAudio(mic);
            }
            if (hasVideo) {
                stream.attachCamera(getCam());
            }
		}
		
		public function attachLocalMedia():void{
			display.attachCamera(getCam());
		}
		
		public function removeLocalMedia():void{
			display.attachCamera(null);
		}
		
		
		/**
		 * Change output format CIF/QCIF
		 **/
		public function changeFormat(width:int, height:int):void{
			Logger.info("change format "+width+"x"+height);			
			if ((width>0)&&(height>0)){
				getCam().setMode(width,height,FPS,KEEP_RATIO);
			}			
		}

		public function hasAccess():Boolean {
			if (mic != null && !mic.muted) {
				return true;
			}
			if (cam != null && !cam.muted) {
				return true;
			}
			return false;
		}

        public function hasAccessToAudio():Boolean{
            if (mic == null || mic.muted){
                return false;
            }
            return true;
        }
		
		public function hasAccessToVideo():Boolean{
			if (cam == null || cam.muted){
				return false;
			}
            return true;
		}		

  		/**
		 * change current camera to used Flashphoner
		 **/
		public function changeCamera(camera:Camera):void{
			Logger.info("changeCamera");
			camera.setMode(this.width,this.height,FPS,KEEP_RATIO);
			camera.setKeyFrameInterval(KEY_INT);
			camera.setQuality(BANDWIDTH,QUALITY);
			camera.setMotionLevel(0,this.MOTION_LEVEL);	
			this.cam = camera;			
		}

        private function defineMicrophone(useEnhanced:Boolean, index:int=-1):Microphone {
            Logger.info("getMicrophone "+index);
            if (useEnhanced){
                if (Main.getFlashPlayerMajorVersion() >= 11 || Capabilities.language.indexOf("en") >= 0){
                    this.micIndex = index;
                    return Microphone.getEnhancedMicrophone(index);
                }else{
                    Logger.warn("WARNING!!! Echo cancellation is turned off on your side (because your OS has no-english localization). Please use a headset to avoid echo for your interlocutor.");
                    this.micIndex = index;
                    return Microphone.getMicrophone(index);
                }
            }else{
                this.micIndex = index;
                return Microphone.getMicrophone(index);
            }
        }

        private function initMic(mic:Microphone, gain:int=50, loopback:Boolean=false):void{
            if (mic != null){
                changeCodec("pcma");

                if (gain != -1){
                    mic.gain = gain;
                }

                mic.soundTransform = new SoundTransform(1,0);
                mic.setLoopBack(loopback);
                mic.setSilenceLevel(0,3600000);
                mic.setUseEchoSuppression(true);
            }
        }

        private function changeCodec(name:String):void{
            Logger.info("changeCodec: "+name);
            if (name=="speex"){
                mic.codec = SoundCodec.SPEEX;
                mic.framesPerPacket = 1;
                mic.rate = 16;
                mic.encodeQuality = 6;
            }else if (name=="ulaw" || name=="pcmu" ){
                mic.codec = SoundCodec.PCMU;
                mic.framesPerPacket = 2;
                mic.rate = 8;
            }else if (name=="alaw" || name=="pcma" ){
                mic.codec = SoundCodec.PCMA;
                mic.framesPerPacket = 2;
                mic.rate = 8;
            }
        }

        public function getMicrophone():Microphone{
            return mic;
        }

		public function listMicrophones():Array{
			var list = [];
			var i = 0;
			for (i = 0; i < Microphone.names.length; i++) {
				var mic = {};
				mic.id = i;
				mic.label = Microphone.names[i];
				mic.type = "mic";
				list.push(mic);
			}
			return list;
		}

		public function listCameras():Array{
			var list = [];
			var i = 0;
			for (i = 0; i < Camera.names.length; i++) {
				var camera = {};
				camera.id = i;
				camera.label = Camera.names[i];
				camera.type = "camera";
				list.push(camera);
			}
			return list;
		}
    }
}
