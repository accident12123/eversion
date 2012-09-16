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
import ev.Eskinrun;
import ev.Dex;
import ev.miniDex;
import ev.Background;
import api.Popapi;
import api.RemoteControl;
import api.Mediaplayer;
import tools.StringUtil;
import tools.Preloader;
import ev.Loadimage;
import mx.utils.Delegate;
import mx.xpath.XPathAPI;

class ev.Screen {
	private var callback:Function=null;
	private var fn:Object = null;

	private var parentMC:MovieClip = null;
	private var mainMC:MovieClip = null;
	private var auxdata:Object=null;
	private var eskinmaster:String=null;
	private var eskin:String=null;
	private var skinfile:String=null;

	private var isMaster:Boolean=null;
	private var isSkipped:Boolean=null;
	private var nextScreen:Screen;
	private var errorScreen:Screen;

	private var segments:Array=null;
	private var preloadseg:Object=null;
	private var segmentremote:Number=null;
	private var minidexnum:Number=null;

	private var currentEskin:Eskinrun=null;
	private var mycount:Number=null;

	private var alertInterval=null;

// ************************** INIT ************************************

	public function Screen(parentMC:MovieClip, callback:Function, auxdata:Object) {
		this.cleanup();

		this.fn = {	onScreenReturn:Delegate.create(this, this.onScreenReturn),
					segmentreturn:Delegate.create(this, this.segmentreturn),
					erunreturn:Delegate.create(this, this.erunreturn),
					globalKeyHit:Delegate.create(this, this.globalKeyHit),
					get_auxdata:Delegate.create(this, this.get_auxdata),
					playerdone:Delegate.create(this, this.playerdone),
					screen_hide:Delegate.create(this, this.screen_hide),
					alert_check:Delegate.create(this, this.alert_check)
        	};

		this.callback=callback;
		this.parentMC = parentMC;

		this.auxdata=auxdata;

		trace("screen init");
		trace(". kind: "+this.auxdata.kind);
		trace(". eskin: "+this.auxdata.eskin);
		trace(". file: "+this.auxdata.file);
		trace(". title: "+this.auxdata.title);

		if(this.auxdata.xml == undefined) {
			trace(". xml: false");
		} else {
			trace(". xml: true");
		}

		if(this.auxdata.tvset == undefined) {
			trace(". tvsetxml: false");
		} else {
			trace(". tvsetxml: true");
		}

		// figure out the root eskin
		this.eskinmaster=Common.evSettings.eskin;

		// prep the screen
		this.mycount=Common.count;
		Common.count++;
		this.mainMC=this.parentMC.createEmptyMovieClip("mainMC"+this.mycount, this.parentMC.getNextHighestDepth());
		Preloader.swap(this.mainMC);
		this.currentEskin=new Eskinrun(this.mainMC,this.fn.erunreturn);

		RemoteControl.stopAllRemote();

		if(this.auxdata.kind=="MASTER") {
			trace("We're master");
			this.isMaster=true;

			var temp=Common.esSettings.startpage.toLowerCase();
			if(temp != "home" && temp!=null && temp !=undefined) {
				trace("startpage not home, jumping over home to index");
				this.isSkipped=true;
				trace("!! home");
				this.mainMC._visible=false;
			}

			// figure out the home
			switch(Common.eskinmaster[this.eskinmaster].settings.starttype) {
				case 'home':
					trace("home screen");
					trace(".. eskin: "+Common.esSettings.menuHOME);
					this.eskin=Common.esSettings.menuHOME;
					this.eskinstart("HOME");
					break;
				default:
					this.isSkipped=false; // not a home based eskin
					trace("unknown starttype");
					this.callback("ERROR", "Unknown starttype "+Common.eskinmaster.settings.starttype);
					break;
			}
		} else {
			trace("We're not master");
			this.isMaster=false;

			this.eskinstart(this.auxdata.kind);
		}
	}

// *************************** eskin start ****************************
	private function eskinstart(kind:String) {
		trace("eskinstart for "+kind);
		switch(kind) {
			case "HOME":
				this.eskin=Common.esSettings.menuHOME;
				this.currentEskin.skin_start(Common.esSettings.menuHOME);
				break;
			case "DETAIL":
				this.eskindetail();
				break;
			case "INDEX":
			case "PRELOAD":
				Preloader.update("Loading data");
				this.eskinindex();
				break;
			case "EXTRA":
			case "SCREEN":
				this.eskinblank();
				break;
			case 'ERROR':
			case 'POPUP':
			case 'VERPOPUP':
			case 'MPART':
				this.system_screen();
				break;
			default:
				trace("unknown screen type "+kind);
				this.callback("ERROR",Common.evPrompts.eunknownscreen+" "+kind);
				return;
		}
	}

	private function eskinfullscreen(skinfile:String) {
		this.skinfile=skinfile.toLowerCase();
		if(Common.eskinmaster[this.eskinmaster][this.skinfile].control.fullscreen!=false) {
			trace("fullscreen is true, hiding former");
			this.callback("HIDE");
		} else {
			trace("fullscreen is false, leaving previous screen on");
		}
	}

	private function system_screen() {
		trace("system screen load "+this.auxdata.kind);

		switch(this.auxdata.kind) {
			case 'ERROR':
				this.splitskinfix(Common.esSettings.systemERROR);
				break;
			case 'POPUP':
				this.splitskinfix(Common.esSettings.systemINFO);
				break;
			case 'VERPOPUP':
				this.splitskinfix(Common.esSettings.systemMULTIINFO);
				break;
			case 'MPART':
				this.splitskinfix(Common.esSettings.systemMPART);
				break;
			default:
				trace("..  don't know what to do");
				this.callback("ERROR", Common.evPrompts.eunknownscreen+" "+this.auxdata.kind);
				return;
		}

		// eskinstart
		this.currentEskin.skin_start(this.eskin, this.fn.get_auxdata);
	}

	private function splitskinfix(filename:String) {
		if(filename.indexOf(":") != -1)	{
			trace("skinsplit");
			var splitted:Array=filename.split(":");
			this.eskinmaster=splitted[0];
			this.eskin=splitted[1];

			trace(".. master: "+this.eskinmaster);
			trace(".. eskin: "+this.eskin);

			// update eskinrun for master
			this.currentEskin.updateMaster(this.eskinmaster);

		} else {
			this.eskin=filename;
		}
	}

	private function eskindetail() {
		// setup minidex
		this.auxdata.minidexname="minidex";
		var segnum=this.add_mini_segment(this.auxdata);

		// figure out type & eskin file
		var mtype=this.segments[segnum].base.get_data("mtype");
		trace("details is "+mtype);

		this.eskin=Common.esSettings["details"+mtype];

		this.segments[0].base.alert("UPDATE",null,null,{eskin:this.eskinmaster,eskinfile:this.eskin});

		// start the eskin
		this.currentEskin.skin_start(this.eskin, this.segments[segnum].cbs.getevdata, this.segments[segnum].cbs.getdata);
		//trace("after eskinrun: "+this.auxdata.xml);
	}

	private function eskinblank() {
		if(this.auxdata.xml != undefined && this.auxdata.xml !=null) {
			trace("... extra, starting up minidex");
			// setup minidex
			this.auxdata.minidexname="minidex";
			var segnum=this.add_mini_segment(this.auxdata);
		} else trace("... blank, starting up eskin");

		this.eskin=this.auxdata.eskin;
		trace("eskin to load "+this.eskin);

		if(this.auxdata.xml != undefined && this.auxdata.xml !=null) {
			this.segments[0].base.alert("UPDATE",null,null,{eskin:this.eskinmaster,eskinfile:this.eskin});
		}

		// start the eskin
		if(this.auxdata.xml != undefined && this.auxdata.xml !=null) {
			this.currentEskin.skin_start(this.eskin, this.segments[segnum].cbs.getevdata, this.segments[segnum].cbs.getdata);
		} else {
			this.currentEskin.skin_start(this.eskin);
		}
	}

	private function eskinindex() {
		// prep segment info
		this.preloadseg=this.auxdata;

		// launch tempsegment (it'll signal back other steps)
		this.preloadseg.base = new Dex();
		this.preloadseg.base.create(this.mainMC, -1, this.preloadseg, this.fn.segmentreturn);
	}

	private function eskinindex_start(kind:String,get_data:Function) {

		trace("eskin starting for "+kind);

		if(kind==undefined && this.auxdata.kind=="PRELOAD") {
			trace(".. preload index");
			var eskintemp:String=this.auxdata.xml.file;
		} else {
			var eskintemp:String=Common.esSettings["index"+kind];
		}

		trace(".. temp "+eskintemp);

		if(eskintemp==undefined || eskintemp==null) {
			trace("unknown skin type, trying generic index");
			var eskintemp:String=Common.esSettings["indexINDEX"];
			trace(".. temp "+eskintemp);
		}

		if(eskintemp==undefined || eskintemp==null) {
			this.callback("ERROR", "Invalid eskin setting for "+kind);
			return;
		}

		// prep
		this.eskin=eskintemp;

		// people node support
		if(kind=="PEOPLE") {
			trace("checking for people data")
			var peopledata=get_data('peoplexml');
			if (peopledata!=null && peopledata!=undefined && peopledata!='') {
				trace("people index with person node, starting minidex");

				var auxdata=new Object();
				auxdata.xml=peopledata;
				auxdata.minidexname="minidex";
				var segnum=this.add_mini_segment(auxdata);
				this.currentEskin.skin_start(this.eskin, get_data, this.segments[segnum].cbs.getdata);
				return;
			}
		}

		// start the eskin
		this.currentEskin.skin_start(this.eskin, get_data);
	}


// *************************** RETURN *********************************
	private function onScreenReturn(request:String, message:String, returndata:Object) {
		trace("onScreenReturn signaled "+request);

		switch(request) {
			case 'EXIT':  // user is exiting
			case 'RESET':
				this.callback(request);
				break;
			case 'ERROR':  // problem
				this.do_error_message(message);
				break;
			case 'HIDE':   // next screen wants us to clear
				trace("!! hide");
				this.mainMC._visible=false;
				this.screen_hide();
				break;
			case 'PLAYHIDE':   // next screen wants us to clear
				trace("!! hide");
				this.mainMC._visible=false;
				this.screen_hide(true);
				break;
			case 'HOME':   // user requested home screen
				if(this.isMaster==false) {
					trace(".. we're not home, moving back");
					this.callback("HOME",message,returndata);
					return;
				} else {
					trace(".. we're the home!");
					this.return_cleanup();					// clean last screen
					this.screen_wake();
					Common.evRun.popupactive=false;
				}
				break;
			case 'BACK':   // user returned to this screen
				if(this.isMaster==false && (returndata.data != undefined && returndata.data!=null) && returndata.data!="index" && int(returndata.data) != 1) {
					var newdata=int(returndata.data)-1;
					trace("back going "+newdata);
					this.callback("BACK",message,{data:newdata.toString()});
				} else {
					if(returndata.data=="index" && this.isMaster==false) {
						trace("back looking for index");
						if(this.auxdata.kind!="INDEX") {
							trace("not index, still going back");
							this.callback("BACK",message,returndata);
							return;
						}
					}
					trace("back in "+this.mycount);
					this.return_cleanup();					// clean last screen
					this.screen_wake();
					Common.evRun.popupactive=false;
				}
				break;
			case 'jumpto':  // direct index jump
				if(this.isMaster==false) {
					trace(".. we're not home, moving back");
					this.callback("jumpto", message);
					return;
				} else {
					trace(".. we're the home! starting index");
					Common.evRun.popupactive=false;
					var tscreen=this.nextScreen;
					//this.nextScreen.cleanup();
					this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, {kind:"INDEX",file:message});
					tscreen.cleanup();
					//this.mainMC._visible=false;
				}
				break;
			case 'eskinjump':
				if(this.isMaster==false) {
					trace(".. we're not home, moving back");
					this.callback("eskinjump", message, returndata);
					return;
				} else {
					trace(".. we're the home! starting eskin");
					Common.evRun.popupactive=false;
					var tscreen=this.nextScreen;
					//this.nextScreen.cleanup();
					this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, returndata);
					if(tscreen!=null) {
						tscreen.cleanup();
						delete tscreen;
						tscreen=null;
					}
					//this.mainMC._visible=false;
				}
				break;
			case 'PLAYWAKE':
				this.play_wake();
				break;
			default:
				break;
		}
	}

	private function erunreturn(request:String, message:String, data:Object) {
		trace("eskinrun signaled "+request+" message "+message);

		switch(request) {
			case 'ADDSEG':
				return(this.add_segment(data));
				break;
			case 'SEGLAUNCH':
				this.segments[data.segnum].mcname=data.mcname;
				this.segments[data.segnum].mcdepth=data.mcdepth;
				this.seg_launch(data.segnum);
				break;
			case 'LOADED':
				this.eskinfullscreen(this.eskin);
				if(this.isSkipped!=true) {
					if(Common.eskinmaster[this.eskinmaster][this.skinfile].control.passthrough!=undefined) {
						if(this.auxdata.kind !="SCREEN") this.mainMC._visible=true;
						var passdata=this.auxdata;
						passdata.eskin=Common.eskinmaster[this.eskinmaster][this.skinfile].control.passthrough;
						trace("PASSTHROUGH to "+Common.eskinmaster[this.eskinmaster][this.skinfile].control.passthrough);
						if(this.auxdata.kind=="DETAIL") this.auxdata.kind="EXTRA";
						//trace("kind "+this.auxdata.kind);
						//passdata.file=undefined;
						this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, passdata);
					} else {
						this.remote_screen();
						Preloader.clear();
					}
				} else {
					this.mainMC._visible=false;  // not sure why it's on here
				}
				break;
			case 'ACTIVATE':
				if(this.isSkipped!=true) {
					this.remote_segment();
				}
				break;
			case 'ERROR':
				this.check_error_message(message);
				break;
			default:
				trace("!&!&!&! unknown");
				break;
		}
	}

	private function segmentreturn(request:String, message:String, data:Object, keyhit) {
		trace("segment return "+request+" message: "+message);

		switch(request) {
			case 'GLOBALKEY':  // used keys from segments
				this.globalKeyHit(keyhit);
				break;
			case 'PRELOAD': // preload signaling of type
				this.eskinindex_start(message,data.get_data);
				break;
			case 'apps':  // apps
				Popapi.launcher();
				break;
			case 'exit':  // exitpage
				this.callback("EXIT");
				break;
			case 'change': // changing screens
				// launch next screen
				trace("CHANGE: "+data.ddata);
				if(this.auxdata.tvset!=undefined) {
					trace(".. added tvsetxml to data");
					data.tvset=this.auxdata.tvset;
				}
				this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, data);
				this.segments_alert("IDLE");  // idle segments
				break;
			case 'ONLINE':
				if(this.isSkipped==true) {
					this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, {kind:"INDEX",file:Common.esSettings.startpage});
				} else {
					this.remote_segment();
				}
				break;
			case 'REMOTEKEY':
				this.process_remote(message, data);
				break;
			case 'PLAY':
				this.start_playback(data);
				break;
			case 'ERROR':
				this.check_error_message(message);
				break;
			default:
				trace(".. unknown request");
		}
	}

// ************************** SEGMENTS ********************************
	private function add_mini_segment(data:Object) {
		trace("adding minisegment "+data.minidexname);

		if(this.segments==null) this.segments=new Array();

		var segnum=this.segments.length;
		trace(".. number "+segnum);

		this.segments[segnum]=data;
		this.segments[segnum].base = new miniDex();
		trace("------------- current eskin: "+typeof(this.currentEskin) + " val "+this.currentEskin);
		this.segments[segnum].erun=this.currentEskin;
		var cbs:Object=this.segments[segnum].base.create(this.mainMC, segnum, this.segments[segnum], this.fn.segmentreturn);
		this.segments[segnum].cbs=cbs;
		this.minidexnum=segnum;

		return(segnum);
	}

	private function add_segment(data:Object) {
		trace("SCREEN: adding segment "+Common.eskinmaster[data.eskin][data.file].segments[data.member].name);

		if(this.segments==null) this.segments=new Array();

		var segnum=this.segments.length;
		trace(".. number "+segnum);

		this.segments[segnum]=data;
		this.segments[segnum].erun=this.currentEskin;
		if(this.auxdata.xml!=null) {
			this.segments[segnum].xml=this.auxdata.xml;
		}

		if(this.auxdata.tvset!=null && this.auxdata.tvset!=undefined) {
			this.segments[segnum].tvset=this.auxdata.tvset;
		}

		if(this.auxdata.aux!=null && this.auxdata.aux!=undefined) {
			this.segments[segnum].aux=this.auxdata.aux;
		}
		if(this.auxdata.popup!=null) {
			this.segments[segnum].popup=this.auxdata.popup;
		}
		// who has remote
		this.segmentremote=segnum;

		// figure out type.
		if(Common.eskinmaster[data.eskin][data.file].segments[data.member].name=="index") {
			trace(".. preloaded index segment");
			this.segments[segnum].base=this.preloadseg.base;
			this.segments[segnum].segnum=segnum;
			return(segnum);
		} else {
			trace(".. control/post load segment");
			this.segments[segnum].base = new Dex();
			this.segments[segnum].base.create(this.mainMC, segnum, this.segments[segnum],this.fn.segmentreturn);
			return(segnum);
		}
	}

	private function seg_launch(segnum:Number) {
		if(this.segments[segnum].segnum!=undefined) {
			trace("updating segment");
			this.segments[segnum].base.alert("UPDATE",null,null,this.segments[segnum]);
		} else if(this.segments[segnum].base.delaystart==true) {
			this.segments[segnum].base.alert("START");
		}
	}

	private function segments_alert(action:String) {
		if(this.segments==null) return;
		if(this.segments.length<1) return;

		for(var i=0;i<this.segments.length;i++) {
			// close it
			trace(action+"ing: "+i);
			this.segments[i].base.alert(action);
		}
	}

	private function segments_close() {
		if(this.segments==null) return;
		if(this.segments.length<1) return;

		for(var i=0;i<this.segments.length;i++) {
			// close it
			trace("closeing: "+i);
			this.segments[i].base.cleanup();
		}
	}

// ************************ global remote *****************************
	private function globalKeyHit(keyhit) {
		//trace("screen remote keycode "+keyhit);

		// buttons
		var handler=this.segment_remote_check(Common.eskinmaster[this.eskinmaster][this.skinfile].remote[keyhit]);
		if(handler != undefined) {
			trace("** SCREEN KEY HIT! "+keyhit);
			return(this.process_remote(handler.action,handler));
		}
/*
		if(Common.eskinmaster[this.eskinmaster][this.skinfile].remote[keyhit] != undefined) {
			trace("** SCREEN KEY HIT! "+keyhit);
			this.process_remote(Common.eskinmaster[this.eskinmaster][this.skinfile].remote[keyhit].action, Common.eskinmaster[this.eskinmaster][this.skinfile].remote[keyhit]);
			return(true);
		}
	*/
	//this.currentEskin.skin_start(this.eskin, this.segments[segnum].cbs.getevdata, this.segments[segnum].cbs.getdata);

		// keypad
		if(Common.eskinmaster[this.eskinmaster][this.skinfile].settings.remotekeypad != undefined) {
			if(keyhit>47 && keyhit<58) {
				trace("** KEYPAD HIT! "+keyhit);
				this.process_remote(Common.eskinmaster[this.eskinmaster][this.skinfile].settings.remotekeypad.action, Common.eskinmaster[this.eskinmaster][this.skinfile].settings.remotekeypad);
				return(true);
			}
		}

		// all
		if(Common.eskinmaster[this.eskinmaster][this.skinfile].settings.remoteall != undefined) {
			trace("** ALL HIT! "+keyhit);
			this.process_remote(Common.eskinmaster[this.eskinmaster][this.skinfile].settings.remoteall.action, Common.eskinmaster[this.eskinmaster][this.skinfile].settings.remoteall);
			return(true);
		}

		//trace("screen2 remote keycode "+keyhit);
		switch(keyhit)
		{
			case (Key.HOME):
				if(this.isMaster!=true) {
					this.callback("HOME");
				}
				return(true);
			case (187):			// = key used for comp debuggin
				//trace("error test activated");
				//this.do_error_message("error message testing");
				//break;
			case (Key.MENU):
				this.do_user_button("menu");
				break;
			case (Key.BACK):
			case (16777238):
				trace("back key");
				if(this.isMaster==false) {
					trace(".. ok to go back");
					this.callback("BACK");
				} else {
					trace(".. we're at home, no back");
				}
				return(true);
			case (Key.RED):
				this.do_user_button(Common.evSettings.red);
				return(true);
			case (Key.YELLOW):
				this.do_user_button(Common.evSettings.yellow);
				return(true);
			case (Key.GREEN):
				this.do_user_button(Common.evSettings.green);
				return(true);
			case (Key.BLUE):
				this.do_user_button(Common.evSettings.blue);
				return(true);
			case (268436490): // search button
				this.do_user_button(Common.evSettings.search);
			    return(true);
			default:
				for(var tt in RemoteControl.remotemapname) {
					//trace("checking "+tt);
					if(keyhit==RemoteControl.remotemapname[tt]) {
						//trace("match with "+tt);
						if(Common.evSettings["button"+tt] != undefined) {
							trace("user defined button"+tt);
							this.do_user_button(Common.evSettings["button"+tt]);
							return(true);
						}
					}
				}
		}
		return(false);
	}


	private function segment_remote_check(against) {
		if(against == undefined) return(undefined);

		for(var i=0;i<against.length;i++) {
			if(against[i].condition==undefined) {
				trace(".. no remote condition, using this one");
				return(against[i]);
			} else trace(".. remote condition skipped, screen remote");
		}
		return(undefined);
	}

	private function do_user_button(command:String) {
		trace("user button for "+command);
		this.do_switch({data:command});

		// this routine left as a passthrough for now just in case.
	}

// ************************** COMMON **********************************

	private function screen_hide(playhide:Boolean) {
		trace("!! screenhide for "+this.mycount);
		this.mainMC._visible=false;				// hide screen
		this.segments_alert("UNLOAD"); 			// unload segments
		this.currentEskin.skin_memory_clear();  // unload eskin

		// hide the previous if we're not fullscreen
		if(playhide==true && Common.eskinmaster[this.eskinmaster][this.skinfile].control.fullscreen==false) {
			this.callback("PLAYHIDE");
		}
	}

	private function play_wake() {
		this.screen_show();

		if(Common.eskinmaster[this.eskinmaster][this.skinfile].control.fullscreen==false) {
			this.callback("PLAYWAKE");
		}
	}

	private function screen_wake() {
		this.screen_show();
		this.remote_take();
	}

	private function screen_show() {
		this.isSkipped=false;
		this.mainMC._visible=true;				// show the screen again
		this.segments_alert("WAKE");			// restart segments
		if(this.minidexnum!= null) {
			var wakevars={get_data:this.segments[this.minidexnum].cbs.getdata,get_ev_data:this.segments[this.minidexnum].cbs.getevdata};
		} else {
			//var wakevars={get_data:this.segments[this.segmentremote].cbs.getdata,get_ev_data:this.segments[this.segmentremote].cbs.getevdata};
			var wakevars=null;
		}
		var dataarray=new Array();
		this.currentEskin.skin_redraw(wakevars);		// redraw skin ui
	}

	private function remote_take() {
		if(this.nextScreen==null && this.errorScreen==null) {
			Preloader.clear();
			RemoteControl.stopAllRemote();
			this.remote_segment();
			this.remote_screen();
		} else trace("cannot retake remote, we are not top screen");
	}

	private function remote_screen() {
		if(this.nextScreen==null && this.errorScreen==null) {
			Preloader.clear();
			RemoteControl.startRemote("screen",this.fn.globalKeyHit);
			if(this.alertInterval==null) {
				trace("========================= starting alert check");
				this.alertInterval = setInterval(this.fn.alert_check,2000);
			}
		} else trace("cannot retake remote, we are not top screen");
	}

	private function remote_segment() {
		if(this.nextScreen==null && this.errorScreen==null) {
			if(this.segmentremote!=null) this.segments[this.segmentremote].base.alert("CONTROL");
			if(this.minidexnum!=null) this.segments[this.minidexnum].base.alert("CONTROL");
		} else trace("cannot retake remote, we are not top screen");
	}

// ************************** REMOTE HANDLER **************************
	private function process_remote(command:String, data:Object) {
		trace("processing remote control command "+command);

		//if(data.xml==undefined && this.auxdata.xml != undefined) data.xml=this.auxdata.xml;

		switch(command) {
			case 'BLOCK':  			// block the remote key
				break;
			case 'CLEARYUPDATE':
				Background.verjb=false;
				data.action="BACK";
				command="BACK";
				// break left out, back should be below this.
			case 'HOME':            // commands that move back at least 1 screen when not master
			case 'BACK':
				if(this.isMaster!=true) {
					this.callback(command,null,data);
				}
				break;
			case 'RESET':            // commands that move back at least 1 screen no matter what.
			case 'EXIT':
				this.callback(command,null,data);
				break;
			case 'EXTRA':           // new screen commands
				if(data.xml == undefined || data.xml == null) {
					if(data.raw == undefined) {
						trace("!!! no XML OR RAW data to start extra with");
						this.do_error_message(Common.evPrompts.esnoxtradata);
						return
					} else {
						data.xml=data.raw;
					}
					//trace("no data to start extra with");
					//this.do_error_message(Common.evPrompts.esnoxtradata);
					//return;
				}

				trace("extra, eskin to load "+data.file);
				if(data.file==undefined) {
					trace(".. cannot extra load");
					this.do_error_message(Common.evPrompts.esnoxtrafile);
					return;
				}
				data.file=this.currentEskin.process_variable(data.file,data.who,{get_data:data.getdata,get_ev_data:data.getevdata});
				this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, {kind:"EXTRA",eskin:data.file,xml:data.xml});
				break;
			case 'SCREEN':
				if(data.file==undefined) {
					if(data.keyinfo.file==undefined) {
						if(data.raw.file==undefined) {
							trace(".. cannot load");
						} else data.file=data.raw.file;
					} else data.file=data.keyinfo.file;
				}
				data.file=this.currentEskin.process_variable(data.file,data.who,{get_data:data.getdata,get_ev_data:data.getevdata});
				this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, {kind:"SCREEN",eskin:data.file});
				break;
			case 'PRELOAD':
				//trace("preload check check 1 2 3 "+data.title);
				this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, {kind:"PRELOAD",xml:data.raw});
				break;
			case 'SWITCH':			// EXTERNAL NAVIGATION
				this.do_switch(data);
				break;
			case 'APPS':
				trace("launching apps");
				Popapi.launcher();
				break;
			case 'PLAYFILE':
				this.do_playfile(data);
				break;
			case 'PLAYDISC':
			case 'PLAYROM':
				this.do_playrom();
				break;
			case 'PLAYALL':
			case 'PLAYPART':		// PLAY COMMANDS
			case 'PLAYLAST':
			case 'PLAYRANDOM':
			case 'PLAYSINGLE':
			case 'PLAYFROMHERE':
			case 'PLAYWATCHED':
			case 'PLAYNEW':
			case 'PLAYALLMULTI':
				this.do_player(command, data);
				break;
			default:
				trace("unknown action");
				break;
		}
	}

// ************************** EXTERNAL NAV ****************************
	private function do_switch(data:Object) {
		//trace("data.data: "+data.data);
		if(data.data==undefined) {
			if(data.raw.data!=undefined) {
				var command:String=data.raw.data;
			} else {
				var command:String=data.keyinfo.data;
			}
		} else {
			var command:String=data.data;
		}

		trace("SWITCHING PRE "+command);

		command=this.currentEskin.process_variable(command,data.who,{get_data:data.get_data,get_ev_data:data.getevdata});

		trace("SWITCHING POST "+command);

		switch(command) {
			case 'menu':
				trace("menu button pressed");
				if(Common.esSettings.menuMENU != undefined && Common.esSettings.menuMENU != null) {
					trace("..we have a menu screen to show!!");
					this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, {kind:"SCREEN",eskin:Common.esSettings.menuMENU});
				}
				break;
			case 'home':
				if(this.isMaster!=true) {
					this.callback("HOME");
				}
				break;
			case 'apps':
				trace("launching apps");
				Popapi.launcher();
				break;
			case 'eject':
            case 'popboxexit':
			case 'exit':
				// return to sender
				this.callback("EXIT");
				break;
			case 'start':
				if(Common.evRun.hardware.loadpage) {
					Popapi.htmlexit("user", true);	   // where to go
					Popapi.presseject(); // press eject for the user
				}
				break;
			default:
			    // act like eject button
				if(StringUtil.beginsWith(command, "phf://")) {
					trace('load_phf url');
					var newexit:String=command.substr(6);
					newexit="file://"+newexit;
					trace("new exit command: "+newexit);
					Popapi.phfexit(newexit);	   // where to go
				} else if(StringUtil.beginsWith(command, "file://") || StringUtil.beginsWith(command, "http://")) {
					if(Common.evRun.hardware.loadpage) {
						trace("gaya url");
						Popapi.htmlexit(command, true);
						Popapi.presseject(); // press eject for the user
					}
				} else if(StringUtil.beginsWith(command, "eskin://")) {
					trace("eskin filename");
					var neweskin:String=command.substr(8);
					//this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, {kind:"SCREEN",eskin:neweskin,data:data.raw.data});
					this.onScreenReturn("eskinjump", command, {kind:"SCREEN",eskin:neweskin,aux:data.raw});
				} else if(StringUtil.endsWith(command, "_1")) {  // JUMP TO INDEX
					trace("jump to "+command+" requested");
					this.onScreenReturn("jumpto", command);
				} else {
					trace(".. no clue where to switch too");
				}
				break;
		}
	}

// ************************** PLAYBACK ********************************

	private function do_playrom() {
		trace("playrom selected");

		Mediaplayer.playrom(this.parentMC, this.fn.playerdone);
	}

	private function do_playfile(data) {
		trace("playfile for "+data.raw.title);

		Mediaplayer.playfile(this.parentMC, this.fn.playerdone, data.raw);
	}

	private function do_player(what:String, data:Object) {
		var part=0;
		if(data.keyhit != undefined) {
			part=data.keyhit-48;
			if(part==0) part=10;
			trace("keypad play part "+part);
		}

		if(data.epraw!=null) {
			this.start_epplayback({playtype:what, raw:data.raw, epraw:data.epraw});
		} else {
			this.start_playback({playtype:what, part:part, xml:data.xml, raw:data.raw});
		}
	}

	private function start_epplayback(playinfo:Object) {
		trace("episodeplay "+playinfo.playtype+" requested");

		var part=playinfo.raw.playnum;
		trace("playnum: "+part);

		switch(playinfo.playtype) {
			case 'PLAYALL':
			case 'PLAYWATCHED':
			case 'PLAYNEW':
			case 'PLAYALLMULTI':
				Mediaplayer.addEP(playinfo.epraw, 0, 0, this.fn.playerdone, this.parentMC);
				break;
			case 'PLAYPART':
			case 'PLAYSINGLE':
				Mediaplayer.addEP(playinfo.epraw, part, part, this.fn.playerdone, this.parentMC);
				break;
			case 'PLAYFROMHERE':
				Mediaplayer.addEP(playinfo.epraw, part, 0, this.fn.playerdone, this.parentMC);
				break;
			case 'PLAYLAST':
				var last=playinfo.epraw.length-1;
				part=playinfo.epraw[last].playnum;
				Mediaplayer.addEP(playinfo.epraw, part, 0, this.fn.playerdone, this.parentMC);
				break;
			case 'PLAYRANDOM':
				var check=playinfo.epraw.length-1;
				var who=Math.round(Math.random()*check);
				part=playinfo.epraw[who].playnum;
				Mediaplayer.addEP(playinfo.epraw, part, part, this.fn.playerdone, this.parentMC);
				break;
			default:
				trace("I don't know this playtype");
				break;
		}
	}

	private function start_playback(playinfo:Object) {
		trace(playinfo.playtype+" playback requested");

		trace("playinfo part: "+playinfo.part+" episode: "+playinfo.raw.episode);
		var part=0;
		if(playinfo.part == 0 && playinfo.raw.episode != undefined) {
			part=playinfo.raw.episode;
		} else {
			part=playinfo.part;
		}

		if(playinfo.xml != undefined) {
			var playthis=playinfo.xml;
		} else {
			var playthis=playinfo.raw;
		}

		switch(playinfo.playtype) {
			case 'PLAYALL':
				if(Common.evSettings.playermultipick=='true') {
					var xmlNodeList:Array = XPathAPI.selectNodeList(playthis, "/movie/files/file");
					if(xmlNodeList.length > 1) {
						if(XPathAPI.selectSingleNode(playthis, "/movie").attributes.isSet.toString() != "true" && XPathAPI.selectSingleNode(playthis, "/movie").attributes.isTV.toString() != "true") {
							trace("multipart, user selected a menu");
							this.nextScreen=new Screen(this.parentMC, this.fn.onScreenReturn, {kind:"MPART",eskin:Common.esSettings.systemMPART,xml:playthis});
							break;
						} else trace("multipart menu skipped, it's a set");
					}
				}
				// no break on purpose
			case 'PLAYWATCHED':
			case 'PLAYNEW':
			case 'PLAYALLMULTI':
				Mediaplayer.addFromXML(playthis, 0, 0, this.fn.playerdone, this.parentMC);
				break;
			case 'PLAYPART':
			case 'PLAYSINGLE':
				Mediaplayer.addFromXML(playthis, part, part, this.fn.playerdone, this.parentMC);
				break;
			case 'PLAYFROMHERE':
				Mediaplayer.addFromXML(playthis, part, 0, this.fn.playerdone, this.parentMC);
				break;
			case 'PLAYLAST':
				var xmlNodeList:Array = XPathAPI.selectNodeList(playthis, "/movie/files/file");
				var check:Number = xmlNodeList.length;
				if(check==0) {
					trace("no videos to play");
					this.do_error_message(Common.esPrompts.enovideo);
					return;
				}
				trace('playing last video '+check);
				check--;
				part=int(XPathAPI.selectSingleNode(xmlNodeList[check], "/file").attributes.firstPart.toString());
				Mediaplayer.addFromXML(playthis, part, 0, this.fn.playerdone, this.parentMC);
				break;
			case 'PLAYRANDOM':
				var xmlNodeList:Array = XPathAPI.selectNodeList(playthis, "/movie/files/file");
				var check:Number = xmlNodeList.length;
				if(check==0) {
					trace("no videos to play");
					this.do_error_message(Common.esPrompts.enovideo);
					return;
				}
				check--;
				var who=Math.round(Math.random()*check);
				trace("random video pos: "+who);
				// find the part number
				part=int(XPathAPI.selectSingleNode(xmlNodeList[who], "/file").attributes.firstPart.toString());
				trace("random xml part number "+part);
				Mediaplayer.addFromXML(playthis, part, part, this.fn.playerdone, this.parentMC);
				break;
			default:
				trace("I don't know this playtype");
				break;
		}
	}

	private function playerdone(status:String, message:String) {
		trace("playerdone called with status "+status);

		switch(status) {
			case 'ERROR':
				trace('mp error recieved '+message);
				Preloader.clear();
				Popapi.systemled("off");
				this.screen_show();
				this.play_wake();
				Mediaplayer.resetQueue();
				Popapi.stopvideo();
				Popapi.screensaver("0");
				this.do_error_message(message);
				break;
			case 'PLAY':
				Preloader.clear();
				Loadimage.bgclear();
				Popapi.clear_pod_bg();
				RemoteControl.stopAllRemote();
				this.screen_hide(true);
				break;
			case 'DONE':
				//trace("TEST STOPPING");
				//break;
			default:
				Preloader.clear();
				Popapi.systemled("off");
				this.play_wake();
				this.screen_wake();
				Mediaplayer.resetQueue();
				break;
		}
	}

// *************************** AUX DATA ******************************
	private function get_auxdata(data:String) {
		//trace("get_auxdata for "+data+ " "+this.auxdata[data]);

		if(this.auxdata[data] != undefined) {
			return(this.auxdata[data]);
		} else {
			return(null);
		}
	}

	private function check_error_message(message:String) {
		if(this.auxdata.kind=="ERROR") {
			trace("ERROR IS ERRORING!!");

			var errorMC:MovieClip = this.parentMC.attachMovie("fatalMC", "fatalMC", this.parentMC.getNextHighestDepth(), {_x:100, _y:100});
			errorMC.message_txt.text=message;
			RemoteControl.stopAllRemote();
		} else {
			this.segments_alert("ERRORHALT");
			this.callback("ERROR",message);
		}
	}


	private function do_error_message(message:String) {
		this.start_popup("ERROR", "error", message, true);
	}

	private function start_popup(kind, title, message, iserror, data) {
		if(iserror==true) {
			if(Common.evRun.popupactive) {  // pull out the error block just in case it's an erroring popup
				this.errorScreen.cleanup();
				delete this.errorScreen;
				this.errorScreen=null;
				Common.evRun.popupactive=false;
			}

			if(this.errorScreen!=null) {
				trace("error already on the screen, aborting new error message");
				return;
			}
		} else {
			Common.evRun.popupactive=true;   // flag it a non-error popup
		}

		this.errorScreen=new Screen(this.parentMC, this.fn.onScreenReturn, {kind:kind,title:title,message:message,popup:data});
	}

// ************************** ALERTS *********************************
	private function alert_check() {
		// if nextscreen or errorscreen skip, we're not active
		if(this.mainMC._visible==false || this.nextScreen!=null || this.errorScreen!=null) return;

		// if a popup is already up, skip
		if(Common.evRun.popupactive==true) return;

		if(Background.verevbadupdate==true) {  // check beta2 upgraded wrong
			trace(".. beta2 upgrade alert detected");
			this.start_popup("POPUP", "badevupgrade", Common.evPrompts.ewarninga);
			Background.verevbadupdate=false;
		} else if(Background.verevupdated==true) { // config newer than phf
			trace(".. ev restart alert detected");
			this.start_popup("POPUP", "evupdatefinish", Common.evPrompts.restartev);
			Background.verevupdated=false;
		} else if(Background.verevbad==true) { // check eversion
			trace(".. ev version alert detected");
			this.start_popup("POPUP", "badevupdate", Common.evPrompts.ewarning);
			Background.verevbad=false;
		} else if(Background.veroldyamj==true) {  // check yamj version
			trace(".. yamj version alert detected");
			this.start_popup("POPUP", "oldyamj", Common.evPrompts.eyver+Common.evRun.minyamj+"+");
			Background.veroldyamj=false;
		} else if(Background.verjb==true) {  // check jbupdate
			trace(".. jb updated alert detected");
			if(Common.evSettings.autoreset=="true") {
				this.callback("RESET");
			} else {
				this.start_popup("VERPOPUP", "alert", Common.evPrompts.yupdate,false,"yupdate");
			}
			Background.verjb=false;
		}
	}


// *************************** CLEANUP ********************************
	private function return_cleanup() {
		Loadimage.bgclearall();

		// make sure we're not abandoning someone higher than us.
		if(this.nextScreen!=null) {
			trace("cleaning up next screen");
			this.nextScreen.cleanup();
			delete this.nextScreen;
			this.nextScreen=null;
		}

		if(this.errorScreen!=null) {
			trace("cleaning up error screen");
			this.errorScreen.cleanup();
			delete this.errorScreen;
			this.errorScreen=null;
		}
	}

	public function cleanup():Void {
		trace("cleanup start for "+this.mycount);
		this.return_cleanup();

		trace("cleanup for "+this.mycount);

		this.parentMC = null;
		this.mainMC.removeMovieClip();
		this.mainMC = null;

		this.currentEskin.cleanup();
		delete this.currentEskin;
		this.currentEskin=null;

		this.eskinmaster=null;
		this.skinfile=null;

		delete this.fn;
		this.fn=null;

		this.preloadseg.base.cleanup();
		delete this.preloadseg;
		this.preloadseg=null;

		this.segments_close();
		delete this.segments;
		this.segments=null;

		this.isMaster=null;
		this.isSkipped=null;

		delete this.auxdata;
		this.auxdata=null;

	    this.eskin=null;
		this.segmentremote=null;

		this.minidexnum=null;

		clearInterval(this.alertInterval);
		this.alertInterval=null;
	}
}