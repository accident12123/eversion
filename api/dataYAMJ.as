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

class api.dataYAMJ {
	// state stuff
	private var fn:Object = null;
	private var subdata:String = null;
	private var Callback:Function = null; // the return routine
	private var processingCallback:Function = null; // the return routine
	private var infoprocessing:Boolean = null; // internal return routine
	private var currentfilename:String=null;
	private var indexname:String=null;

	// xml vars
	private var xmlPer:Number = null;  // how many per
	public var indexXML:Array = null;  // array of original xml per title
	public var personXML:XMLNode = null; // array of person data

	// index vars
	private var indexTypeTemp:String=null;
	private var baseIndexName:String=null;
	private var indexLastCount:Number=null;
	private var indexOriginalname:String=null;

	// last seen
	private var currentindexcategory:String=null;

	// artwork vars
	private var artsize:Array=null;

	// constructor
	function dataYAMJ() {
		this.fn = {onLoadyamjXML:Delegate.create(this, this.onLoadyamjXML),
				   onLoadcatXML:Delegate.create(this, this.onLoadcatXML),
				   parsedata:Delegate.create(this, this.xml_parse),
				   episodes_findspecials:Delegate.create(this, this.episodes_findspecials)
			};

		this.artsize=new Array("SMALL","MEDIUM","LARGE","ORIGINAL");
	}

	public function cleanup():Void {
		delete this.fn;
		this.fn=null;
		delete this.artsize;
		this.artsize=null;
		this.reload();
	}

	public function reload():Void {
		delete this.indexXML;
		this.indexXML=null;
		this.infoprocessing=null;
		this.xmlPer=null;
		this.indexTypeTemp=null;
		this.baseIndexName=null;
		this.indexLastCount=null;
		this.currentfilename=null;
		this.indexOriginalname=null;
		this.indexname=null;

		this.currentindexcategory=null;
	}

// ****************************** EXTRAS *****************************
	public function extras(xml:XMLNode, callBack:Function) {
		this.fn.parsedata=Delegate.create(this, this.hardparse);

		var xmlNodeList:Array = XPathAPI.selectNodeList(xml, "/movie/extras/extra");
		var totalTitles=xmlNodeList.length;
		trace(totalTitles+" records");

		var addto=new Array();
		for(var i=0;i<totalTitles;i++) {

			var title=XPathAPI.selectSingleNode(xmlNodeList[i], "/extra").attributes.title.toString();
			var file=XPathAPI.selectSingleNode(xmlNodeList[i], "/extra").firstChild.nodeValue.toString();

			trace("... title:   "+title);
			trace("... file:   "+file);

			// add it
			addto.push({title:title, file:file});
		}

		if(addto.length<1) {
			//trace("no eps");
			callBack("ERROR", Common.evPrompts.enoextras);
		} else {
			//trace("returning ep array");
			callBack(null,null,addto);
		}
	}

// ****************************** EPISODES *****************************
	public function episodes(xml:XMLNode, callBack:Function) {
		this.Callback=callBack;

		// check if we can attempt set load
		var setname=XPathAPI.selectSingleNode(xml, "/movie/indexes/index[@type='Set']").attributes.encoded.toString();
		//trace("@@@ set name: "+setname);
		if(setname.toLowerCase() != "set" && Common.evSettings.epmerge=="true") {
			trace("@@@ attempting to find season 0 in set Set_"+setname+"_1");

			this.indexXML=new Array();
			this.indexXML[0]=xml;

			this.baseIndexName="Set_"+setname+"_";
			//trace("basename is "+this.baseIndexName);

			// have the first page loaded
			Data.loadXML(Common.evSettings.yamjdatapath+this.baseIndexName+"1.xml", this.fn.episodes_findspecials);
		} else {
			trace("set loading skipped");
			this.episodeswithset(xml, null, callBack);
		}
	}

	private function episodes_findspecials(success:Boolean, xml:XML,errorcode) {
		if(success) {
			//trace("set file ready to parse");

			var xmlNodeList:Array = XPathAPI.selectNodeList(xml.firstChild, "/library/movies/movie");
			var xmlDataLen:Number = xmlNodeList.length;
			//trace(xmlDataLen+" seasons to check in this file");

			for (var i:Number = 0; i < xmlDataLen; i++) {
				var season:String=XPathAPI.selectSingleNode(xmlNodeList[i], "/movie/season").firstChild.nodeValue.toString();
				if(season=="0") {
					//trace("found season 0, merging!");
					this.episodeswithset(this.indexXML[0], xmlNodeList[i], this.Callback);
					return;
				} else {
					//trace("skipped season "+season);
				}
			}
			//trace("ready to check for more set pages");
			var indexNode = XPathAPI.selectSingleNode(xml.firstChild, "/library/category/index[@current='true'][@first='"+this.baseIndexName+"1']");
			var itemCurrent = XPathAPI.selectSingleNode(indexNode, "/index").attributes.currentIndex.toString();
			var itemLast = XPathAPI.selectSingleNode(indexNode, "/index").attributes.lastIndex.toString();
			//trace("current: "+itemCurrent+" last: "+itemLast);
			if(itemCurrent!=itemLast) {
				var next=int(itemCurrent)+1;
				Data.loadXML(Common.evSettings.yamjdatapath+this.baseIndexName+next+".xml", this.fn.episodes_findspecials);
			} else {
				//trace("no more set pages to check");
				this.episodeswithset(this.indexXML[0], null, this.Callback);
			}
		} else {
			//trace("failed to load");
			this.episodeswithset(this.indexXML[0], null, this.Callback);
		}
	}

	public function episodeswithset(xml:XMLNode, tvset:XMLNode, callBack:Function) {
		this.fn.parsedata=Delegate.create(this, this.hardparse);

		var season:String=XPathAPI.selectSingleNode(xml, "/movie/season").firstChild.nodeValue.toString();

		if(season!="0") {
			//trace("season "+season+" looking for specials");
			var specials:Array=extract_season(season, "0", tvset);
		}
		var episodes:Array=extract_season(season, null, xml);


		//trace("ready to merge");

		var addto:Array=new Array();
		var lastepisode:Number=-1;

		if(specials!=null) {
			//trace(".. merging in specials");

			var playnum:Number=1;
			for(var i=0;i<specials.length;i++) {  // loop the specials
				trace("special "+i+": beforeep "+specials[i].special.beforeep+" after "+specials[i].special.airsafter);

				if(specials[i].special.airsafter) {
					trace(".. after after");
					if(episodes !=null && episodes != undefined && episodes.length>0) {
						for(var e=0;e<episodes.length;e++) {
							if(episodes[e].skip==true) continue;

							episodes[e].playnum=playnum;
							trace(".... inserting ep "+episodes[e].episode+" playnum "+playnum);
							lastepisode=episodes[e].episode;
							playnum++;
							addto.push(episodes[e]);
						}
						episodes=null;
					}
					trace(".... inserting special "+specials[i].episode+" playnum "+playnum);
					specials[i].playnum=playnum;
					playnum++;
					addto.push(specials[i]);
				} else if(specials[i].special.beforeep!=0) {
					trace(".. SP"+specials[i].episode+": specialairs before, looking for episode "+specials[i].special.beforeep);

					if(episodes !=null && episodes != undefined && episodes.length>0) {
						var checkep=int(specials[i].special.beforeep);
						for(var e=0;e<episodes.length;e++) {
							if(episodes[e].skip==true) continue;

							trace("checking: season "+episodes[e].season+" episode "+episodes[e].episode);
							if(int(episodes[e].episode) >= checkep && episodes[e].special == null) {
								trace("found "+episodes[e].episode+" stopping search");
								break;
							} else {
								episodes[e].playnum=playnum;
								trace(".... inserting ep "+episodes[e].episode+" playnum "+playnum);
								lastepisode=episodes[e].episode;
								playnum++;
								addto.push(episodes[e]);
								episodes[e].skip=true;
							}
						}
						trace(".... inserting special "+specials[i].episode+" playnum "+playnum);
						specials[i].playnum=playnum;
						playnum++;
						addto.push(specials[i]);
					} else {
						if(lastepisode > specials[i].special.beforeep) {
							trace(".. no more episodes to search, dr who time warped specials clause, re-re-remerging");
							episodes=addto;
							addto=new Array();
							i--;
							playnum=1;
							lastepisode=-1;
						} else {
							trace(".... no more episodes inserting special "+specials[i].episode+" playnum "+playnum);
							specials[i].playnum=playnum;
							playnum++;
							addto.push(specials[i]);
						}
					}
				}
			}
			//trace("done with specials");

			// add the missing episodes still left
			if(episodes.length>0) {
				trace("more episodes remain to be merged");
				for(var i=0;i<episodes.length;i++) {
					if(episodes[i].skip==true) continue;

					episodes[i].playnum=playnum;
					trace(".... inserting ep "+episodes[i].episode+" playnum "+playnum);
					playnum++;
					addto.push(episodes[i]);
				}
			}
		} else {
			trace(".. no specials to merge.");
			addto=episodes;
		}

		if(addto.length<1) {
			trace("no eps");
			callBack("ERROR", Common.evPrompts.noeps);
		} else {
			trace("returning ep array");
			callBack(null,null,addto);
		}
	}

	private function extract_season(season, special, xml) {
		//trace("extracting season "+season+" special "+special);
		if(xml==null || xml==undefined) return(null);

		if(special!=null) {
			//trace(".. extract specials ");
			var xmlNodeList:Array = XPathAPI.selectNodeList(xml, "/movie/files/file[@season='0']");
			if(xmlNodeList.length<1) {
				//trace("no specials to extract");
				return(null);
			}
		} else {
			//trace(".. extracting normal season");
			var xmlNodeList:Array = XPathAPI.selectNodeList(xml, "/movie/files/file");
		}

		var totalTitles=xmlNodeList.length;
		//trace(totalTitles+" records");


		var showtitle=this.xml_parse("title",xml); // tv show title name
		var addto=new Array();
		for(var i=0;i<totalTitles;i++) {
			// get the first/last parts
			var firstpart=int(XPathAPI.selectSingleNode(xmlNodeList[i], "/file").attributes.firstPart.toString());
			var lastpart=int(XPathAPI.selectSingleNode(xmlNodeList[i], "/file").attributes.lastPart.toString());
			var newpart=true;

			// loop the episodes in this record
			for(var u=firstpart;u<=lastpart;u++) {
				if(special!=null) {
					var airbefore=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/airsInfo[@part='"+u+"'").attributes.beforeEpisode.toString();
					var airbefores=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/airsInfo[@part='"+u+"'").attributes.beforeSeason.toString();
					var airafter=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/airsInfo[@part='"+u+"'").attributes.afterSeason.toString();

					trace(".. airs afterseason "+airafter+" beforeseason "+airbefores+" before episode "+airbefore);
					var specs:Object=new Object();
					if(airbefores==season) {
						specs.beforeep=airbefore;
						//specs.beforeep=airbefores;
						specs.airsafter=false;
					} else if(airafter==season) {
						specs.airsafter=true;
						specs.beforeep=0;
					} else {
						trace("skipped, not for "+season);
						continue;
					}
					trace("+++ settings used: airsafter: "+specs.airsafter+" beforeep " + specs.beforeep);
				}
				// extra the details of this episode
				var title=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/fileTitle[@part='"+u+"']").firstChild.nodeValue.toString();
				var watched=XPathAPI.selectSingleNode(xmlNodeList[i], "/file").attributes.watched.toString();
				var filePlot=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/filePlot[@part='"+u+"']").firstChild.nodeValue.toString();
				var fileRating=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/fileRating[@part='"+u+"']").firstChild.nodeValue.toString();
				var file=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/fileURL").firstChild.nodeValue.toString();
				var zcd=XPathAPI.selectSingleNode(xmlNodeList[i], "/file").attributes.zcd.toString();
				var fileImageFile=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/fileImageFile[@part='"+u+"']").firstChild.nodeValue.toString();
				var fileImageURL=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/fileImageURL[@part='"+u+"']").firstChild.nodeValue.toString();
				var aired=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/firstAired[@part='"+u+"']").firstChild.nodeValue.toString();

				// setup play name
				if(newpart) {
					if(special!=null) {
						var playseason="00";
					} else {
						if(season.length<2) var playseason="0"+season;
						   else var playseason=season;
					}
					var showpart=firstpart.toString();
					if(showpart.length<2) showpart="0"+showpart;

					if(firstpart!=lastpart) {  // multiple-episode video
						var showlastpart=lastpart.toString();
						if(showlastpart.length<2) showlastpart="0"+showlastpart;
						var name=showtitle+" "+Common.evPrompts.seasonshort+playseason+Common.evPrompts.episodeshort+showpart+" - "+Common.evPrompts.episodeshort+showlastpart;
					} else {					// single episode video with epname
						var name=showtitle+" "+Common.evPrompts.seasonshort+playseason+Common.evPrompts.episodeshort+showpart+": "+title;
					}
					if(special!=null) name=name+" ("+Common.evPrompts.special.toUpperCase()+")";
				}

				var scoreyamj=Math.round(int(fileRating)/10)*10;
				var score=int(fileRating)/10;
				var scorefive=Math.round((int(fileRating)/20)*10)/10;

				addto.push({playnum:i+1, playname:name, score:score.toString(),score10:score.toString(),score5:scorefive.toString(),scoreyamj:scoreyamj.toString(),zcd:zcd, newpart:newpart, url:file, aired:aired, rating:fileRating, season:season, episode:u, title:title, watched:watched, plot:filePlot, smartplot:filePlot, smartoutline:filePlot, outline:filePlot, videoimage:fileImageFile, special:specs, videoimageurl:fileImageURL});
				newpart=false;
			}
		}

		if(addto.length!=0) return(addto);

		return(null);
	}

	public function hardparse(field:String,titledata,howmany:Number):String {
		switch(field) {
			case 'episode':
				if(titledata.special!=undefined) return(Common.evPrompts.special.toUpperCase()+titledata[field]);
				// break missing on purpose
			default:
				return(titledata[field]);
		}
	}

// ***************************** MPARTS **********************************
	public function mpartsall(xml:XMLNode, callBack:Function) {
		this.fn.parsedata=Delegate.create(this, this.hardparse);

		//trace("dataYAMJ parsing out episodes");

		var xmlNodeList:Array = XPathAPI.selectNodeList(xml, "/movie/files/file");
		var totalTitles=xmlNodeList.length;
		trace(totalTitles+" records");

		var addto=new Array();
		addto.push({title:"Play All",action:"PLAYALLMULTI",episode:0});
		for(var i=0;i<totalTitles;i++) {
			// get the first/last parts
			var firstpart=int(XPathAPI.selectSingleNode(xmlNodeList[i], "/file").attributes.firstPart.toString());
			var title=XPathAPI.selectSingleNode(xmlNodeList[i], "/file/fileTitle[@part='"+firstpart+"'").firstChild.nodeValue.toString();
			if(title=="UNKNOWN") title="PART "+firstpart;

			// add it
			addto.push({episode:firstpart, title:title, action:"PLAYSINGLE"});
		}

		if(addto.length<2) {
			callBack("ERROR", Common.evPrompts.enoparts);
		} else {
			callBack(null,null,addto);
		}
	}


// ****************************** CATEGORIES *****************************

	public function getCat(callBack:Function):Void {
		this.Callback=callBack;

		//trace("datayamj, categories loading");

		// load up the categories
		Data.loadXML(Common.evSettings.yamjdatapath+"Categories.xml", this.fn.onLoadcatXML);
	}

	private function onLoadcatXML(success:Boolean, xml:XML) {
		if(success) {
			//trace("loaded categories.xml");

			// prep the global
			delete Common.indexes;
			Common.indexes=new Array();

			// prep what we're looking for
			var needed:Array=new Array();
			needed=needed.concat(Common.esSettings.homelist.split(","),Common.esSettings.menulist.split(","));
			if(Common.esSettings.userlist!=undefined &&  Common.esSettings.userlist!=null) {
				needed=needed.concat(Common.esSettings.userlist.split(","));
			}
			if(Common.esSettings.userlist2!=undefined &&  Common.esSettings.userlist2!=null) {
				needed=needed.concat(Common.esSettings.userlist2.split(","));
			}
			if(Common.esSettings.userlist3!=undefined &&  Common.esSettings.userlist3!=null) {
				needed=needed.concat(Common.esSettings.userlist3.split(","));
			}
			if(Common.esSettings.userlist4!=undefined &&  Common.esSettings.userlist4!=null) {
				needed=needed.concat(Common.esSettings.userlist4.split(","));
			}

			for(var i=0;i<needed.length;i++) {
				if(Common.indexes[needed[i].toLowerCase()] == undefined) {
					processCat(xml, needed[i]);
				} // else trace(".. already done, skipped processing of "+needed[i]);
			}

			// prepare the homelist
			var homedata:Array=new Array();
			var homelist:Array=new Array();
			homelist=Common.esSettings.homelist.split(",");
			for(var i=0;i<homelist.length;i++) {
				//trace(".. adding "+homelist[i]+" to home");

				if(Common.indexes[homelist[i].toLowerCase()]!= undefined) {
					homedata=homedata.concat(Common.indexes[homelist[i].toLowerCase()]);
					//trace("... success");
				} // else trace("... didn't exist");
			}

			// send it off (if we have something)
			if(homedata.length>0) {
				Common.indexes["homelist"]=homedata;
			}

			// cleaner
			delete homedata;
			delete homelist;

			// prepare the menulist
			homelist=new Array();
			homedata=new Array();
			homelist=Common.esSettings.menulist.split(",");

			for(var i=0;i<homelist.length;i++) {
				//trace(".. adding "+homelist[i]+" to menu");

				if(Common.indexes[homelist[i].toLowerCase()]!= undefined) {
					homedata.push({action:"catlist", arraydata:homelist[i].toLowerCase(), title:Common.evPrompts[homelist[i].toLowerCase()],originaltitle:homelist[i].toLowerCase()});
					//trace("... success");
				} // else trace("... didn't exist");
			}

			// send it off (if we have something)
			if(homedata.length>0) {
				Common.indexes["menulist"]=homedata;
			}

			if(Common.esSettings.userlist!=undefined &&  Common.esSettings.userlist!=null) {
				// prepare the userlist
				homelist=new Array();
				homedata=new Array();
				homelist=Common.esSettings.userlist.split(",");

				for(var i=0;i<homelist.length;i++) {
					//trace(".. adding "+homelist[i]+" to user");

					if(Common.indexes[homelist[i].toLowerCase()]!= undefined) {
						homedata.push({action:"catlist", arraydata:homelist[i].toLowerCase(), title:Common.evPrompts[homelist[i].toLowerCase()],originaltitle:homelist[i].toLowerCase()});
						//trace("... success");
					} // else trace("... didn't exist");
				}

				// send it off (if we have something)
				if(homedata.length>0) {
					Common.indexes["userlist"]=homedata;
				}
			}

			if(Common.esSettings.userlist2!=undefined &&  Common.esSettings.userlist2!=null) {
				// prepare the userlist
				homelist=new Array();
				homedata=new Array();
				homelist=Common.esSettings.userlist2.split(",");

				for(var i=0;i<homelist.length;i++) {
					//trace(".. adding "+homelist[i]+" to user");

					if(Common.indexes[homelist[i].toLowerCase()]!= undefined) {
						homedata.push({action:"catlist", arraydata:homelist[i].toLowerCase(), title:Common.evPrompts[homelist[i].toLowerCase()],originaltitle:homelist[i].toLowerCase()});
						//trace("... success");
					} // else trace("... didn't exist");
				}

				// send it off (if we have something)
				if(homedata.length>0) {
					Common.indexes["userlist2"]=homedata;
				}
			}

			if(Common.esSettings.userlist3!=undefined &&  Common.esSettings.userlist3!=null) {
				// prepare the userlist
				homelist=new Array();
				homedata=new Array();
				homelist=Common.esSettings.userlist3.split(",");

				for(var i=0;i<homelist.length;i++) {
					//trace(".. adding "+homelist[i]+" to user");

					if(Common.indexes[homelist[i].toLowerCase()]!= undefined) {
						homedata.push({action:"catlist", arraydata:homelist[i].toLowerCase(), title:Common.evPrompts[homelist[i].toLowerCase()],originaltitle:homelist[i].toLowerCase()});
						//trace("... success");
					} // else trace("... didn't exist");
				}

				// send it off (if we have something)
				if(homedata.length>0) {
					Common.indexes["userlist3"]=homedata;
				}
			}

			if(Common.esSettings.userlist4!=undefined &&  Common.esSettings.userlist4!=null) {
				// prepare the userlist
				homelist=new Array();
				homedata=new Array();
				homelist=Common.esSettings.userlist4.split(",");

				for(var i=0;i<homelist.length;i++) {
					//trace(".. adding "+homelist[i]+" to user");

					if(Common.indexes[homelist[i].toLowerCase()]!= undefined) {
						homedata.push({action:"catlist", arraydata:homelist[i].toLowerCase(), title:Common.evPrompts[homelist[i].toLowerCase()],originaltitle:homelist[i].toLowerCase()});
						//trace("... success");
					} // else trace("... didn't exist");
				}

				// send it off (if we have something)
				if(homedata.length>0) {
					Common.indexes["userlist4"]=homedata;
				}
			}
			this.Callback();

			// cleaner
			delete homedata;
			delete homelist;
		} else {
			this.Callback(null, Common.evPrompts.enoload+Common.evSettings.yamjdatapath+"Categories.xml");
		}
	}

	private function processCat(xml:XML, what:String) {
		//trace("processing "+what);

		var addto:Array=new Array();
		var place=0;

		// pull out node with info
		var xmlNodeList:Array = XPathAPI.selectNodeList(xml.firstChild, "/library/category[@name='"+what+"']/index");
		var xmlDataLen:Number = xmlNodeList.length;

		if(xmlDataLen>0) {
			//trace("found "+xmlDataLen+" "+what);
			for (var i:Number = 0; i < xmlDataLen; i++) {
				var itemNode = xmlNodeList[i];
				//this.indexXML[itemCurrent][i]=itemNode;
				var name = XPathAPI.selectSingleNode(itemNode, "/index").attributes.name.toString();
				var originalName = XPathAPI.selectSingleNode(itemNode, "/index").attributes.originalName.toString();
				var index= XPathAPI.selectSingleNode(itemNode, "/index").firstChild.nodeValue.toString();
				//trace("+++++ ORIGINALNAME: "+originalName);
				if(originalName==undefined || originalName==null || originalName=="") {
					originalName=originaltitle_fix(index);
					//trace("+++++ ORIGINALNAME2: "+originalName);
					if(originalName=="UNKNOWN") originalName=name;
				}
				//trace("+++++ ORIGINALNAME FINAL: "+originalName);
				trace("index "+index+" named "+name+ " originalname "+originalName);
				addto[place]={action:"SWITCH", data:index, file:index, title:name, originaltitle:originalName};
				place++;
			}
			Common.indexes[what.toLowerCase()]=addto;
			trace(Common.indexes[what]);
		}
		delete addto;
	}


// ****************************** INDEX INFO ******************************
	// Load/get information about an index
	public function getIndexInfo(url:String, callBack:Function):Void {
		this.processingCallback=callBack;

		// prep the save
		this.indexXML=new Array();

		// prep baseIndexName
		var name:Array=url.split("_");
		name.pop();
		this.baseIndexName=name.join("_")+"_";
		trace("basename is "+this.baseIndexName);
		trace(url);

		if(url != null) {
			// figure out the temp types we need to use filename to find
			if(url.indexOf("Other_New-TV") != -1) {
				trace("TV index");
				this.indexTypeTemp="NEWTV";
			} else if(url.indexOf("Other_TV") != -1 || url.indexOf("Library_TV") != -1){
				trace("TV index");
				this.indexTypeTemp="TV";
			} else if(url.indexOf("Other_Movie") != -1 || url.indexOf("Library_Movie") != -1) {
				trace("Movie index");
				this.indexTypeTemp="MOVIE";
			} else if(url.indexOf("Other_New-Movie") != -1) {
				trace("Movie index");
				this.indexTypeTemp="NEWMOVIE";
			} else if(url.indexOf("Other_New_") != -1 || url.indexOf("Library_New") != -1) {
				trace("Movie index");
				this.indexTypeTemp="NEW";
			} else if(url.indexOf("Set_") != -1) {
				trace("set index");
				this.indexTypeTemp="SET";
			} else if(url.indexOf("Person_") != -1 || url.indexOf("Writer_") != -1 || url.indexOf("Director_") != -1 || url.indexOf("Cast_") != -1) {
				trace("People index");
				this.indexTypeTemp="PEOPLE";
			} else {
				trace("generic index or possible unknown rename");
				this.indexTypeTemp="INDEX";
			}

			trace("index type currently: "+this.indexTypeTemp);

			// are we info processing
			this.infoprocessing=true;
			this.currentfilename=Common.evSettings.yamjdatapath+url+".xml";

			// have the first page loaded
			Data.loadXML(Common.evSettings.yamjdatapath+url+".xml", this.fn.onLoadyamjXML);

		} else {
			// return with error
			this.processingCallback(null, Common.evPrompts.enoindexfilename);
		}
	}
// ****************************** INDEX XML DATA ****************************

	//
	public function getData(url:String, needPage:Number, callBack:Function):Void {
		this.Callback=callBack;
		var filename:String = null;

		if(needPage==-1) { // details/other file
			filename=url+".xml";
			//trace("direct file request "+filename);
		} else {
			filename=this.baseIndexName+needPage+".xml";
			//trace("xml page request "+filename);
		}

		// clear
		this.indexXML[needPage]=null;
		this.infoprocessing=false;
		this.currentfilename=Common.evSettings.yamjdatapath+filename;

		Data.loadXML(Common.evSettings.yamjdatapath+filename, this.fn.onLoadyamjXML);
	}

// ************************* INDEX FILE PROCESSING ***************************

	// after xml file loaded
	private function onLoadyamjXML(success:Boolean, xml:XML):Void {
		//trace("xml file loaded");

		if(success) {
			this.currentfilename=null;

			if(this.personXML==null) {
				var ttXML=XPathAPI.selectSingleNode(xml.firstChild, "/library/person");
				if(ttXML != undefined && ttXML != null && ttXML != '') {
				    // adjust the xml for existing variable processing
					var jjXML:XML=new XML('<movie/>');

					for (var i=0; i<ttXML.childNodes.length; i++) {
						jjXML.firstChild.appendChild(ttXML.childNodes[i].cloneNode(true));
						//trace(":: "+ttXML.childNodes[i]);
					}
					this.personXML=jjXML.firstChild;

					trace("found person xml");
					//trace(this.personXML);
				}
			}

			// get the currentindexcategory
			this.currentindexcategory=XPathAPI.selectSingleNode(xml.firstChild, "/library/category[@current='true']").attributes.name.toString();
			if(this.currentindexcategory==undefined) this.currentindexcategory=null;
			trace("current index cat is: "+this.currentindexcategory);

			// process the xml file
			var indexNode:XMLNode = null;

			// pull out node with info
			indexNode = XPathAPI.selectSingleNode(xml.firstChild, "/library/category/index[@current='true'][@first='"+this.baseIndexName+"1']");

			// double check this is not an index with ' in the name
			if(indexNode==undefined) {
				indexNode = XPathAPI.selectSingleNode(xml.firstChild, "/library/category/index[@current='true']");
			}

			if(indexNode!=undefined) {
				// pull out the movie records
				var xmlNodeList:Array = XPathAPI.selectNodeList(xml.firstChild, "/library/movies/movie");
				var xmlDataLen:Number = xmlNodeList.length;

				// save the original name just in case
				this.indexOriginalname=XPathAPI.selectSingleNode(indexNode, "/index").attributes.originalName.toString();

				// figure out the page number..
				var itemCurrent = XPathAPI.selectSingleNode(indexNode, "/index").attributes.currentIndex.toString();
				//trace("itemcurrent="+itemCurrent);

				// last page (total pages)
				var itemLast = XPathAPI.selectSingleNode(indexNode, "/index").attributes.lastIndex.toString();
				//trace("indexlast "+itemLast);

				// if we don't have saved xml data, process it
				if(this.indexXML[itemCurrent] == null) {
					//trace("new xml file, processing");
					this.indexXML[itemCurrent] = new Array();

					// loop through the movies in the xml and pull out data we care about
					for (var i:Number = 0; i < xmlDataLen; i++)
					{
						var itemNode = xmlNodeList[i];
						this.indexXML[itemCurrent][i]=itemNode;
					}
				}

				if(itemLast==itemCurrent) {  // only count the titles from the last page
					this.indexLastCount=xmlDataLen;
				}

				// data or info processing?
				if(this.infoprocessing==true) {
					//trace("info processing");

					if(Common.evSettings.indexcount=="true") {
						var indexcount:String = XPathAPI.selectSingleNode(xml.firstChild, "/library/movies/movie").attributes.indexCount.toString();
						if(indexcount!= undefined && indexcount!=null) {
							if(itemLast == 1) {
								this.xmlPer=0;
							} else {
								this.xmlPer=int(this.indexXML[itemCurrent].length);
							}
							this.infoProcessing(xml, indexNode);
							return;
						}
					}

					// if page 1, get more info
					if(itemCurrent=="1") {
						var per=this.indexXML[itemCurrent].length;

						// save what we have so far
						if(itemLast == 1) {
							this.xmlPer=0;
							this.infoProcessing(xml, indexNode);
						} else {
							this.xmlPer=int(per);

							var lastfile = XPathAPI.selectSingleNode(indexNode, "/index").attributes.last.toString();
							Data.loadXML(Common.evSettings.yamjdatapath+lastfile+".xml", this.fn.onLoadyamjXML);
						}
					} else {
						this.infoProcessing(xml, indexNode);
					}
				} else {
					var tempindex=this.indexXML[itemCurrent];
					this.indexXML[itemCurrent]=null;
					this.Callback(tempindex,int(itemCurrent));
				}
			} else {
				// details file read in
				this.processingCallback(null, "Unsupported file format: "+Common.evPrompts.eprobfile+this.currentfilename);
			}
		} else {
			// tell the caller we can't process directly
			this.processingCallback(null, Common.evPrompts.eprobfile+this.currentfilename);
		}
	}

	private function infoProcessing(xml:XML, indexNode:XMLNode) {
		// get index name
		var indexName = XPathAPI.selectSingleNode(indexNode, "/index").attributes.name.toString();
		this.indexname=indexName;
		trace("indexname "+indexName);

		// last page (total pages)
		var itemLast = XPathAPI.selectSingleNode(indexNode, "/index").attributes.lastIndex.toString();
		trace("indexlast "+itemLast);

		// eskin requested originalname
		var originalName = XPathAPI.selectSingleNode(indexNode, "/index").attributes.originalName.toString();
		if(originalName == undefined || originalName == null || originalName == "") {
			originalName=this.originaltitle_fix(this.baseIndexName);
		}
		trace("originalName="+originalName);

		var indexcount:String = XPathAPI.selectSingleNode(xml.firstChild, "/library/movies/movie").attributes.indexCount.toString();
		if(Common.evSettings.indexcount=="true" && indexcount != undefined && indexcount != null) {
			var total=int(indexcount);
		} else {
			var total=((int(itemLast)-1)*this.xmlPer) + this.indexLastCount;
		}
		trace("total items in index "+total);
		trace("index type currently: "+this.indexTypeTemp);

		// INDEX TYPE
		if(this.indexTypeTemp=="SET") {
			// figure out type of set
			var mediatype=this.process_data("mtype",this.indexXML[1][0]);
			var indexType=mediatype.toUpperCase()+this.indexTypeTemp;
		} else {
			if(this.indexTypeTemp == "INDEX" && this.indexOriginalname!=undefined && this.indexOriginalname!=null) {  // make sure it's detected correctly
				trace("checking for renamed index original name "+this.indexOriginalname);
				if(this.indexOriginalname.indexOf("New-TV") != -1) {
					trace(".. TV index");
					this.indexTypeTemp="NEWTV";
				} else if(this.indexOriginalname.indexOf("TV") != -1) {
					trace(".. TV index");
					this.indexTypeTemp="TV";
				} else if(this.indexOriginalname.indexOf("New-Movie") != -1) {
					trace(".. New Movie index");
					this.indexTypeTemp="NEWMOVIE";
				} else if(this.indexOriginalname.indexOf("Movie") != -1) {
					trace(".. Movie index");
					this.indexTypeTemp="MOVIE";
				} else {
					trace(".. no change, generic index");
				}
			} else {
				trace("index original name recheck skipped: "+this.indexOriginalname);
			}

			// we know the type
			var indexType=this.indexTypeTemp;

		}

		trace("finished info processing");
		this.infoprocessing=false;

		trace("PRECHECK: "+indexType);

		var tempindex:Array=this.indexXML[1];
		this.indexXML[1]=null;
		this.indexXML[itemLast]=null;

		// send the data back with page 1 xml
		// xml, friendly name, type, number of pages, total number of tiles in the index
		this.processingCallback(tempindex,indexName,indexType,int(itemLast),total,originalName);
	}

	private function originaltitle_fix(testname:String) {
		var originalName="UNKNOWN";

		testname=testname.toLowerCase();
		if(testname.indexOf("other") != -1) {
			originalName="other";
		} else if(testname.indexOf("genre") != -1) {
			originalName="genre";
		} else if(testname.indexOf("title") != -1) {
			originalName="title";
		} else if(testname.indexOf("certification") != -1) {
			originalName="certification";
		} else if(testname.indexOf("year") != -1) {
			originalName="year";
		} else if(testname.indexOf("library") != -1) {
			originalName="library";
		} else if(testname.indexOf("cast") != -1) {
			originalName="cast";
		} else if(testname.indexOf("director") != -1) {
			originalName="director";
		} else if(testname.indexOf("country") != -1) {
			originalName="country";
		} else if(testname.indexOf("set") != -1) {
			originalName="set";
		} else if(testname.indexOf("award") != -1) {
			originalName="award";
		} else if(testname.indexOf("person") != -1) {
			originalName="person";
		} else if(testname.indexOf("ratings") != -1) {
			originalName="ratings";
		}

		return(originalName);
	}

// ************************** data processing ******************************

	public function process_data(field:String,titleXML,howmany:Number):String {
		return(this.fn.parsedata(field, titleXML, howmany));
	}

	public function xml_parse(field:String,titleXML:XMLNode,howmany:Number):String {
		// make sure we're good to contine
		if(titleXML != null) {
			// process the request
			var itemResult:String=null;
			switch(field) {
				case 'epcount':
					var xmlNodeList:Array = XPathAPI.selectNodeList(titleXML, "/movie/files/file");
					var xmlDataLen:Number = xmlNodeList.length;
					var count:Number=0;
					for(var i=0;i<xmlDataLen;i++) {
						var lastpart=int(XPathAPI.selectSingleNode(xmlNodeList[i], "/file").attributes.lastPart.toString());
						var more=lastpart-int(XPathAPI.selectSingleNode(xmlNodeList[i], "/file").attributes.firstPart.toString())+1;
						count=count+more;
					}
					delete xmlNodeList;
					xmlNodeList=null;
					itemResult=count.toString();
					break;
				case 'action':    // figure out the dex action
					itemResult = XPathAPI.selectSingleNode(titleXML, "/movie").attributes.isSet.toString();
					if(itemResult=="true") {
						itemResult="index";
					} else {
						itemResult="detail";
					}
					break;
				case 'file':
					itemResult = XPathAPI.selectSingleNode(titleXML, "/movie/baseFilename").firstChild.nodeValue.toString();
					break;
				case 'setorder':
					//trace("set order");
					itemResult="NONE";
					var xmlNodeList:Array = XPathAPI.selectNodeList(titleXML, "/movie/sets/set");
					var xmlDataLen:Number = xmlNodeList.length;
					for(var i=0;i<xmlDataLen;i++) {
						var setname=XPathAPI.selectSingleNode(xmlNodeList[i], "/set").firstChild.nodeValue.toString();
						if(setname==this.indexname) {
							trace("found: "+setname);
							itemResult=XPathAPI.selectSingleNode(xmlNodeList[i], "/set").attributes.order.toString();
							break;
						} else {
							trace("skipped set name: "+setname+" looking for "+this.indexname);
						}
					}

					if(itemResult=="NONE") {
						itemResult = XPathAPI.selectSingleNode(titleXML, "/movie/sets/[set="+this.indexname+"]/set").attributes.order.toString();
					}
					trace("SET ORDER: "+itemResult);
					break;
				case 'mtype':
					itemResult = XPathAPI.selectSingleNode(titleXML, "/movie").attributes.isSet.toString();
					if(itemResult=="true") {
						var test= XPathAPI.selectSingleNode(titleXML, "/movie").attributes.isTV.toString();
						if(test=="true") {
							itemResult="TVSET";
						} else {
							itemResult="MOVIESET";
						}
					} else {
						//  tv
						itemResult = XPathAPI.selectSingleNode(titleXML, "/movie").attributes.isTV.toString();
						if(itemResult=="true") {
							itemResult="TV";
						} else {
							itemResult="MOVIE";
						}
					}
					break;
				case 'genres':
					itemResult=this.process_TitleData_xpath_multi('/movie/genres/genre',"genre",titleXML,howmany);
					break;
				case 'actors':
					itemResult=this.process_TitleData_xpath_multi('/movie/cast/actor',"actor",titleXML,howmany);
					break;
				case 'writers':
					itemResult=this.process_TitleData_xpath_multi('/movie/writers/writer',"writer",titleXML,howmany);
					break;
				case 'directors':
					itemResult=this.process_TitleData_xpath_multi('/movie/directors/director',"director",titleXML,howmany);
					if(itemResult=="UNKNOWN") {  // legacy jukebox xml
						itemResult = XPathAPI.selectSingleNode(titleXML, "/movie/director").firstChild.nodeValue.toString();
					}
					break;
				case 'smartoutline':
					itemResult=XPathAPI.selectSingleNode(titleXML, "/movie/outline").firstChild.nodeValue.toString();
					if(itemResult=="UNKNOWN" || itemResult==null || itemResult==undefined) {
						itemResult=XPathAPI.selectSingleNode(titleXML, "/movie/plot").firstChild.nodeValue.toString();
					}
					itemResult=StringUtil.remove(itemResult, "See full summary �");
					itemResult=StringUtil.remove(itemResult, "{br}");
					break;
				case 'outline':
					itemResult=XPathAPI.selectSingleNode(titleXML, "/movie/outline").firstChild.nodeValue.toString();
					itemResult=StringUtil.remove(itemResult, "See full summary �");
					itemResult=StringUtil.remove(itemResult, "{br}");
					break;
				case 'plot':
					itemResult=XPathAPI.selectSingleNode(titleXML, "/movie/plot").firstChild.nodeValue.toString();
					itemResult=StringUtil.remove(itemResult, "See full summary �");
					itemResult=StringUtil.remove(itemResult, "{br}");
					break;
				case 'smartplot':
					itemResult=XPathAPI.selectSingleNode(titleXML, "/movie/plot").firstChild.nodeValue.toString();
					if(itemResult=="UNKNOWN" || itemResult==null || itemResult==undefined) {
						itemResult=XPathAPI.selectSingleNode(titleXML, "/movie/outline").firstChild.nodeValue.toString();
					}
					itemResult=StringUtil.remove(itemResult, "See full summary �");
					itemResult=StringUtil.remove(itemResult, "{br}");
					break;
				case 'fulltitle':
				case 'fulltitlenoyear':
					itemResult=XPathAPI.selectSingleNode(titleXML, "/movie/title").firstChild.nodeValue.toString();
					if(XPathAPI.selectSingleNode(titleXML, "/movie").attributes.isSet.toString() != "true") {
						var season:String=XPathAPI.selectSingleNode(titleXML, "/movie/season").firstChild.nodeValue.toString();
						switch(season) {
							case "-1":
								var ses:String="";
								break;
							case "0":
								var ses:String=" "+Common.evPrompts.specials;
								break;
							case undefined:  // WE'RE NOT LOADED YET
								return(season);
							default:
								var ses:String=" "+Common.evPrompts.season+" "+season;
								break;
						}
					} else var ses:String="";
					itemResult=itemResult+ses;
					break;
				case 'smarttitle':
					itemResult=XPathAPI.selectSingleNode(titleXML, "/movie/title").firstChild.nodeValue.toString();
					var season:String=XPathAPI.selectSingleNode(titleXML, "/movie/season").firstChild.nodeValue.toString();
					switch(season) {
						case "-1":
							break;
						case "0":
							itemResult=Common.evPrompts.specials;
							break;
						case undefined:  // WE'RE NOT LOADED YET
							return(season);
						default:
							itemResult=Common.evPrompts.season+" "+season;
							break;
					}
					break;
				case 'fullseason':
					var season:String=XPathAPI.selectSingleNode(titleXML, "/movie/season").firstChild.nodeValue.toString();
					switch(season) {
						case "-1":
							itemResult="";
							break;
						case "0":
							itemResult=Common.evPrompts.specials;
							break;
						case undefined:  // WE'RE NOT LOADED YET
							itemResult=season;
						default:
							itemResult=Common.evPrompts.season+" "+season;
							break;
					}
					break;
				case 'scoreyamj':
					var rating:String=XPathAPI.selectSingleNode(titleXML, "/movie/rating").firstChild.nodeValue.toString();
					if(rating=="UNKNOWN") return("UNKNOWN");
					var score:Number=Math.round(int(rating)/10)*10;
					itemResult=score.toString();
					break;
				case 'score10':
				case 'score':
					var rating:String=XPathAPI.selectSingleNode(titleXML, "/movie/rating").firstChild.nodeValue.toString();
					if(rating=="UNKNOWN") return("UNKNOWN");
					var score:Number=int(rating)/10;
					itemResult=score.toString();
					break;
				case 'score5':
					var rating:String=XPathAPI.selectSingleNode(titleXML, "/movie/rating").firstChild.nodeValue.toString();
					if(rating=="UNKNOWN") return("UNKNOWN");
					var score:Number=Math.round((int(rating)/20)*10)/10;
					itemResult=score.toString();
					break;
				case 'smartcontainer':
					var itemResult:String=XPathAPI.selectSingleNode(titleXML, "/movie/container").firstChild.nodeValue.toString();
					if(itemResult!="UNKNOWN") {
						itemResult=itemResult.toUpperCase();
						if(itemResult.indexOf("HD2DVD") != -1) {
							itemResult="hd2dvd";
						} else if(itemResult.indexOf("ASF") != -1) {
							itemResult="asf";
						} else if(itemResult.indexOf("AVI") != -1) {
							itemResult="avi";
						} else if(itemResult.indexOf("BIN") != -1) {
							itemResult="bin";
						} else if(itemResult.indexOf("DAT") != -1) {
							itemResult="dat";
						} else if(itemResult.indexOf("IMG") != -1) {
							itemResult="img";
						} else if(itemResult.indexOf("DIVX") != -1) {
							itemResult="divx";
						} else if(itemResult.indexOf("DVD") != -1) {
							itemResult="dvd";
						} else if(itemResult.indexOf("ISO") != -1) {
							itemResult="iso";
						} else if(itemResult.indexOf("BDMV") != -1 || itemResult.indexOf("BDAV") != -1 || itemResult.indexOf("BLURAY") != -1 || itemResult.indexOf("BLU-RAY") != -1 || itemResult.indexOf("BDMV") != -1 || itemResult.indexOf("BDMV") != -1) {
							itemResult="bluray";
						} else if(itemResult.indexOf("M1V") != -1) {
							itemResult="m1v";
						} else if(itemResult.indexOf("M2P") != -1) {
							itemResult="m2p";
						} else if(itemResult.indexOf("M2TS") != -1) {
							itemResult="m2ts";
						} else if(itemResult.indexOf("M2T") != -1) {
							itemResult="m2t";
						} else if(itemResult.indexOf("M2V") != -1) {
							itemResult="m2v";
						} else if(itemResult.indexOf("M4V") != -1) {
							itemResult="m4v";
						} else if(itemResult.indexOf("MDF") != -1) {
							itemResult="mdf";
						} else if(itemResult.indexOf("MKV") != -1 || itemResult.indexOf("MATROSKA") != -1) {
							itemResult="mkv";
						} else if(itemResult.indexOf("MOV") != -1) {
							itemResult="mov";
						} else if(itemResult.indexOf("MP4") != -1 || itemResult.indexOf("MPEG-4") != -1) {
							itemResult="mp4";
						} else if(itemResult.indexOf("MPG") != -1 || itemResult.indexOf("PS") != -1) {
							itemResult="mpg";
						} else if(itemResult.indexOf("MTS") != -1) {
							itemResult="mts";
						} else if(itemResult.indexOf("NRG") != -1) {
							itemResult="nrg";
						} else if(itemResult.indexOf("QT") != -1) {
							itemResult="qt";
						} else if(itemResult.indexOf("RAR") != -1) {
							itemResult="rar";
						} else if(itemResult.indexOf("FLV") != -1) {
							itemResult="flv";
						} else if(itemResult.indexOf("RM") != -1) {
							itemResult="rm";
						} else if(itemResult.indexOf("RMP4") != -1) {
							itemResult="rmp4";
						} else if(itemResult.indexOf("TS") != -1) {
							itemResult="ts";
						} else if(itemResult.indexOf("TP") != -1) {
							itemResult="tp";
						} else if(itemResult.indexOf("TRP") != -1) {
							itemResult="trp";
						} else if(itemResult.indexOf("VOB") != -1) {
							itemResult="vob";
						} else if(itemResult.indexOf("WMV") != -1 || itemResult.indexOf("WINDOWS MEDIA") != -1) {
							itemResult="wmv";
						} else {
							itemResult="UNKNOWN";
						}
					}
					break;
				case 'smartvideocodec':
					var codecResult:Array=get_full_codec(titleXML,"video");
					var itemResult=codecResult.info;
					if(codecResult.old==true) {
						trace("video codec OLD "+itemResult);
						if(itemResult.indexOf("AVC") != -1) {
							itemResult="AVC";
						} else if(itemResult.indexOf("XVID") != -1) {
							itemResult="XVID";
						} else if(itemResult.indexOf("DIVX") != -1) {
							itemResult="DIVX";
						}else if(itemResult.indexOf("VC-1") != -1) {
							itemResult="VC1";
						}else if(itemResult.indexOf("H.264") != -1) {
							itemResult="H264";
						}else if(itemResult.indexOf("MPEG") != -1) {
							itemResult="MPEG";
						}else if(itemResult.indexOf("MICROSOFT") != -1) {
							itemResult="VC1";
						} else {
							if(itemResult.length>6) {
								itemResult="UNKNOWN";
							} else {
								itemResult=itemResult.toUpperCase();
							}
						}
					}
					break;
				case 'smartaudiocodec':
					var codecResult:Array=get_full_codec(titleXML,"audio");
					var itemResult=codecResult.info;
					if(codecResult.old==true) {
						trace("audio codec old "+itemResult);
						if(itemResult!="UNKNOWN") {
							itemResult=itemResult.toUpperCase();
							var split:Array=itemResult.split("/");
							if(StringUtil.beginsWith(split[0],"A_")) {
								return(split[0].substr(2));
							}

							var start:Number=split[0].indexOf("(");
							if(start != -1) {
								return(split[0].substr(0,start-1));
							}

							return(StringUtil.trim(split[0]));
						}
					}
					break;
				case 'flagcontainer':
					var itemResult:String=XPathAPI.selectSingleNode(titleXML, "/movie/container").firstChild.nodeValue.toString();
					if(itemResult!="UNKNOWN") {
						var check:String=StringUtil.remove(split[0],"-");
						if(check.indexOf("MATROSKA") != -1) {
							itemResult="mkv";
						} else if(check.indexOf("QUICKTIME") != -1) {
							itemResult="mov";
						} else if(check.indexOf("DVD") != -1) {
							itemResult="dvd";
						} else if(check.indexOf("WEB") != -1) {
							itemResult="web-dl";
						} else if(check.indexOf("FLV") != -1) {
							itemResult="flash";
						}
					}
					break;
				case 'flagvideocodec':
					var itemResult:String=XPathAPI.selectSingleNode(titleXML, "/movie/videoCodec").firstChild.nodeValue.toString().toUpperCase();
					//trace("video codec "+itemResult);
					if(itemResult!="UNKNOWN") {
						var split:Array=itemResult.split("/");
						var check:String=StringUtil.remove(split[0],"-");
						if(check.indexOf("DIVX") != -1 || check.indexOf("3VIX") != -1) {
							itemResult="divx";
						} else if(check.indexOf("XVID") != -1) {
							itemResult="xvid";
						} else if(check.indexOf("MPEG1") != -1) {
							itemResult="mpeg1video";
						} else if(check.indexOf("MPEG2") != -1) { // must be after theora
							itemResult="mpeg2video";
						} else if(check.indexOf("MPEG4") != -1 || check.indexOf("AVC") != -1) {
							itemResult="mpeg4video";
						} else if(check.indexOf("H263") != -1) {
							itemResult="h263";
						} else if(check.indexOf("H262") != -1) {
							itemResult="h262";
						} else if(check.indexOf("DVR") != -1) {
							itemResult="asf";
						} else if(check.indexOf("THEORA") != -1) {
							itemResult="oggtheora";
						} else if(check.indexOf("OGG") != -1) { // must be after theora
							itemResult="ogg";
						} else if(check.indexOf("REAL") != -1) {
							itemResult="real";
						} else if(check.indexOf("MICROSOFT") != -1) {
							itemResult="wmv";
						} else if(check.indexOf("VC1") != -1) {
							itemResult="wvc1";
						} else {
							itemResult="UNKNOWN";
						}
					}
					break;
				case 'flagaudiocodec':
					//var codecResult:Array=get_full_codec(titleXML,"video");
					//var itemResult=codecResult.info;
					var itemResult:String=XPathAPI.selectSingleNode(titleXML, "/movie/audioCodec").firstChild.nodeValue.toString().toUpperCase();
					//trace("audio codec "+itemResult);
					if(itemResult!="UNKNOWN") {
						var split:Array=itemResult.split("/");
						var check:String=StringUtil.remove(split[0],"-");
						if(check.indexOf("MP3") != -1) {
							itemResult="mp3";
						} else if(check.indexOf("AAC") != -1) {
							itemResult="aac";
						} else if(check.indexOf("FLAC") != -1) {
							itemResult="flac";
						} else if(check.indexOf("EAC3") != -1 || check.indexOf("EC3") != -1 || check.indexOf("AC3+") != -1) {
							itemResult="dolbydigitalplus";
						} else if(check.indexOf("AC3") != -1) { // must be below AC3+
							itemResult="dolbydigital";
						} else if(check.indexOf("DTSHD") != -1) {  // must be above DTS
							itemResult="dtsma";
						} else if(check.indexOf("DTS") != -1) {
							itemResult="dts";
						} else if(check.indexOf("TRUEHD") != -1) {
							itemResult="truehd";
						} else if(check.indexOf("ORBIS") != -1) {
							itemResult="vorbis";
						} else if(check.indexOf("PCM") != -1) {
							itemResult="pcm";
						} else if(check.indexOf("WMA") != -1 || check.indexOf("MICROSOFT") != -1) {
							itemResult="wmapro";
						} else {
							itemResult="UNKNOWN";
						}
					}
					break;
				case 'flagcertification':
					var itemResult:String=XPathAPI.selectSingleNode(titleXML, "/movie/certification").firstChild.nodeValue.toString().toLowerCase();
					itemResult=StringUtil.remove(itemResult,"-");
					itemResult=StringUtil.remove(itemResult,"_");
					itemResult=StringUtil.remove(itemResult," ");
					break;
				case 'flagchannels':
					var itemResult:String=XPathAPI.selectSingleNode(titleXML, "/movie/audioChannels").firstChild.nodeValue.toString().toUpperCase();
					if(itemResult!="UNKNOWN") {
						var split:Array=itemResult.split(" / ");
						return(split[0]);
					}
					break;
				case 'smartchannels':
					var itemResult:String=XPathAPI.selectSingleNode(titleXML, "/movie/audioChannels").firstChild.nodeValue.toString().toUpperCase();
					if(itemResult!="UNKNOWN") {
						//trace("itemResult "+itemResult);
						var split:Array=itemResult.split(" / ");
						//trace("split"+split[0]);
						var channels:Number=int(split[0]);
						//trace("channels"+channels);
						itemResult=channels.toString();
						if(channels>2) {
							channels--;
							itemResult=channels.toString()+".1";
						}
						//trace("itemResult "+itemResult);
					}
					break;
				case 'aspectyamj':
				case 'smartaspect':
				case 'flagaspect':
				case 'flagratio': // legacy from manual typo
					var aspect:String=XPathAPI.selectSingleNode(titleXML, "/movie/aspect").firstChild.nodeValue.toString();
					if(aspect=="UNKNOWN") return(aspect);

					var asparts:Array=aspect.split(":");
					var asp:Number=Number(asparts[0]);
					//trace("aspect: "+aspect+" asparts: "+asparts[0]+" asp: "+asp);
					if(aspect.length!=6) {
						if(asp > 2.710) {
							itemResult="2.76";
						} else if(asp > 2.625) {
							itemResult="2.66";
						} else if(asp > 2.570) {
							itemResult="2.59";
						} else if(asp > 2.485) {
							itemResult="2.55";
						} else if(asp > 2.415) {
							itemResult="2.42";
						} else if(asp > 2.405) {
							itemResult="2.41";
						} else if(asp > 2.395) {
							itemResult="2.40";
						} else if(asp > 2.370) {
							itemResult="2.39";
						} else if(asp > 2.275) {
							itemResult="2.35";
						} else if(asp > 2.100) {
							itemResult="2.20";
						} else if(asp > 1.925) {
							itemResult="2.00";
						} else if(asp > 1.815) {
							itemResult="1.85";
						} else if(asp > 1.765) {
							itemResult="1.78";
						} else if(asp > 1.705) {
							itemResult="1.75";
						} else if(asp > 1.610) {
							itemResult="1.66";
						} else if(asp > 1.530) {
							itemResult="1.56";
						} else if(asp > 1.465) {
							itemResult="1.50";
						} else if(asp > 1.400) {
							itemResult="1.43";
						} else if(asp > 1.350) {
							itemResult="1.37";
						} else {
							itemResult="1.33";
						}
					} else {
						itemResult=asp.toString();
						if(itemResult.length<4) itemResult=itemResult+"0";
					}
					if(field=="smartaspect") {
						itemResult=itemResult+":1";
					} else if(field=="aspectyamj"){
						itemResult=StringUtil.remove(itemResult,".");
					}
					break;
				case 'flagresolution':
					var resolution:String=XPathAPI.selectSingleNode(titleXML, "/movie/resolution").firstChild.nodeValue.toString();
					if(resolution=="UNKNOWN") return("UNKNOWN");
					var resparts:Array=resolution.split("x");
					var resx:Number=int(resparts[0]);
					var resy:Number=int(resparts[1]);
					// adjust for 3d
					if(resx>2559) { // SBS
						resx=resx/2;
					} else if((resx>1919 && resy>1080) || (resx>1279 && resy>1080)) { // TB
						resy=resy/2;
					}

					if(resx>1919) {
						itemResult="1080";
					} else if(resx>1279) {
						itemResult="720";
					} else if(resy>720) {
						itemResult="1080";
					} else if(resy>576) {
						itemResult="720";
					} else if(resy>540) {
						itemResult="576";
					} else if(resy>480) {
						itemResult="540";
					} else if(resy>360) {
						itemResult="480";
					} else if(resy>240) {
						itemResult="360";
					} else itemResult="240";
					break;
				case 'smartres':
					var resolution:String=XPathAPI.selectSingleNode(titleXML, "/movie/resolution").firstChild.nodeValue.toString();
					if(resolution=="UNKNOWN") return("UNKNOWN");
					var resparts:Array=resolution.split("x");
					var resx:Number=int(resparts[0]);
					var resy:Number=int(resparts[1]);
					//trace("original: "+resolution+" resx: "+resx+" resy: "+resy);
					if(resx>3849) {
						itemResult="3D1080";
					} else if(resx>2559) {
						itemResult="3D720";
					} else if(resx>1919 && resy>1080) {
						itemResult="3D1080";
					} else if(resx>1919 || resy==1080) {
						itemResult="HD1080";
					} else if(resx>1279 && resy>1080) {  // prevents false 3d720 when 720
						itemResult="3D720";
					}  else if(resx>1279 || resy==720) {
						itemResult="HD720";
					} else if(resy>719) {
						itemResult="HD4:3";
					} else itemResult="SD";
					break;
				case 'isextras':
					var xmlNodeList:Array = XPathAPI.selectNodeList(titleXML, "/movie/extras/extra");
					if(xmlNodeList.length<1) {
						itemResult="NO";
					} else {
						itemResult="YES";
					}
					break;
				case 'issubtitles':
					var itemResult:String=XPathAPI.selectSingleNode(titleXML, "/movie/subtitles").firstChild.nodeValue.toString().toUpperCase();
					if(itemResult=="UNKNOWN" || itemResult==null || itemResult==undefined) {
						itemResult="NO";
					} else {
						itemResult="YES";
					}
					break;
				default:  // straight process
					itemResult = artwork_vars(field,titleXML);

					if(itemResult==null) { // still didn't process yet
						if(StringUtil.beginsWith(field, "person")) {
							// process person variable
							itemResult=person_vars(field,titleXML);
						} else if(StringUtil.beginsWith(field, "multi-")) {
							itemResult=multi_vars(field,titleXML);
						} else {
							if(field.indexOf("@") != -1) {
								var newfield:Array=field.split("@");
								itemResult = XPathAPI.selectSingleNode(titleXML, "/movie/"+newfield[0]).attributes[newfield[1]].toString();
							} else {
								if(field=='birthplace') {
									trace("!!!!!! "+titleXML);
								}
								itemResult = XPathAPI.selectSingleNode(titleXML, "/movie/"+field).firstChild.nodeValue.toString();
							}
						}
					}
			}
		} else {
			////trace("titleXML is missing/null/empty");

			//trace(titleXML);
		}
		////trace("getData "+field+" result: "+itemResult);
		return(itemResult);
	}


	private function get_full_codec(titleXML,field) {
		trace("extended codec check for "+field);

		var xmlNodeList:Array = XPathAPI.selectNodeList(titleXML,"/movie/codecs/"+field+"/codec");
		var itemResult:String=XPathAPI.selectSingleNode(titleXML, "/movie/"+field+"Codec").firstChild.nodeValue.toString();

		if(xmlNodeList.length<1) {
			trace(".. no extended codec info, using "+itemResult);
			return({old:true,info:itemResult});
		}


		var codec:String=XPathAPI.selectSingleNode(xmlNodeList[0], "/codec").firstChild.nodeValue.toString().toUpperCase();
		var codecformat:String=XPathAPI.selectSingleNode(xmlNodeList[0], "/codec").attributes.format.toString().toUpperCase();
		var codecprofile:String=XPathAPI.selectSingleNode(xmlNodeList[0], "/codec").attributes.formatProfile.toString().toUpperCase();
		var tempprofile=codecprofile.split(" / ");
		codecprofile=tempprofile[0];

		trace(".. codec "+codec);
		trace(".... format "+codecformat);
		trace(".... profile "+codecprofile);

		if(field=="audio") {
			if(codec.indexOf("DTS") != -1) {
				trace(".. variation of dts");
				switch(codecprofile) {
					case "96/24":
						return({info:"DTS9624"});
						break;
					case "ES":
						return({info:"DTSES"});
						break;
					case "MA":
						return({info:"DTSHDMA"});
						break;
					case "HRA":
						return({info:"DTSHDHRA"});
						break;
					default:
						return({info:"DTS"});
						break;
				}
			} else if(codecformat.indexOf("E-AC-3") != -1) {
				return({info:"DDPLUS"});
			} else if(codec.indexOf("AC-3") != -1) {
				if(codecprofile=="TRUEHD") {
					return({info:"TRUEHD"});
				} else {
					return({info:"AC3"});
				}
			} else if(codecformat.indexOf("MPEG AUDIO") != -1) {
				if(codecprofile=="LAYER 3") {
					return({info:"MP3"});
				} else {
					return({info:"MPEG"});
				}
			} else if(codecformat.indexOf("WMA") != -1) {
				return({info:"WMA"});
			} else {
				return({old:true, info:itemResult});
			}
		}
		return({old:true,info:itemResult});
	}

	private function multi_vars(field,titleXML) {
		trace("multi processing: "+field);

		var person:Array=field.split("-");
		if(person.length<4 || person.length>5) {
			trace("not enough elements");
			return("UNKNOWN");
		}

		trace(titleXML);
		trace("looking for: "+person[1]);

		var which:Number=int(person[2]);

		var xmlNodeList:Array = XPathAPI.selectNodeList(titleXML,person[1]);
		trace(xmlNodeList)
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

	private function process_TitleData_xpath_multi(xpexpr:String,xmlField:String,titleXML:XMLNode,howmany):String {
		var itemResult:String="";

		////trace("multiprocess");

		// make sure we're good to contine
		if(titleXML != null) {
			//trace(titleXML);
			var xmlNodeList:Array = XPathAPI.selectNodeList(titleXML, xpexpr);
			var xmlDataLen:Number = xmlNodeList.length;
			if (xmlDataLen != 0) {
				var keepData:Array=new Array();
				var keep:String;
				for(var i=0;i<howmany&&i<xmlDataLen;i++) {
					keepData[i] = XPathAPI.selectSingleNode(xmlNodeList[i], "/"+xmlField).firstChild.nodeValue.toString();
					//trace(keepData[i]);
				}
				itemResult=keepData.join(", ");
				//trace(itemResult);
			} else itemResult="UNKNOWN";
			//trace(itemResult);
		} else {
			////trace("multi titleXML is missing/null/empty");
		}
		return(itemResult);
	}

	private function process_TitleData_xpath(xpexpr:String,titleXML:XMLNode, attc):String {
		var itemResult:String=null;
		if(attc==undefined || attc==null) {
			itemResult = XPathAPI.selectSingleNode(titleXML, xpexpr).firstChild.nodeValue.toString();
		} else {
			itemResult = XPathAPI.selectSingleNode(titleXML, xpexpr).attributes[attc].toString();
		}

		return(itemResult);
	}

	private function count_TitleData_xpath(xpexpr:String,titleXML:XMLNode):Number {
		var xmlNodeList:Array = XPathAPI.selectNodeList(titleXML, xpexpr);
		var itemResult:Number = xmlNodeList.length;
		if(itemResult==undefined) itemResult=0;

		return(itemResult);
	}

// **** artwork variable routines
	private function artwork_vars(field:String,titleXML:XMLNode):String {
		var itemResult=null;
		var ischeck:Boolean=false;

		// normal or is
		if(StringUtil.beginsWith(field, "is")) {
			ischeck=true;
			var newfield=field.slice(2);
		} else var newfield=field;

		itemResult=artwork_newscanner(newfield,titleXML);

		// if we don't process this, get out now.
		if(itemResult == null) return(null);

		if(ischeck) {
			if(itemResult == undefined || itemResult == "" || itemResult == "UNKNOWN") return("false");
			return("true");
		} else {
			return(itemResult);
		}
	}

	private function artwork_newscanner(field:String,titleXML:XMLNode):String {
		// figure out what we're looking for.
		var smart:Boolean=false;
		var kind:String=null;
		var which:Number=null;
		var size:String=null;


		// smart
		if(StringUtil.beginsWith(field, "smart")) {
			//trace(".. is smart");
			smart=true;
			var newfield=field.slice(5);
		} else var newfield=field;

		// break out the pieces
		var whichstart:Number=0;
		var sizestart:Number=0;
		for (var i:Number = 0; i < newfield.length; i++){
			if(!isNaN(newfield.charAt(i))) {
				sizestart=i+1;
				if(whichstart==0) whichstart=i;
			} else {
				if(sizestart!=0) break;
			}
        }

		if(sizestart!=0 && whichstart!=0) {
			size=newfield.slice(sizestart);
			kind=newfield.substring(0,whichstart);
			which=newfield.substring(whichstart,sizestart);
		} else kind=newfield;

		// new artwork scanner not in use
		if(!Background.artworkscanner) {
			// switch kind
			switch(kind) {
				case 'poster':
				case 'thumbnail':
				case 'banner':
				case 'fanart':
					if(kind=="poster" and size=="small") kind="thumbnail";
					if(smart) return(artwork_legacy("smart"+kind,titleXML));
					return(artwork_legacy(kind,titleXML));
					break;
				case 'clearart':
				case 'clearlogo':
				case 'tvthumb':
				case 'seasonthumb':
					return("UNKNOWN");
				default:
					return(null);  // probably not a variable for us.
			}
		}

		// Artwork scanner processing

		// legacy var fixing.
		if(which==null) {
			which=1;
			var legacy=true;

			if(kind=="thumbnail") {
				kind="poster";
				size="small";
			} else {
				size="medium";
			}
		}

		// validate we do this
		switch(kind) {
			case 'poster':
				var findkind="Poster";
				break;
			case 'fanart':
				var findkind="Fanart";
				break;
			case 'banner':
				var findkind="Banner";
				break;
			case 'tvthumb':
				var findkind="TvThumb";
				break;
			case 'clearart':
				var findkind="ClearArt";
				break;
			case 'clearlogo':
				var findkind="ClearLogo";
				break;
			case 'seasonthumb':
				var findkind="SeasonThumb";
				break;
			default:	// we don't support this type
				return(null);
		}

		return(artwork_new(titleXML, findkind, which, size.toUpperCase(), legacy, smart));
	}

	private function artwork_new(titleXML:XMLNode, kind, which, size, legacy, smart) {
		var startsize:Number=0;
		switch(size) {
			case 'MEDIUM':
				startsize=1;
				break;
			case 'LARGE':
				startsize=2;
				break;
			case 'ORIGINAL':
				startsize=3;
				break;
		}

		// get the xml
		var xmlNodeList:Array = XPathAPI.selectNodeList(titleXML, "/movie/artwork/"+kind);
		//trace("found "+xmlNodeList.length);

		if(xmlNodeList.length>0) {
			if(xmlNodeList.length<which) {
				which=xmlNodeList.length-1;
			} else {
				which--;
			}

			for (var i:Number = which; i >= 0; i--) {
				//trace("checking "+i);
				for(var j=startsize;j<4;j++) {
					//trace(".. "+this.artsize[j]);
					var check=XPathAPI.selectSingleNode(xmlNodeList[i], "/"+kind+"/"+this.artsize[j]).firstChild.nodeValue.toString();
					//trace(".... found: "+check);
					if(check!=undefined && check!=null && check !="") return(check);
					if(!smart && legacy!=true) break;
				}
				if(!smart) break;
			}
		}
		return("UNKNOWN");
	}

	private function artwork_legacy(field:String,titleXML:XMLNode):String {
		var itemResult:String=null;

		// check the smarts
		switch(field) {
			case 'smartthumbnail':
			case 'smartposter':
				if(this.get_yvars(titleXML, "posterURL") == "UNKNOWN") return("UNKNOWN");
				break;
			case 'smartbanner':
				if(this.get_yvars(titleXML, "bannerURL") == "UNKNOWN") return("UNKNOWN");
				break;
			case 'smartfanart':
				if(this.get_yvars(titleXML, "fanartURL") == "UNKNOWN") return("UNKNOWN");
				break;
			default:
				break;
		}

		// then the normals
		switch(field) {
			case 'thumbnail':
			case 'smartthumbnail':
				itemResult = this.get_yvars(titleXML, "thumbnail");
				break;
			case 'poster':
			case 'smartposter':
				itemResult = this.get_yvars(titleXML, "detailPosterFile");
				break;
			case 'fanart':
			case 'smartfanart':
				itemResult = this.get_yvars(titleXML, "fanartFile");
				break;
			case 'banner':
			case 'smartbanner':
				itemResult = this.get_yvars(titleXML, "bannerFile");
				break;
			default:
				return(null);  // we don't process these variables
				break;
		}

		if(itemResult==undefined) return("UNKNOWN");
		return(itemResult);
	}

	private function get_yvars(titleXML:XMLNode,field:String):String {
		return(XPathAPI.selectSingleNode(titleXML, "/movie/"+field).firstChild.nodeValue.toString());
	}

	public function state_data(field:String) {
		switch(field) {
			case 'indextypelist':
				return(this.currentindexcategory);
			default:
				return(null);
		}
	}
}