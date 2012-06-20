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
import mx.xpath.XPathAPI;

class ev.Background {
	// control
	public static var bgInterval=null;
	public static var bgtasks:Array=null;

	// clock.
	public static var clockMC:MovieClip=null;
	public static var dateMC:MovieClip=null;
	public static var dowMC:MovieClip=null;

	// vercheck.
	public static var verevbad:Boolean=null;
	public static var verevbadupdate:Boolean=null;
	public static var verevupdated:Boolean=null;
	public static var verjb:Boolean=null;
	public static var artworkscanner:Boolean=null;
	public static var veroldyamj:Boolean=null;
	public static var verignore:Boolean=null;
	public static var verlasttime:String=null;

// ********* BG SETUP
	public static function init() {
		Background.reset();

		Background.bgtasks=new Array();

		// add the clock
		Background.add("clock", 10, 6, Background.clock);
		Background.add("vercheck", 0, Common.evSettings.jbcheck, Background.vercheck);

		// start it ticking
		Background.start();
	}

	public static function reset() {
		Background.stop();
		Background.clockMC=null;
		Background.dateMC=null;

		Background.verjb=null;
		Background.veroldyamj=null;
		Background.verignore=null;
		Background.verlasttime=null;
		Background.verevbad=null;
		Background.verevbadupdate=null;
		Background.verevupdated=null;
		Background.artworkscanner=null;

		delete Background.bgtasks;
		Background.bgtasks=null;
	}

	public static function start() {
		Background.bgInterval = setInterval(Background.control,1000);
	}

	public static function stop() {
		clearInterval(Background.bgInterval);
		Background.bgInterval=null;
	}

// ********* BG CONTROL
	public static function control() {
		//trace("control called");
		for(var tt in Background.bgtasks) {
			if(Background.bgtasks[tt].current<2) {
				Background.bgtasks[tt].call();
				if(Background.bgtasks[tt].reset==0) {
					Background.bgtasks[tt].current=9999;
					Background.bgtasks[tt].name="DELETED";
				} else {
					Background.bgtasks[tt].current=Background.bgtasks[tt].reset;
				}
			} else {
				if(Background.bgtasks[tt].name!="DELETED") Background.bgtasks[tt].current--;
			}
		}
	}

	public static function add(name:String, start:Number, interval:Number, call:Function) {
		trace("adding "+name);

		var found:Boolean=false;
		for(var tt in Background.bgtasks) {
			if(Background.bgtasks[tt].name==start) {
				trace("already added, updating settings");
				Background.bgtasks[tt].name=name;
				Background.bgtasks[tt].current=start;
				Background.bgtasks[tt].reset=interval;
				Background.bgtasks[tt].call=call;
				found=true;
				break;
			}
		}
		if(found==false) {
			trace("added");
			Background.bgtasks.push({name:name, current:start, reset:interval, call:call});
		}
	}

// ********* CLOCK
	public static function update_clock(newMC:MovieClip) {
		trace("updating clock");

		// setup the new MC
		Background.clockMC=newMC;

		// update the clock now
		Background.clock();
	}

	public static function update_date(newMC:MovieClip) {
		trace("updating date");

		// setup the new MC
		Background.dateMC=newMC;

		// update the clock now
		Background.clock();
	}

	public static function update_dow(newMC:MovieClip) {
		trace("updating dow");

		// setup the new MC
		Background.dowMC=newMC;

		// update the clock now
		Background.clock();
	}

	public static function clock() {
		//trace("clock called");

		if(Background.clockMC==null && Background.dateMC==null) return;   // is there a clock to update?

		var clocktxtfmt=Background.clockMC.clock.getTextFormat();
		var datetxtfmt=Background.dateMC.date.getTextFormat();
		var dowtxtfmt=Background.dateMC.date.getTextFormat();

		//trace("updating clock");

		var mydate = new Date();
		var minutes = mydate.getMinutes();
		var hours = mydate.getHours();
		delete mydate;

		if (minutes<10) {
			minutes = "0"+minutes;
		}

		if(Common.evSettings.clock=="12") {	// 12 hour
			if (hours>12 ) {
				hours = hours-12;
				var ampm = "PM";
			} else if (hours == 12) {
				var ampm = "PM";
			} else {
				var ampm = "AM";
			}
			if (hours == 0) {
					  hours = 12;
			}
			Background.clockMC.clock.text=hours+":"+minutes+" "+ampm;
		} else {	// 24 hour
			if (hours<10) {
				hours = "0"+hours;
			}
			Background.clockMC.clock.text=hours+":"+minutes;
		}
		Background.clockMC.clock.setTextFormat(clocktxtfmt);

		// date
		var month=mydate.getMonth();
		month++;
		if(month<10) month="0"+month;

		var day=mydate.getDate();
		if(day<10) day="0"+day;

		var year=mydate.getFullYear();

		switch(Common.evSettings.date) {
			case '2':   // YYYY-MM-DD
				Background.dateMC.date.text=year+"-"+month+"-"+day;
				break;
			case '3':   // MM/DD/YYYY
				Background.dateMC.date.text=month+"/"+day+"/"+year;
				break;
			case '4':   // YYYY/MM/DD
				Background.dateMC.date.text=year+"/"+month+"/"+day;
				break;
			case '5':
				Background.dateMC.date.text=day+"-"+month+"-"+year;
				break;
			case '6':
				Background.dateMC.date.text=day+"/"+month+"/"+year;
				break;
			default:    // MM-DD-YYYY
				Background.dateMC.date.text=month+"-"+day+"-"+year;
				break;
		}
		Background.dateMC.date.setTextFormat(datetxtfmt);

		var dayN = mydate.getDay();
		switch (dayN) {
			case 0 :
				Background.dowMC.day.text="Sunday";
				break;
			case 1 :
				Background.dowMC.day.text="Monday";
				break;
			case 2 :
				Background.dowMC.day.text="Tuesday";
				break;
			case 3 :
				Background.dowMC.day.text="Wednesday";
				break;
			case 4 :
				Background.dowMC.day.text="Thursday";
				break;
			case 5 :
				Background.dowMC.day.text="Friday";
				break;
			case 6 :
				Background.dowMC.day.text="Saturday";
				break;
		}
		Background.dowMC.dow.setTextFormat(dowtxtfmt);
	}

// **************** VERSION CHECKS **************************
	public static function vercheck() {
		//trace("time to ver check");

		// ev version
		if(Common.evRun.evversionok != true) {
			trace("checking ev version");
			trace("Common.evRun.evrversion "+Common.evRun.evrversion);
			trace("Common.evSettings.eversion "+Common.evSettings.eversion);
			if(Common.evRun.evrversion!=Common.evSettings.eversion) {
				if(Common.evRun.evrversion<Common.evSettings.eversion) {
					Background.verevupdated=true;
					trace("bad ev phf older detected, alerting");
				} else {
					Background.verevbad=true;
					trace("bad ev update detected, alerting");
				}
			}
			Common.evRun.evversionok=true;
			//Data.loadXML(Common.evSettings.yamjdatapath+"eversion/settings/skinsettings-default.xml", Background.bad_beta1update);
			Data.loadXML("eversion/settings/skinsettings-default.xml", Background.bad_beta1update);
		}

		// yamj versions.
		Data.loadXML(Common.evSettings.yamjdatapath+"jukebox_details.xml", Background.ver_jbdetailsloaded);
	}

	public static function bad_beta1update(success) {
		if(success) {
			trace("beta1 files still in jukebox folder");
			Background.verevbadupdate=true;
		} else {
			trace("beta1 updated correctly");
			Background.verevbadupdate=false;
		}
	}

	public static function ver_jbdetailsloaded(success, xml) {
		if(success) {
			//trace("parsing jbdetails");
			Common.jbmissing=false;

			// extract jukebox stats
			Common.evRun.ystatstotal=XPathAPI.selectSingleNode(xml.firstChild, "/root/statistics/Videos").firstChild.nodeValue.toString();
			Common.evRun.ystatstv=XPathAPI.selectSingleNode(xml.firstChild, "/root/statistics/Movies").firstChild.nodeValue.toString();
			Common.evRun.ystatsmovies=XPathAPI.selectSingleNode(xml.firstChild, "/root/statistics/TVShows").firstChild.nodeValue.toString();

			// extract the timestamp
			var newtimestamp:String=XPathAPI.selectSingleNode(xml.firstChild, "/root/jukebox/RunTime").firstChild.nodeValue.toString();

			// extract yamj major version
			var yamjVersion:String=XPathAPI.selectSingleNode(xml.firstChild, "/root/jukebox/JukeboxVersion").firstChild.nodeValue.toString();

			// extract yamj r version
			var yamjRVersion=int(XPathAPI.selectSingleNode(xml.firstChild, "/root/jukebox/JukeboxRevision").firstChild.nodeValue.toString());

			// artwork scanner
			Background.artworkscanner=false;
			var art:String=XPathAPI.selectSingleNode(xml.firstChild, "/root/jukebox/ArtworkScanner").firstChild.nodeValue.toString().toLowerCase();
			if(art=="true") Background.artworkscanner=true;

			//trace(".. late updated: "+newtimestamp);
			//trace(".. Y Version: "+yamjVersion);
			//trace(".. R Version: "+yamjRVersion);

			// if not ignore
			if(Background.verignore != true && newtimestamp != undefined && newtimestamp != null) {
				// if we don't have a timestamp and timestamp is good from details
				if(Common.evSettings.yamjcheck!='false') {
					if(Background.verlasttime == null) {
						trace("first ver check");

						if(yamjRVersion < Common.evRun.minyamj) {
							trace(".. older than "+Common.evRun.minyamj+", alerting");
							Background.veroldyamj=true;
						} else trace(".. R version is ok");
					} else {
						if(Background.verlasttime != newtimestamp) {
							trace(".. jb updated!");
							Background.verjb=true;
							Common.evRun.updated=true;
						}
					}
				}
			}

			// save timestamp+versions
			if(newtimestamp!= undefined && newtimestamp!= null) {
				//trace("saving ver data");
				Background.verlasttime=newtimestamp;
				Common.evRun.yamjversion=yamjVersion;
				Common.evRun.yamjrversion=yamjRVersion;
			}
		} else {
			trace("problem loading jukebox_details");
			Common.jbmissing=true;
		}
	}
}