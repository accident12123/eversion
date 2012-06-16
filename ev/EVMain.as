// Eversion, the flash interface for YAMJ on the Syabas Embedded Players
// Copyright (C) 2012  Bryan Socha, aka Accident

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import ev.Common;
import ev.Screen;
import ev.EVSettings;
import ev.Eskinload;
import ev.Background;
import api.RemoteControl;
import api.Popapi;
import api.Duneapi;
import tools.Preloader;
import tools.StringUtil;
import mx.utils.Delegate;
import mx.xpath.XPathAPI;

class ev.EVMain {
	private var fn:Object = null;
	private var setup:EVSettings=null;
	private var eskin:Eskinload=null;
	private var nextScreen:Screen=null;

	private var parentMC:MovieClip = null;
	private var mainMC:MovieClip = null;

	public function cleanup():Void {
		RemoteControl.stopFullRemote();
		this.nextScreen.cleanup();
		Background.reset();
		Common.reset();

		delete this.fn;
		this.fn=null;

		this.parentMC = null;
		this.mainMC.removeMovieClip();
		this.mainMC = null;
	}

	public function create(parentMC:MovieClip):Void {
		// setup
		this.cleanup();

		this.fn = {	settingsDone:Delegate.create(this, this.settingsDone),
					skinsettingsDone:Delegate.create(this, this.skinsettingsDone),
					skinloadDone:Delegate.create(this, this.skinloadDone),
					screenDone:Delegate.create(this, this.screenDone)
        	};

		this.parentMC = parentMC;
		RemoteControl.setupRemote(this.fn.screenDone);
		Preloader.init(parentMC);

		trace("READY");

		// start it up
		this.startEV();
	}

	private function startEV() {
		this.load_splash();
		this.mainMC.message_txt.text="Initializing..";

		// reset
		Common.enviroment(this.parentMC);

		// load settings
		this.setup=new EVSettings({ev:true,url:Common.evRun.rootpath+"/eversion/settings/",userfile:"esettings",prefix:""},this.mainMC,this.fn.settingsDone);
	}

	private function load_splash() {
		// load up the splash
		this.mainMC = this.parentMC.attachMovie("splashMC", "splashMC", this.parentMC.getNextHighestDepth(), {_x:0, _y:0});
		trace("parentmc next depth check: "+this.parentMC.getNextHighestDepth());
		this.mainMC.background_img.htmlText="<img align='center' vspace='0' hspace='0' src='eversion/images/splash.png'/>";
	}

	private function clear_splash() {
		this.mainMC._visible=false;
		this.mainMC.removeMovieClip();
		this.mainMC=null;
	}

	private function settingsDone(status, message) {
		trace("back from settings");

		if(status!="ERROR") {
			// validate/adjust esettings
			this.setup.validateSettings();
			this.setup=null;

			this.eskin=new Eskinload(this.mainMC,this.fn.skinloadDone);
			this.eskin.first_load();
		} else {
			trace("error "+message);
			this.mainMC.message_txt.text="ERROR: "+message;
		}
	}

	private function skinloadDone(loaded:Boolean) {
		trace("back from skin load");

		if(loaded==true) {
			trace("loaded, ready to load settings");
			this.setup=new EVSettings({ev:false,url:Common.evSettings.eskinrootpath+Common.evSettings.eskin+"/",userfile:"settings",prefix:Common.evSettings.eskin.toUpperCase()+": "},this.mainMC,this.fn.skinsettingsDone);
		} else {
			trace("failed to load");
		}
	}

	private function skinsettingsDone(status, message) {
		trace("back from eskin settings");

		if(status!="ERROR") {
			// validate skin settings
			this.setup.validateSkin();
			this.setup=null;

			// and we're off
			this.startskin();
		} else {
			trace("error "+message);
			this.mainMC.message_txt.text="ERROR: "+message;
		}
	}

	private function startskin() {
		trace("ready to roll");
		this.mainMC.message_txt.text="Starting up.";

		// render quality
		if(Common.evSettings.renderquality!="OFF") {
			this.parentMC._quality=Common.evSettings.renderquality;
			trace(".. parent mc quality "+this.parentMC._quality);
		} else {
			trace(".. quality adjustment disabled");
		}

		// prepare eject button
		this.do_exit(true);

		// start up ev!
		Background.init();

		this.nextScreen=new Screen(this.parentMC, this.fn.screenDone, {kind:"MASTER"});
	}

	private function screenDone(status:String, message:String) {
		trace("main screenDone status "+status+" message "+message);

		switch(status) {
			case 'HIDE':
				trace(".. ev is running, cleaning splash");
				this.clear_splash();
				break;
			case 'ERROR':
				trace(".. ERROR ERROR "+message);
				this.load_splash();
				this.mainMC.message_txt.text="ERROR: "+message;
				var errorMC:MovieClip = this.parentMC.attachMovie("fatalMC", "fatalMC", this.parentMC.getNextHighestDepth(), {_x:100, _y:100});
				errorMC.message_txt.text=message;
				RemoteControl.stopAllRemote();
				Preloader.clear();
				Popapi.systemled("on");
				break;
			case 'RESET':
				trace("... resetting!!!");
				this.mainMC.message_txt.text="RESETTING";
				this.create(this.parentMC);
				break;
			case 'EXIT':
				trace("MAIN: user exiting");
				this.do_exit(false);
				break;
			default:
				trace(".. don't know what to do");
				break;
		}
	}

	private function do_exit(skipexit:Boolean):Void
	{
		if(skipexit==undefined) skipexit=false;

		if(skipexit==true) {
			if(!Common.evRun.hardware.pcheject) {
				trace("eject button handling skipped, popbox player");
				return;
			}
			trace("exitpage prep for eject button");
		}
		trace("EXIT REQUESTED, user set: "+Common.evSettings.exitpage);

		// if dune, exit
		Duneapi.exit();

		switch(Common.evSettings.exitpage) {
			case 'apps':
				if(skipexit==true) break;     // unsupported eject button delayed function
				trace("launching apps");
				Popapi.launcher();
				break;
			case 'eject':
				if(skipexit==true) break;     // unsupported eject button delayed function
				if(!Common.evRun.hardware.loadpage) {
					trace("eject switched to popbox exit");
					Popapi.launcher();
				} else {
					Popapi.presseject();
				}
				break;
            case 'popboxexit':
				if(skipexit==true) break;     // unsupported eject button delayed function
				trace("popbox exit");
				Popapi.launcher();
				break;
			case 'start':
				this.mainMC._visible=false;
				if(!Common.evRun.hardware.loadpage) {
					trace("eject switched to popbox exit");
					if(skipexit==false) Popapi.launcher();
				} else {
					Popapi.htmlexit("user", true);	   // where to go
					if(skipexit==false) Popapi.presseject(); // press eject for the user
				}
				break;
			default: // act like eject button
				if(StringUtil.beginsWith(Common.evSettings.exitpage, "phf://")) {
					if(skipexit==true) break;     // unsupported eject button delayed function
					trace('load_phf url');
					var newexit:String=Common.evSettings.exitpage.substr(6);
					newexit="file://"+newexit;
					trace("new exit command: "+newexit);
					Popapi.phfexit(newexit);	   // where to go
				} else if(StringUtil.beginsWith(Common.evSettings.exitpage, "file://") || StringUtil.beginsWith(Common.evSettings.exitpage, "http://")) {
					if(!Common.evRun.hardware.loadpage) Popapi.launcher();
					trace("gaya url");
					Popapi.htmlexit(Common.evSettings.exitpage, true);	   // where to go
					if(skipexit==false) Popapi.presseject(); // press eject for the user
				} else {
					if(skipexit==true) break;     // unsupported eject button delayed function
					trace("unknown exitpage, sending eject");
					if(!Common.evRun.hardware.pcheject) {
						Popapi.launcher();
					} else {
						Popapi.presseject(); // press eject for the user
					}
				}
				break;
		}
	}
}