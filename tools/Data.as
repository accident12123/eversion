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

class tools.Data {
    // our base load xml class
	public static function loadXML(url:String, onLoad:Function):Void {
		if(url==undefined || url==null) onLoad(false, null, 10000);
		if(onLoad==undefined || onLoad==null) onLoad(false, null, 10001);

		var xml:XML = new XML();
		xml.ignoreWhite = true;

		xml.onLoad = function(success:Boolean):Void
		{
			if (success && xml.status==0) {
				onLoad(true, xml);
			} else {
				onLoad(false, xml, xml.status);
			}

			delete xml.idMap;
			xml = null;
		};
		xml.load(url);
	}

	// make an array out of key pair xml style, 1 deep
	public static function arrayXML(xml:XML) {
		var saveData:Object=new Object;

		// loop through the xml
		var myXML = xml.childNodes;

		for (var i=0; i<myXML.length; i++) {
			var dataName=myXML[i].nodeName.toString();
			var dataValue=myXML[i].firstChild.nodeValue.toString();
			//trace(":: "+dataName+" value "+dataValue);
			saveData[dataName]=dataValue;
		}
		if(saveData.length<1) return(null);

		return(saveData);
	}

	public static function is_numeric(val) {
		if (!isNaN(Number(val))) {
			return true;
		}
		return false;
	}
}