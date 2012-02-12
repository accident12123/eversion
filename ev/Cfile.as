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
import api.Popapi;
import api.dataYAMJ;
import tools.Data;
import tools.StringUtil;
import tools.Preloader;
import mx.xpath.XPathAPI;
import mx.utils.Delegate;

class ev.Cfile {
	private var callback:Function=null;
	private var fn:Object = null;
	private var filename:String=null;
	private var postxml:XML=null;
	private var ydata:dataYAMJ=null;

	public function cleanup() {
		delete this.fn;
		this.fn=null;

		this.callback=null;
		this.filename=null;
		this.postxml=null;
	}

	public function staticdata(who:String, callback:Function) {
		trace("CF: static data for "+who);

		var data:Array=new Array();

		switch(who) {
			case 'yupdate':
				data.push({title:"Reset",action:"RESET"});
				data.push({title:"Ignore",action:"CLEARYUPDATE", data:"1"});
				data.push({title:"Home",action:"HOME"});
				break;
			default:
				callback("ERROR", Common.evPrompts.enodatain+" "+who);
				return;
		}

		callback(null, null, data);
	}


	public function indexdata(who:String, callback:Function) {
		trace("CF: index data for "+who);
		var what=who.toLowerCase();

		if(Common.indexes[what] != undefined) {
			trace("adding index data");
			callback(null, null, Common.indexes[what]);
		} else {
			trace("ERROR!");
			callback("ERROR", Common.evPrompts.enoload+" "+what);
		}
	}

	public function load(file:String, callback:Function) {
		this.cleanup();
		this.callback=callback;

		this.fn={cfloaded:Delegate.create(this, this.cfloaded),
				 insert_load:Delegate.create(this, this.insert_load)
				}

		this.filename=file+".control";
		trace("cf: starting control file load for "+this.filename);

		if(Common.eskincfile[this.filename].loaded!=true) {
			Preloader.update(Common.evPrompts.prepcat);
			Data.loadXML(this.filename, this.fn.cfloaded);
		} else {
			trace("already loaded");
			this.callback(null, null, Common.eskincfile[this.filename].code);
		}
	}

	private function cfloaded(success:Boolean, xml:XML) {
		if(success) {
			trace("cfile loaded");
			Common.eskincfile[this.filename]=new Object();
			Common.eskincfile[this.filename].menu=new Array();
			Common.eskincfile[this.filename].code=new Array();

			// process the code
			// loop the blocks
			var myXML = xml.firstChild.childNodes;
			trace(".. "+myXML.length+" blocks in the file");
			for (var i=0; i<myXML.length; i++) {
				var blockName=myXML[i].nodeName.toString().toLowerCase();
				trace(".. block: "+blockName);

				switch(blockName) {
					case 'item':
						if(!this.cf_item(myXML[i])) {
							continue;
						}
						break;
					case 'insert':
						//var dataValue=myXML[i].firstChild.nodeValue.toString();
						//if(!process_insert(dataValue)) {
						if(!do_insert(myXML[i])) {
							trace("cfile will reprocess after insert dataload");
							this.postxml=xml;
							delete Common.eskincfile[this.filename];
							return;
						}
						break;
					default:
						trace("...  UNKNOWN BLOCK!! ");
				}
			}

			trace("finished with file");
			Common.eskincfile[this.filename].loaded=true;
			Preloader.clear();
			this.callback(null, null, Common.eskincfile[this.filename].code);
		} else {
			trace("cfile failed");
			this.callback("ERROR", Common.evPrompts.enoload+" "+this.filename);
		}
	}

	private function do_insert(xml) {
		trace("checking insert");

		// see if anything is loaded yet
		if(Common.indexes==null || Common.indexes==undefined) {
			this.insert_loadcat();
			return(false);
		}

		// see what we're processing
		var data=Data.arrayXML(xml);

		data.info=data.info.toLowerCase();

		trace(".. inserting "+data.info);

		if(Common.indexes[data.info] == undefined) {
			switch(data.info) {
				case 'playrom':
					if(Common.evSettings.showrom=="true"||Common.evSettings.playrom=="true") Common.eskincfile[this.filename].code.push({name:"Play Disc",title:"Play Disc",originaltitle:"Play Disc",action:"PLAYROM"});
					return(true);
				default:
					trace(".. cannot insert, data not found");
					return(true);
			}
		}

		// process
		this.add_control_array(Common.indexes[data.info], data);
		return(true);
	}

	private function add_control_array(data:Array, control) {
		//trace("********************* aca: "+data.length);
		trace("custom action of "+control.action);
		for(var tt=0;tt<data.length;tt++) {
			var newdata=data[tt];
			if(newdata.originaltitle == undefined) newdata.originaltitle=newdata.title;
			if(control.action != undefined) {
				for (var prop in control) {
					trace(prop+": "+control[prop]+" added");
					newdata[prop]=control[prop];
				}
			}
			Common.eskincfile[this.filename].code.push(newdata);
		}
	}

	private function insert_loadcat() {
		trace(".. need to load categories first");

		this.ydata=new dataYAMJ();
		this.ydata.getCat(this.fn.insert_load);
	}

	private function insert_load(catData:Array,errormsg:String) {
		trace(".. back from cat load");

		if(errormsg==undefined || errormsg==null) {
			trace(".. success starting control processing again");
			this.cfloaded(true, this.postxml);
		} else {
			trace(".. error!! "+errormsg);
			this.callback("ERROR", errormsg);
		}
	}

	private function cf_item(xml:XML) {
		trace(".. processing item");

		var newxml:Array=Data.arrayXML(xml);
		if(newxml==null || newxml==undefined) {
			trace("unable to process xml");
			this.callback("ERROR", Common.evPrompts.eprobfile+" "+this.filename);
			return(false);
		}

		if(newxml.action != undefined) {
			newxml.action=newxml.action.toUpperCase();
			Common.eskincfile[this.filename].code.push(newxml);
		}
		return(true);
	}

	public function process_data(field:String,titledata,howmany:Number):String {
		return(titledata[field]);
	}
}