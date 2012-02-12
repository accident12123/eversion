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
import tools.Data;
import tools.StringUtil;
import mx.xpath.XPathAPI;
import mx.utils.Delegate;

class api.dataRSS {
	// state stuff
	private var fn:Object = null;
	private var subdata:String = null;
	private var Callback:Function = null; // the return routine


	// constructor
	function dataRSS() {
		this.fn = {onLoadlundman:Delegate.create(this, this.onLoadlundman)};
	}

	public function cleanup():Void {
		delete this.fn;
		this.fn=null;
		this.reload();
	}

	public function reload():Void {
	}

// ****************************** LUNDMAN ****************************
	public function lundman(url:String, callBack:Function):Void {
		this.fn.parsedata=Delegate.create(this, this.hardparse);
		this.Callback=callBack;

		// load data
		Data.loadXML(url, this.fn.onLoadlundman);
	}

	private function onLoadlundman(success:Boolean, xml:XML, errorcode) {
		if(success) {
			//trace("success, ready to parse");
			var xmlNodeList:Array = XPathAPI.selectNodeList(xml.firstChild, "/xml/trailers/trailer");
			var xmlDataLen:Number = xmlNodeList.length;
			if(xmlDataLen>0) {
				var addto:Array=new Array();

				for (var i:Number = 0; i < xmlDataLen; i++) {
					var itemNode = xmlNodeList[i];

					var current:Array=Data.arrayXML(itemNode);
					current.action="PLAYFILE";
					current.file=current.url;
					//trace(current.title);
					//trace(current.cover);

					addto.push(current);
				}
			} else {
				this.Callback("ERROR", "no data from feed");
			}

			if(addto.length<1) {
				this.Callback("ERROR", "no data from feed");
			} else {
				this.Callback(null,null,addto);
			}
		} else {
			this.Callback("ERROR", "load fail, parse errorcode "+errorcode);
		}
	}

// *********************************** PROCESSING ****************************

	public function hardparse(field:String,titledata,howmany:Number):String {
		switch(field) {
			case 'episode':
				if(titledata.special!=undefined) return(Common.evPrompts.special.toUpperCase()+titledata[field]);
				// break missing on purpose
			default:
				return(titledata[field]);
		}
	}

	public function process_data(field:String,titleXML,howmany:Number):String {
		return(this.fn.parsedata(field, titleXML, howmany));
	}
}

