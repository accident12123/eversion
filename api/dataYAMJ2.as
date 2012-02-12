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
import ev.Background;
import tools.Data;
import tools.StringUtil;
import mx.xpath.XPathAPI;
import mx.utils.Delegate;

class api.dataYAMJ2 {
	// state stuff
	private var fn:Object = null;

	// constructor
	function dataYAMJ2() {
		this.fn = {parsedata:Delegate.create(this, this.hardparse)
			};
	}

	public function cleanup():Void {
		delete this.fn;
		this.fn=null;
		//this.reload();
	}

	public function reload():Void {
		//trace(".. reloaded");
	}


// *************************** PEOPLE **************************
	public function people(xml:XMLNode, callBack:Function) {
		trace("datayamj2 start people data");
		this.fn.parsedata=Delegate.create(this, this.hardparse);

		var xmlNodeList:Array = XPathAPI.selectNodeList(xml, "/movie/people/person");
		var totalTitles=xmlNodeList.length;
		trace(totalTitles+" records");

		var addto=new Array();
		for(var i=0;i<totalTitles;i++) {
			//var title=XPathAPI.selectSingleNode(xmlNodeList[i], "/person/title").firstChild.nodeValue.toString();
			//trace("... title:   "+title);

			// add it
			addto.push({xml:xmlNodeList[i]});
		}

		if(addto.length<1) {
			trace("no people");
			callBack("ERROR", Common.evPrompts.enopeople);
		} else {
			trace("returning people array");
			callBack(null,null,addto);
		}
	}

	public function hardparse(field:String,titledata,howmany:Number):String {
		switch(field) {
			case 'episode':
				if(titledata.special!=undefined) return(Common.evPrompts.special.toUpperCase()+titledata[field]);
				// break missing on purpose
			default:
				if(titledata[field] != undefined) {
					return(titledata[field]);
				} else if(titledata.xml != undefined) {
					trace("yamj2 xml var "+field);
					var itemResult:String=undefined;
					if(StringUtil.beginsWith(field, "multi-")) {
						itemResult=multi_vars(field,titledata.xml);
					} else {
						if(field.indexOf("@") != -1) {
							trace("...attribute var");
							var newfield:Array=field.split("@");
							itemResult = XPathAPI.selectSingleNode(titledata.xml, newfield[0]).attributes[newfield[1]].toString();
						} else {
							trace("...node var");
							itemResult = XPathAPI.selectSingleNode(titledata.xml, field).firstChild.nodeValue.toString();
						}
					}
					trace(".. result:" +itemResult);
					return(itemResult);
				} else return(undefined);
		}
	}

// ************************** data processing ******************************

	public function process_data(field:String,titleXML,howmany:Number):String {
		trace("yamj2 process_data");
		return(this.fn.parsedata(field, titleXML, howmany));
	}

	private function multi_vars(field,titleXML) {
		trace("multi processing: "+field);

		var person:Array=field.split("-");
		if(person.length<4 || person.length>5) {
			trace("not enough elements");
			return("UNKNOWN");
		}

		trace("looking for: "+person[1]);
		var which:Number=int(person[2]);

		var xmlNodeList:Array = XPathAPI.selectNodeList(titleXML,person[1]);
		if(xmlNodeList.length>0) {
			trace("found "+xmlNodeList.length);

			if(xmlNodeList.length<which) {
				trace("element "+which+" not found");
				return("UNKNOWN");
			}
			which--;
			if(person.length>4) {
				return(XPathAPI.selectSingleNode(xmlNodeList[which], person[3]).attributes[person[4]].toString());
			} else {
				return(XPathAPI.selectSingleNode(xmlNodeList[which], person[3]).firstChild.nodeValue.toString());
			}
		}

		return("UNKNOWN");
	}

	private function person_vars(field,titleXML) {
		trace("person processing: "+field);

		var person:Array=field.split("-");
		if(person.length<3 || person.length>4) {
			trace("not enough elements");
			return("UNKNOWN");
		}

		trace("looking for: "+person[1]);
		var which:Number=int(person[2]);

		var xpathvar:String="/movie/people/person[@job='"+person[1]+"']";
		var xmlNodeList:Array = XPathAPI.selectNodeList(titleXML,xpathvar);
		if(xmlNodeList.length>0) {
			trace("found "+xmlNodeList.length);

			if(xmlNodeList.length<which) {
				trace("element "+which+" not found");
				return("UNKNOWN");
			}
			which--;
			if(person.length>3) {
				return(XPathAPI.selectSingleNode(xmlNodeList[which], "/person").attributes[person[3]].toString());
			} else {
				return(XPathAPI.selectSingleNode(xmlNodeList[which], "/person").firstChild.nodeValue.toString());
			}
		}

		return("UNKNOWN");
	}
}