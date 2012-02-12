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
import api.dataYAMJ;
import mx.utils.Delegate;
import mx.xpath.XPathAPI;
import api.RemoteControl;

class ev.miniDex {
	// global stuff
	private var fn:Object = null;
	private var callback:Function = null;
	private var mysegment:Number=null;
	private var segdetails:Object=null;
	private var skinBusy:Boolean=null;

	private var datasource=null;

// ******************** INIT **********************

	public function create(parentMC:MovieClip, mySegment:Number, segDetails:Object,callback:Function) {
		// reset our variables
		this.cleanup();

		this.fn = {onKeyDown:Delegate.create(this, this.onKeyDown),
				   get_ev_data:Delegate.create(this,this.get_ev_data),
				   get_data:Delegate.create(this,this.get_data),
				   get_current_data:Delegate.create(this,this.get_current_data)
		          };

		this.callback=callback;
		this.mysegment=mySegment;
		this.segdetails=segDetails;

		trace("miniDEX inited");

		// init remote data
		this.datasource=new dataYAMJ();

		// take over remote
		RemoteControl.startRemote("minidex",this.fn.onKeyDown);

		return({getdata:this.fn.get_data, getevdata:this.fn.get_ev_data});
	}

	public function cleanup():Void {
		delete this.fn;
		this.fn = null;

		this.callback = null;
		this.mysegment=null;

		delete this.segdetails;
		this.segdetails=null;

		this.datasource.cleanup();
		this.datasource=null;
	}

// ********************** COMMUNICATION *******************
    // info from screen
	public function alert(request:String, message:String, newparent:MovieClip, data:Object) {
		trace("alert request "+request);

		switch(request) {
			case 'IDLE':
				//Common.keyListener.onKeyDown = null;
				break;
			case 'UPDATE':
				this.segdetails.eskin=data.eskin;
				this.segdetails.file=data.eskinfile.toLowerCase();
				// no break on purpose
			case 'CONTROL':
				RemoteControl.startRemote("minidex",this.fn.onKeyDown);
				break;
			default:
				trace("unknown alert");
				break;
		}
	}

// *********************** ev int data *****************************
	private function get_ev_data(what:String) {
		trace("minidex get_ev_data for "+what);

		switch(what) {
			case 'indexname':
				return(this.datasource.process_data("title",this.segdetails.xml));
				break;
			default:
				trace(".. unknown");
		}
	}

	public function get_data(what:String, who:Number,howmany:Number) {
		//trace("minidex get_data request for "+what);
		//trace(this.segdetails.xml);
		return(this.datasource.process_data(what,this.segdetails.xml,howmany));
	}

	public function get_current_data(what:String,who:Number,howmany:Number) {
		trace("minidex get_current_data request for "+what);
		return(this.datasource.process_data(what,this.segdetails.xml,howmany));
	}


// *********************************** REMOTE *****************************
	private function onKeyDown(keyhit) {
		trace("minidex remote check");

		// buttons
		var handler=this.segment_remote_check(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].remote[keyhit]);
		if(handler != undefined) {
			// trace("** mdex KEY HIT! "+keyhit);
			return(this.handleremote(handler,keyhit));
		} else trace("not mdex button");

/*		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].remote[keyhit] != undefined) {
			//trace("** minidex KEY HIT! "+keyhit);
			return(this.handleremote(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].remote[keyhit]));
		}
*/
		// keypad
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].settings.remotekeypad != undefined) {
			if(keyhit>47 && keyhit<58) {
				//trace("** minidex KEYPAD HIT! "+keyhit);
				// redirect to minidex
				return(this.handleremote(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].settings.remotekeypad, keyhit));
			}
		} else trace("not minidex keypad");

		// all
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].settings.remoteall != undefined) {
			//trace("** minidex ALL HIT! "+keyhit);
			return(this.handleremote(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].settings.remoteall));
		}

		return(false);
	}

	private function segment_remote_check(against) {
		if(against == undefined) return(undefined);

		trace("segment remote");
		trace("against.length "+against.length);

		for(var i=0;i<against.length;i++) {
			trace("against[i].condition "+against[i].condition);
			if(against[i].condition==undefined) {
				trace(".. mdex no remote condition");
				return(against[i]);
			} else {
				trace(".. mdex remote condition "+against[i].condition);
				if(this.segdetails.erun.process_condition(against[i].condition, null, {get_data:this.fn.get_current_data,get_ev_data:this.fn.get_ev_data})) {
					trace("... mdex remote condition passed");
					return(against[i]);
				} else trace("... mdex condition failed");
			}
		}

		return(undefined);
	}

	private function handleremote(data:Object, keyhit) {
		//trace("minidex remote check for "+data.action+" keyhit:"+keyhit);
		switch(data.action) {
			case 'PLAYPART':		// these stay the same
			case 'PLAYLAST':
			case 'PLAYRANDOM':
				this.callback("REMOTEKEY",data.action,{keyinfo:data, keyhit:keyhit, raw:this.segdetails.xml, xml:this.segdetails.xml});
				return(true);
			case 'PLAYALL':			// these change to playall
			case 'PLAYSINGLE':
			case 'PLAYFROMHERE':
			case 'PLAYWATCHED':
			case 'PLAYNEW':
				this.callback("REMOTEKEY","PLAYALL",{keyinfo:data, raw:this.segdetails.xml, xml:this.segdetails.xml});
				return(true);
			case 'EXTRA':
				this.callback("REMOTEKEY",data.action,{keyinfo:data, file:data.file, data:data.data, raw:this.segdetails.xml, xml:this.segdetails.xml});
				return(true);
			default:
				this.callback("REMOTEKEY",data.action,data);
				return(true);
		}
	}
}