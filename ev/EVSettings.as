import ev.Common;
import api.Popapi;
import api.Duneapi;
import tools.Data;
import tools.StringUtil;
import mx.xpath.XPathAPI;
import mx.utils.Delegate;

class ev.EVSettings {
	private var fn:Object = null;
	private var activeMC:MovieClip = null;
	private var callBack:Function = null;
	private var loadprefix:String=null;
	private var savevars:Object=null;
	private var settings:Array=null;
	private var prompts:Array=null;

	// cleanup, called to clear everything in the class
	public function cleanup():Void {
		delete this.fn;
		this.fn=null;

		delete this.savevars;
		this.savevars=null;

		this.loadprefix=null;

		this.activeMC=null;
		this.callBack=null;
	}

	function EVSettings(savevars:Object,activeMC:MovieClip,callBack:Function) {
		this.cleanup();

		this.activeMC=activeMC;
		this.callBack=callBack;
		this.savevars=savevars;

		this.settings=new Array();
		this.prompts=new Array();

		this.fn = {	onUserSettings:Delegate.create(this, this.onUserSettings),
					onDefaultSettings:Delegate.create(this, this.onDefaultSettings),
					onENxml:Delegate.create(this, this.onENxml),
					onperxml:Delegate.create(this, this.onperxml),
					onMacLoaded:Delegate.create(this, this.onMacLoaded),
					onUSERxml:Delegate.create(this, this.onUSERxml),
					onDrivesLoaded:Delegate.create(this, this.onDrivesLoaded),
					onDetectPlayer:Delegate.create(this, this.onDetectPlayer)
			};

		this.activeMC.message_txt.text=this.savevars.prefix+"Loading Settings....";

		// start settings load
		Data.loadXML(this.savevars.url+this.savevars.userfile+".xml", this.fn.onUserSettings);
	}


	private function onUserSettings(success:Boolean, xml:XML) {
		if(success) {
			this.process_xmltoarray(xml, this.settings);
		}

		Data.loadXML(this.savevars.url+this.savevars.userfile+"-default.xml", this.fn.onDefaultSettings);
	}

	private function onDefaultSettings(success:Boolean, xml:XML) {
		if(success) {
			this.process_xmltoarray(xml, this.settings);
		}

		// check that its safe to continue
		if(this.settings.translation == undefined) {
			this.settings.translation="en.xml";
		}

		this.activeMC.message_txt.text=this.savevars.prefix+"Loading Translations....";

		if(this.savevars.ev==true) {
			trace("loading translations for ev");
			if(this.settings.translation=="en.xml") {
				// english
				Data.loadXML(this.savevars.url+"en.xml", this.fn.onENxml);
			} else {
				// non-english
				Data.loadXML(this.savevars.url+this.settings.translation, this.fn.onUSERxml);
			}
		} else {
			trace("loading translations for skin");
			if(Common.evSettings.translation==Common.eskinmaster[Common.evSettings.eskin].settings.info.lang) {
				Data.loadXML(this.savevars.url+Common.eskinmaster[Common.evSettings.eskin].settings.info.lang, this.fn.onENxml);
			} else {
				Data.loadXML(this.savevars.url+Common.evSettings.translation, this.fn.onUSERxml);
			}
		}
	}

	private function onUSERxml(success:Boolean, xml:XML) {
		if(success) {
			this.process_xmltoarray(xml, this.prompts);
		}

		if(this.savevars.ev==true) {
			Data.loadXML(this.savevars.url+"en.xml", this.fn.onENxml);
		} else {
			Data.loadXML(this.savevars.url+Common.eskinmaster.settings.info.lang, this.fn.onENxml);
		}
	}

	private function onENxml(success:Boolean, xml:XML) {
		if(success) {
			this.process_xmltoarray(xml, this.prompts);
		}

		this.activeMC.message_txt.text=this.savevars.prefix+"Loading custom hardware settings...";

		if(Common.evRun.hardware.id==undefined) {
			// get the mac address of the player
			Popapi.uniqueid(this.fn.onMacLoaded);
		} else {
			// have the mac, just get the custom settings
			Data.loadXML(this.savevars.url+Common.evRun.hardware.id+".xml", this.fn.onperxml);
		}
	}

	// when pch mac address finished loading
	private function onMacLoaded(success:Boolean, xml, errorcode) {
		if(success) {
			Data.loadXML(this.savevars.url+Common.evRun.hardware.id+'.xml', this.fn.onperxml);
		} else {
			if(this.settings.bypassapi!="true") {
				this.activeMC.message_txt.text="Hardware not responding";
				this.callBack("ERROR","Hardware not responding (MAC) "+errorcode);
			} else {
				// syabas api is disabled if hits here
				Popapi.disabled=true;

				var ds=Duneapi.macaddress();

				if(ds != undefined) {
					trace("DUNE PLAYER!");
					Common.evRun.hardware.id=ds.toString();
					Data.loadXML(this.savevars.url+Common.evRun.hardware.id+'.xml', this.fn.onperxml);
				} else {
					Duneapi.disabled=true;
					trace("dune api disabled");
					Common.evRun.hardware.id="APIDISABLED";
					this.finished();
				}
			}
		}
	}

	private function onperxml(success:Boolean, xml:XML) {
		if(success) {
			this.process_xmltoarray_force(xml, this.settings);
		}

		// done if syabas api is closed
		if (Duneapi.disabled==false) {
			Duneapi.setup();
			this.finished();
		}

		// get drives and player type if not skin settings
		if(this.savevars.prefix=="") {
			this.activeMC.message_txt.text="Detecting player...";
			Popapi.model(this.fn.onDetectPlayer);
		} else {
			this.finished();
		}
	}

	private function onDrivesLoaded(success:Boolean, xml:XML, errorcode) {
	//	if(success) {
			// FINISHED.. TIME TO RETURN.
			this.finished();
	//    } else {
	//		this.activeMC.message_txt.text="Hardware not responding";
	//		this.callBack("ERROR","Hardware not responding (player detect) "+errorcode);
	//	}
	}

	private function onDetectPlayer(success:Boolean, xml:XML,errorcode) {
		if(success) {
			trace("detected player model"+Common.evRun.hardware.modelname);

			this.activeMC.message_txt.text="Updating drive list...";
			Popapi.drives(this.fn.onDrivesLoaded);
		} else {
			if(this.settings.bypassapi!="true") {
				this.activeMC.message_txt.text="Hardware not responding";
				this.callBack("ERROR","Hardware not responding (player detect) "+errorcode);
			} else {
				Popapi.disabled=true;
				this.finished();
			}
		}
	}

	private function finished() {
		if(this.savevars.ev==true) {
			trace("done with evsettings");

			Common.evSettings=this.settings;
			Common.evPrompts=this.prompts;
		} else {
			trace("done with skinsettings");

			Common.esSettings=this.settings;
			Common.esPrompts=this.prompts;
		}

		this.callBack();
	}

	private function process_xmltoarray(xml:XML, saveData:Array):Void {
		trace('processing started');

		// loop through the xml
		var myXML = xml.firstChild.childNodes;
		//trace(myXML.length+" entries in the file");
		for (var i=0; i<myXML.length; i++) {
			//trace(myXML[i]);
			//trace(myXML[i].firstChild);
			var dataName=myXML[i].nodeName.toString();
			var dataValue=myXML[i].firstChild.nodeValue.toString();
			//trace(dataName+" value "+dataValue);
			if(saveData[dataName] == undefined) {
				saveData[dataName]=dataValue;
				//trace("...added");
			} //else trace("...skipped");
		}
	}

	private function process_xmltoarray_force(xml:XML, saveData:Array):Void {
		trace('processing started');

		// loop through the xml
		var myXML = xml.firstChild.childNodes;
		//trace(myXML.length+" entries in the file");
		for (var i=0; i<myXML.length; i++) {
			//trace(myXML[i]);
			//trace(myXML[i].firstChild);
			var dataName=myXML[i].nodeName.toString();
			var dataValue=myXML[i].firstChild.nodeValue.toString();
			//trace(dataName+" value "+dataValue);
			saveData[dataName]=dataValue;
			//trace("...added");
		}
	}

	public function validateSettings() {
		trace("adjust defaults/loaded");

		// exit and buttons
		if(Common.evSettings.exitpage == undefined) Common.evSettings.exitpage='eject';
		if(Common.evSettings.blue == undefined) Common.evSettings.blue='apps';
		if(Common.evSettings.green == undefined) Common.evSettings.green='start';
		if(Common.evSettings.red == undefined) Common.evSettings.red='start';
		if(Common.evSettings.yellow == undefined) Common.evSettings.yellow='start';
		if(Common.evSettings.search == undefined) Common.evSettings.search='menu';

        // legacy, might still be needed
        Common.evRun.bghighres=false;

		switch(Common.evSettings.youtubequality) {
			case 'small':
			case 'large':
			case 'hd720':
			case 'hd1080':
				break;
			default:
				Common.evSettings.youtubequality="medium";
		}

		// quality
		Common.evSettings.renderquality=Common.evSettings.renderquality.toUpperCase();
		switch(Common.evSettings.renderquality) {
			case 'LOW':
			case 'MEDIUM':
			case 'HIGH':
				break;
			default:
				Common.evSettings.renderquality="OFF";
				break;
		}
		trace("quality set to "+Common.evSettings.renderquality);

		if(Common.evSettings.yamjdatapath==null || Common.evSettings.yamjdatapath==undefined) Common.evSettings.yamjdatapath="";

		// convert some to ints
		Common.evSettings.dataprefetch=int(Common.evSettings.dataprefetch);
		Common.evSettings.datatotal=int(Common.evSettings.datatotal);

		Common.evSettings.hyperscrolltimer=int(Common.evSettings.hyperscrolltimer);
		if(Common.evSettings.hyperscrolltimer==undefined || Common.evSettings.hyperscrolltimer < 100) {
			Common.evSettings.hyperscrolltimer=100;
		}
		Common.evSettings.hyperscrolldraw=int(Common.evSettings.hyperscrolldraw);
		if(Common.evSettings.hyperscrolldraw < 1) Common.evSettings.hyperscrolldraw=2;
		if(Common.evSettings.hyperscrolldraw > 6) Common.evSettings.hyperscrolldraw=2;
		Common.evSettings.hyperscrollredraw=int(Common.evSettings.hyperscrollredraw);
		if(Common.evSettings.hyperscrollredraw < 1) Common.evSettings.hyperscrollredraw=3;
		if(Common.evSettings.hyperscrollredraw > 6) Common.evSettings.hyperscrollredraw=3;
		Common.evSettings.hyperscrolldrawmode=Common.evSettings.hyperscrolldrawmode.toLowerCase();
		if(Common.evSettings.hyperscrolldrawmode!="nice" && Common.evSettings.hyperscrolldrawmode != "min" && Common.evSettings.hyperscrolldrawmode != "max") {
			Common.evSettings.hyperscrolldrawmode="nice";
		}
		Common.evSettings.hypercycles=int(Common.evSettings.hypercycles);
		if(Common.evSettings.hyercycles < 1 || Common.evSettings.hyercycles > 10) Common.evSettings.hyercycles=2;

		Common.evSettings.hypercycles=int(Common.evSettings.hypercycles);
		if(Common.evSettings.hypercycles < 1 || Common.evSettings.hypercycles > 10) Common.evSettings.hypercycles=2;

		Common.evSettings.hyperactivedraw=int(Common.evSettings.hyperactivedraw);
		if(Common.evSettings.hyperactivedraw < 5) Common.evSettings.hyperactivedraw=5;

		// version checking
		Common.evSettings.jbcheck=int(Common.evSettings.jbcheck);
		if(Common.evSettings.jbcheck==undefined || (Common.evSettings.jbcheck > 0 && Common.evSettings.jbcheck < 15)) {
			Common.evSettings.jbcheck=500; // check every 5 minutes is the default
		}
		trace("yamj ver check set to: "+Common.evSettings.jbcheck);

		Common.evSettings.playersingle=this.fixplayertype(Common.evSettings.playersingle);
		Common.evSettings.playeriso=this.fixplayertype(Common.evSettings.playeriso);
		Common.evSettings.playervideots=this.fixplayertype(Common.evSettings.playervideots);
		Common.evSettings.playerbdmv=this.fixplayertype(Common.evSettings.playerbdmv);
		Common.evSettings.playerflv=this.fixplayertype(Common.evSettings.playerflv);

		Common.evSettings.remotepgupdown=Common.evSettings.remotepgupdown.toLowerCase();

		Common.evSettings.playermonitorinterval=int(Common.evSettings.playermonitorinterval);
		if(Common.evSettings.playermonitorinterval < 500) Common.evSettings.playermonitorinterval=500;

		Common.evSettings.playermonitorstart=int(Common.evSettings.playermonitorstart);
		if(Common.evSettings.playermonitorstart < 100) Common.evSettings.playermonitorstart=100;

		Common.evSettings.playerforceexit=int(Common.evSettings.playerforceexit);

		if(Common.evSettings.eskin==undefined) Common.evSettings.eskin="evstreamed";

		Common.evSettings.preloadx=int(Common.evSettings.preloadx);
		if(Common.evSettings.preloadx<0 || Common.evSettings.preloadx>1280) Common.evSettings.preloadx=32;
		Common.evSettings.preloady=int(Common.evSettings.preloady);
		if(Common.evSettings.preloady<0 || Common.evSettings.preloady>1280) Common.evSettings.preloady=30;

		Common.evSettings.preloadstart=int(Common.evSettings.preloadstart);
		if(Common.evSettings.preloadstart < 100 && Common.evSettings.preloadstart!=0) Common.evSettings.preloadstart=100;

		Common.evSettings.preloadanimate=int(Common.evSettings.preloadanimate);
		if(Common.evSettings.preloadanimate < 500 && Common.evSettings.preloadanimate!=0) Common.evSettings.preloadanimate=500;

		if(Common.evSettings.overscan=="true") {
			Common.evSettings.overscanx=(100-Number(Common.evSettings.overscanx))/100;
			Common.evSettings.overscany=(100-Number(Common.evSettings.overscany))/100;
			Common.evSettings.overscanxshift=Number((1280-(1280*Common.evSettings.overscanx))/2);
			Common.evSettings.overscanyshift=Number((720-(720*Common.evSettings.overscany))/2);
		} else {
			Common.evSettings.overscanx=1;
			Common.evSettings.overscany=1;
			Common.evSettings.overscanxshift=0;
			Common.evSettings.overscanyshift=0;
		}

		trace("overscan:");
		trace(".. x: "+Common.evSettings.overscanx);
		trace(".. y: "+Common.evSettings.overscany);
		trace(".. xshift: "+Common.evSettings.overscanxshift);
		trace(".. yshify: "+Common.evSettings.overscanyshift);

		if(Common.evRun.hardware.sharesfrom=="api") {
			trace("non-gaya, forcing mounts on");
			Common.evSettings.playercheckmounts="true";
			Common.evSettings.mountnfstcpasnfs="true";
		}

		if(StringUtil.beginsWith(Common.evRun.rootpath,"http")) {
			trace("HTTP ROOT PATH DETECTED");

			if(Common.evSettings.yamjdatapath=="./") Common.evSettings.yamjdatapath=Common.evRun.rootpath+"/";
			if(Common.evSettings.eskinrootpath=="./") Common.evSettings.eskinrootpath=Common.evRun.rootpath+"/";
		}
		trace("yamjdatapath "+Common.evSettings.yamjdatapath);
		trace("eskinrootpath "+Common.evSettings.eskinrootpath);

		if(Common.evSettings.oversight=='true') {
			Common.overSight=true;
			trace("oversight enabled in settings");
		}

		if(Common.evSettings.fullmounts=='true' || Common.evSettings.fullmounts=='false' || Common.evSettings.fullmounts=='auto') {
			Common.evRun.hardware.cfgmounts=Common.evSettings.fullmounts;
        } else {
			Common.evRun.hardware.cfgmounts='auto';
		}
	}

	private function fixplayertype(setting:String):String {
		// make sure its uppercase
		setting=setting.toUpperCase();

		// make sure its valid or make it NATIVE
		switch(setting) {
			case 'SDK':
				if(!Common.evRun.hardware.isPCH) return("NATIVE");
			case 'NATIVE':
				return(setting);
			case 'YAMJ':	// legacy from EVB1
				if(!Common.evRun.hardware.isPCH) return("NATIVE");
				return('SDK');
			default:
				return("NATIVE");
		}
	}

	public function validateSkin() {
		trace("validating skin");

		// default views
		Common.esSettings.menuHOME=this.is_validate_view("home","menuHOME");
		Common.esSettings.menuMENU=this.is_validate_view("menu","menuMENU");
		Common.esSettings.indexTV=this.is_validate_view("index","indexTV");
		Common.esSettings.indexMOVIE=this.is_validate_view("index","indexMOVIE");
		Common.esSettings.indexTVSET=this.is_validate_view("index","indexTVSET");
		Common.esSettings.indexMOVIESET=this.is_validate_view("index","indexMOVIESET");
		Common.esSettings.indexINDEX=this.is_validate_view("index","indexINDEX");
		Common.esSettings.indexPEOPLE=this.is_validate_view("index","indexPEOPLE");
		Common.esSettings.detailsMOVIE=this.is_validate_view("movie","detailsMOVIE");
		Common.esSettings.detailsTV=this.is_validate_view("tv","detailsTV");
		Common.esSettings.systemERROR=this.is_validate_view("error","systemERROR","shared:error");
		Common.esSettings.systemINFO=this.is_validate_view("info","systemINFO","shared:error");
		Common.esSettings.systemMULTIINFO=this.is_validate_view("multiinfo","systemMULTIINFO","shared:multiinfo");
		Common.esSettings.systemMPART=this.is_validate_view("mpart","systemMPART","shared:mpart");

		//Common.esSettings.indexNEWTV=this.is_validate_view("index","indexNEWTV");
		//Common.esSettings.indexNEWMOVIE=this.is_validate_view("index","indexNEWMOVIE");

		if(Common.esSettings.indexNEWTV!=undefined) {
			Common.esSettings.indexNEWTV=this.is_validate_view("index","indexNEWTV");
		} else Common.esSettings.indexNEWTV=Common.esSettings.indexTV;

		if(Common.esSettings.indexNEWMOVIE!=undefined) {
			Common.esSettings.indexNEWMOVIE=this.is_validate_view("index","indexNEWMOVIE");
		} else Common.esSettings.indexNEWMOVIE=Common.esSettings.indexMOVIE;
	}

	private function is_validate_view(who:String,which:String,defaultpage:String) {
		trace(".. validating: "+who+"("+Common.eskinmaster[Common.evSettings.eskin].settings.screensvalid[who]+") / "+which+"("+Common.esSettings[which]+")");

		// make sure we can proceed
		if(Common.eskinmaster[Common.evSettings.eskin].settings.screensvalid[who] == undefined) {
			if(defaultpage!=undefined) {
				trace("... default: not part of the skin, using "+defaultpage);
				return(defaultpage);
			} else {
				trace("... skipped: not part of skin and no default");
				return(Common.esSettings[which]);
			}
		}

		// check it
		for(var i=0;i<Common.eskinmaster[Common.evSettings.eskin].settings.screensvalid[who].length;i++) {
			trace(".... checking: "+Common.eskinmaster[Common.evSettings.eskin].settings.screensvalid[who][i]);
			if(Common.eskinmaster[Common.evSettings.eskin].settings.screensvalid[who][i]==Common.esSettings[which]) {
				trace("..... MATCH");
				return(Common.esSettings[which]);
			}
		}

		// not valid, return the default
		trace("..... no match, using default of "+Common.eskinmaster[Common.evSettings.eskin].settings.screensvalid[who]);
		return(Common.eskinmaster[Common.evSettings.eskin].settings.screens[who]);
	}
}