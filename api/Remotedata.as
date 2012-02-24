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
import ev.Cfile;
import api.dataYAMJ;
import api.dataYAMJ2;
import api.dataRSS;
import tools.Preloader;
import mx.xpath.XPathAPI;
import mx.utils.Delegate;

class api.Remotedata {
	// state stuff
	private var fn:Object = null;
	private var Callback:Function = null;
	private var loading:Boolean=null;
	private var reloading:Boolean=null;

	// prefetch
	private var prefetchInterval=null;
	private var prefetchOn:Boolean=null;
	private var prefetchdelay:Number=null;

	// fetching variables for this instance
	private var dataprefetch:Number=null;
	private var datatotal:Number=null;
	private var keepxml:Boolean=null;
	private var lastdirection:Number=null;
	private var lastknown:Number=null;

	// paging info
	private var pageData:Array=null;   	// the data we storing.
	private var pageCount:Array=null;  	// titles on each page
	private var pageAdded:Array=null;  	// pages added to menu
	private var pageTCount:Number=null; // how many titles loaded in total
	private var pagePer:Number=null;    // how many titles should be in each page
	private var pageOne:Number=null;	  	// the lowest page currently loaded
	private var pageLast:Number=null;  	// the highest page loaded
	private var pageLoaded:Number=null;	// pages in memory
	private var pageLastLoaded:Number=null;	// page last loaded
	private var newInit:Boolean=null;	// is this the init load?

	// current index info
	private var segDetails:Object=null;
	private var datasource=null;
	public var totalTitles:Number=null;
	public var indexName:String=null;
	public var indexOriginalName:String=null;
	public var indexType:String=null;
	public var indexURL:String=null;
	private var totalPages:Number=null;
	private var episodedata:Array=null;
	private var visiblefirst:Number=null;
	private var visiblelast:Number=null;
	public var peopleXML:XML=null;

	function Remotedata() {
		this.fn = {harddataloaded:Delegate.create(this, this.harddataloaded),
				   prefetch:Delegate.create(this, this.prefetch),
				   add_page_data:Delegate.create(this, this.add_page_data),
				   onLoadInfo:Delegate.create(this, this.onLoadInfo),
				   enableprefetch:Delegate.create(this, this.enablePrefetch),
				   hardepisodedata:Delegate.create(this, this.hardepisodedata)
				  };
	}

	public function cleanup() {
		this.full_reset();
	}

	private function full_reset() {
		clearInterval(this.prefetchInterval);
		this.prefetchInterval=null;
		this.prefetchOn=false;
		this.prefetchdelay=3;

		// stop the datasource
		this.datasource.cleanup();
		this.datasource=null;

		this.Callback=null;
		delete this.segDetails;
		this.segDetails=null;

		// delete it out
		this.keepxml=null;
		delete this.pageData;
		delete this.pageCount;
		delete this.pageAdded;

		delete this.episodedata;
		this.episodedata=null;

		// prep it up.
		this.pageData=new Array();
		this.pageCount=new Array();
		this.pageAdded=new Array();
		this.pageTCount=0;
		this.pageOne=0;
		this.pageLast=0;
		this.pageLoaded=0;
		this.pageLastLoaded=0;
		this.lastknown=0;
		this.pagePer=0;
		this.loading=false;
		this.reloading=false;

		this.totalTitles=null;
		this.indexName=null;
		this.indexType=null;
		this.indexOriginalName=null;
		this.totalPages=null;
		this.lastdirection=1;
		this.indexURL=null;
		this.visiblefirst=1;
		this.visiblelast=1;

		this.dataprefetch=Common.evSettings.dataprefetch;
		this.datatotal=Common.evSettings.datatotal;

		this.newInit=true;
	}

	public function init(segDetails:Object,callBack:Function):Void {
		// get ready
		this.full_reset();

		this.Callback=callBack;
		this.segDetails=segDetails;

		trace("remotedata init");

		// prefetch checks
		if(this.dataprefetch<=0 || this.dataprefetch==null || this.dataprefetch==undefined) this.dataprefetch=1;
		if(this.datatotal<=0 || this.datatotal==null || this.datatotal==undefined) this.datatotal=3;

		// trace("prefetch set to "+this.dataprefetch);
		// trace("totalpages set to "+this.datatotal);

		this.loading=true;
		this.newInit=true;

		if(this.segDetails.eskin==undefined) {  // preload!!
			switch(this.segDetails.kind) {
				case 'INDEX':
					// trace("RD: index preload of "+this.segDetails.file);
					this.indexURL=this.segDetails.file;
					this.datasource=new dataYAMJ();
					this.datasource.getIndexInfo(this.indexURL, this.fn.onLoadInfo);
					break;
				case 'PRELOAD':
					trace("RD: preload for "+this.segDetails.xml.file);
					switch(this.segDetails.xml.info) {
						case 'menulist':
						case 'userlist':
						case 'userlist2':
						case 'userlist3':
						case 'userlist4':
							trace(this.segDetails.xml.info+" for "+this.segDetails.xml.title);
							this.indexType=this.segDetails.xml.info.toUpperCase();
							this.indexName=this.segDetails.xml.title;
							this.datasource=new Cfile();
							this.datasource.indexdata(this.segDetails.xml.arraydata,this.fn.harddataloaded);
							break;
						default:
					}
					break;
				default:
					trace("RD: unknown preload");
					break;
			}
		} else if(Common.eskinmaster[this.segDetails.eskin][this.segDetails.file].segments[this.segDetails.member].settings.control != undefined) {
			// trace("rd: control file "+Common.eskinmaster[this.segDetails.eskin][this.segDetails.file].segments[this.segDetails.member].settings.control);

			// prep control
			this.datasource=new Cfile();

			if(Common.eskinmaster[this.segDetails.eskin][this.segDetails.file].segments[this.segDetails.member].settings.control == "POPUP") {
				// trace("popup data: "+this.segDetails.popup);
				this.datasource.staticdata(this.segDetails.popup,this.fn.harddataloaded);
			} else {
				// start control processing
				this.datasource.load(this.segDetails.erun.process_variable(Common.eskinmaster[this.segDetails.eskin][this.segDetails.file].segments[this.segDetails.member].settings.control),this.fn.harddataloaded);
			}
		} else if(this.segDetails.xml != undefined) {
			trace("RD: xml load, source: "+Common.eskinmaster[this.segDetails.eskin][this.segDetails.file].segments[this.segDetails.member].settings.datasource);


			switch(Common.eskinmaster[this.segDetails.eskin][this.segDetails.file].segments[this.segDetails.member].settings.datasource) {
				case 'episodes':
					this.datasource=new dataYAMJ();
					this.indexType="EP";
					if(this.segDetails.tvset!=undefined && Common.evSettings.epmerge=="true") {
						trace("we have tvset xml");
						Preloader.update("Loading data",false);
						this.datasource.episodeswithset(this.segDetails.xml, this.segDetails.tvset, this.fn.hardepisodedata);
					} else {
						this.datasource.episodes(this.segDetails.xml, this.fn.hardepisodedata);
					}
					break;
				case 'extras':
					this.datasource=new dataYAMJ();
					this.indexType="XTRA";
					this.datasource.extras(this.segDetails.xml, this.fn.harddataloaded);
					break;
				case 'mpartsall':
					this.datasource=new dataYAMJ();
					this.indexType="PARTS";
					this.datasource.mpartsall(this.segDetails.xml, this.fn.harddataloaded);
					break;
				case 'people':
					this.datasource=new dataYAMJ2();
					this.indexType="PEOPLE";
					this.datasource.people(this.segDetails.xml, this.fn.harddataloaded);
					break;
				default:
					// trace("unknown datasource");
					break;
			}
		} else {
			switch(Common.eskinmaster[this.segDetails.eskin][this.segDetails.file].segments[this.segDetails.member].settings.datasource) {
				case 'lundman':
					Preloader.update(Common.evPrompts.loading);
					this.datasource=new dataRSS();
					this.indexType="TRAILERS";
					this.indexName="Trailers";
					trace("Aux "+this.segDetails.aux);
					trace("feed "+this.segDetails.data.feed);
					this.datasource.lundman(this.segDetails.aux.feed, this.fn.harddataloaded);
					break;
				default:
					trace("rd: don't know what to do");
					break;
			}
		}
	}

// **************** HARD DATA ADD *********************

	// episode extras
	private function hardepisodedata(status:String,message:String,data:Array) {
		Preloader.clear();
		if(status==null) {
			this.episodedata=data;
			this.harddataloaded(status,message,data);
		} else {
			trace(status+" : " + message);
			this.Callback(status, message);
		}
	}

	// single array to prefetch processing
	private function harddataloaded(status:String,message:String,data:Array) {
		// trace("harddataloaded");

		if(status==null) {
			// trace(".. processing data");

			// set prefetch to only clear images from index
			this.keepxml=true;
			this.prefetchOn=null;

			// prep
			var addto=new Array();
			this.totalPages=2;  // add needs this to work, we'll have real count when we finish adding
			var page:Number=1;
			var count:Number=0;
			var total:Number=0;
			this.totalTitles=data.length;

			// loop if we need too
			if(data.length>20) {
				for(var i=0;i<this.totalTitles;i++) {
					// total count
					total++;

					// add it
					addto.push(data[i]);

					// check the page status and add if ready
					if(count==19) {
						add_page_data(addto,page);
						count=0;
						page++;
						this.totalPages++;  // should always be larger than page for add to work
						addto=new Array();
					} else {
						count++;
					}
				}
			} else { // just add if we don't
				addto=data;
				total=data.length;
			}

			// if we still have data to add (less than 20 tiles in the last page)
			if(addto.length>0) {
				add_page_data(addto,page);
			} else page--;  // this page was blank, drop page count back

			// calculate the real totals
			this.totalPages=page; // adjust the total pages
			trace(this.totalPages+" pages");
			this.totalTitles=total;
			trace(this.totalTitles+" items added");

			if(this.totalPages==0) {
				this.Callback("ERROR",Common.evPrompts.segment+" "+Common.evPrompts.enodata);
			} else {
				if(this.segDetails.kind == "PRELOAD") {
					this.Callback("PRELOAD");
				} else {
					this.Callback("DATAWAIT",null);
				}
			}
		} else {
			trace(status+" : " + message);
			this.Callback(status, message);
		}
	}

// ****************** JB/XML DATA PAGE ADD******************
	private function onLoadInfo(indexXML:Array,indexName:String,itype:String,totalPages:Number,total:Number,originalName:String) {
		//// trace("back from info");

		// proceed if good load
		if(indexXML!=null) {
			// save the peoplexml
			if(this.peopleXML==null) {
				this.peopleXML=this.datasource.personXML;
			}

			// set vars
			this.totalTitles=total;
			this.indexName=indexName;
			this.indexType=itype;
			this.totalPages=totalPages;
			this.indexOriginalName=originalName;

			/*if(this.totalTitles < 11000) {
				// trace("total within reason, keeping xml in memory");
				this.keepxml=true;
			}*/

			// check that our prefetch settings are even usable for this index
			var checklength=indexXML.length;

			// are there any titles in the index
			if(checklength<1) {
				this.Callback("ERROR",Common.evPrompts.enodatain+" "+indexName);
				return;
			}

			if(checklength < 14 && this.totalPages > 1) {
				// trace("auto-adjusting prefetch settings: index has "+this.totalPages+" page and "+checklength+" tiles");
				this.dataprefetch=Math.ceil(14/checklength);
				this.datatotal=this.dataprefetch*2;
				// trace("new settings: prefetch "+this.dataprefetch+" totalpages"+this.datatotal);
			}

			//// trace("CHECK: "+itype);
			// add page data
			this.add_page_data(indexXML, 1);
		} else {
			// trace("error:"+indexName);
			this.Callback("ERROR",indexName);
		}
	}

// ****************** ADD/REMOVE PAGES *******************
	private function add_page_data(thedata:Array,whichpage:Number) {
		if(thedata!=null) {
			this.pageData[whichpage]=thedata;
			this.pageCount[whichpage]=thedata.length;
			this.pageTCount=this.pageTCount+thedata.length;
			this.pageLastLoaded=whichpage;
			//this.pageLoaded=this.pageData.length;

			// trace("added: "+this.pageCount[whichpage]+" titles to page "+whichpage);

			if(this.pagePer==0) {
				this.pagePer=this.pageCount[whichpage];
				// trace("this index is "+this.pagePer+" titles per page");
			}

			// find the first and last page
			this.first_last();

			// start the index drawing here (if we're not a new load)
			if(this.prefetchOn==true) {        // if prefetch is on, send it over
				// send new data to index
				// trace("sending data to index");
				this.senddata(whichpage);
			} else {
				// trace("index still new, waiting for index to ask for data");
			}

	/*
			// page report
			var report:String="";
			for(var i=1;i<=this.totalPages;i++) {
				if(this.pageCount[i] != null && this.pageCount[i] != undefined) {
					report=report+" "+i+":"+this.pageCount[i];
				} else {
					report=report+" "+i+":EMPTY";
				}
			}
			trace("PAGE REPORT: "+report);
*/

			//this.newInit=false;								// we're done with our init load
			this.loading=false;								// safe for someone else to load now

			// if we're not prefetching yet, we must be page loading so get it on the screen
			if(this.prefetchOn==false) {
				this.Callback("PRELOAD",this.indexType);		// start the index drawing
			} //else this.prefetchdelay++;  // slow us down a hair

			if(this.reloading==true) {  // reloading
				// re-enable prefetch (if it wasn't off before)
				this.prefetchInterval = setInterval(this.fn.prefetch,350);

				// signal we're reloaded
				this.Callback("reloaded");
				this.reloading=false;
			}
		} else {
			this.Callback("ERROR",Common.evPrompts.enodatain+" "+whichpage);
			//// trace("ERROR!!!!!: "+whichpage);
		}
	}

	// requests from skin for data come in here. (only happens on first load)
	public function adddata():Void {
		// trace("request for draw data");
		// find not added media
		for(var i=this.pageOne;i<=this.pageLast;i++) {
			if(this.pageAdded[i]==null) {
				this.senddata(i);
			}
		}

		// prefetch may begin
		this.prefetchOn=true;
	}

	private function removedata(whichpage:Number, force:Boolean):Void {
		// trace("removing page "+whichpage);

		// make sure the user isn't on this page.
		//var where=Math.floor(this.lastknown/this.pagePer+1);
		if(whichpage>=this.visiblefirst && whichpage<=this.visiblelast && force != true) {
			trace("aborting remove, user is on this page");
			return;
		}

		this.loading=true;
		// send the clear
		var offset=(whichpage-1)*this.pagePer;
		this.Callback("remove", null, null, {page:whichpage, offset:offset, length:this.pageCount[whichpage], keepdata:this.keepxml});

		if(this.keepxml != true) {
			// trace("keep xml is off");
			// remove data and change counters
			this.pageTCount=this.pageTCount-this.pageCount[whichpage];
			this.pageData[whichpage]=null;
			this.pageCount[whichpage]=null;

			// remove the field
			this.pageAdded[whichpage]=null;

			// find first and last again
			this.first_last();
			//this.pageLoaded=this.pageData.length;
		} else this.pageAdded[whichpage]=1;

		// relax a moment
		this.prefetchdelay=1;
		this.loading=false;
	}

	public function senddata(page:Number) {
		// trace("page to be added: "+page);
		if(this.pageData[page]!=null) {
			//figure out offset.
			var offset=(page-1)*this.pagePer;
			// trace("... offset should be "+offset);
			// mark it added
			this.pageAdded[page]=2;

			// send the page
			this.Callback("add", null, this.pageData[page], {page:page, offset:offset});
		} else {
			// trace("cannot add this page, it's not loaded yet");
		}
	}

	private function first_last() {
		// find the first and last
		var pageOne=0;
		var pageLast=0;
		var found=0;
		for(var i=1;i<=this.totalPages;i++) {
			if(this.pageCount[i] != null && this.pageCount[i] != -1) {		// -1 is page prefetching
				found++;
				if(pageOne==0) {
					pageOne=i;
				} else pageLast=i;
			}
			//if(this.pageCount[i] == null && pageOne != 0 && pageLast !=0) break; // we're done
		}
		if(pageLast==0) pageLast=pageOne;

		this.pageOne=pageOne;
		this.pageLast=pageLast;
		this.pageLoaded=found;

		//// trace("one: "+this.pageOne+" last: "+this.pageLast+" total pages="+this.pageLoaded+" total titles:"+this.pageTCount);
	}

// ****************** PREFETCH **********************
	public function cursormoved(who, direction, start, end) {
		// if this is an auto-check, make sure we're on the page and moving first
		if(direction == undefined) {
			if(this.lastdirection==0 || this.lastdirection==null) {
				this.lastdirection=1;
			}
		} else this.lastdirection=direction;

		if(this.prefetchInterval==null) this.enablePretchDelayed();
		this.lastknown=who;

		// targeted prefetch
		this.visiblefirst=Math.floor(start/this.pagePer+1);
		this.visiblelast=Math.floor(end/this.pagePer+1);
	}

	// the called regularrly prefetch routine
	private function prefetch() {
		if(this.loading == true) return;   // if we're loading we can't do anything so exit out

		if(this.prefetchOn==true) {
			//// trace("prefetch checking");

			// LOAD CHECK
			// is there anything left to load?
			if(this.pageLoaded != this.totalPages) {
				//// trace("prefetch: not fully loaded yet");
				if(this.newInit==true && this.pageLoaded < this.datatotal && this.lastknown<20) {					// if we're still on first load and theres more room
					prefetch_load(this.pageLast+1);		// grab the next page
					this.prefetchdelay=1; 					// slow it down a little
					//trace("newinit check");
				} else {
					//trace("new page check");
					// NORMAL CHECK FOR POSITION
					this.newInit=false;
					this.prefetch_load_check();
				}
			} else {
				this.newInit=false;
			}

			// UNLOAD CHECK
			// should we wait?
			if(this.prefetchdelay>0) {
				this.prefetchdelay--;
				//trace('prefetchdelay '+this.prefetchdelay);
				return;
			}

			// make sure we didn't start loading or delayed
			if(this.loading==true) {
				//trace("STILL LOADING");
				return;
			}

			// do we have too much?
			this.prefetch_unload_check();

		}	//// else  trace("prefetched skipped, new init still");
	}
	private function prefetch_unload_check() {
		// do we have too much?
		if(this.pageLoaded > this.datatotal) {
			//trace("unload checking");
			// where are they
			var where=Math.floor(this.lastknown/this.pagePer+1);
			var cutoff=0;

			switch(this.lastdirection) {
				case 1: // user is headed forward
					//trace("direction 1");
					cutoff=where-2;
					if(cutoff > 0) {
						//trace("looking lower for pages");
						for(var i=1;i<=cutoff;i++) {
							if(this.pageAdded[i]==2) {
								//trace("found page "+i+" to remove");
								this.removedata(i);
								return;
							}
						}
					}

					// check the other way if we made it this far
					if(this.dataprefetch<2) {
						cutoff=where+2;
					} else {
						cutoff=where+this.dataprefetch;
					}

					if(cutoff <= this.totalPages) {
						//trace("looking higher for pages");
						for(var i=this.totalPages;i>=cutoff;i--) {
							if(this.pageAdded[i]==2) {
								//trace("found page "+i+" to remove");
								this.removedata(i);
								return;
							}
						}
					}
					break;
				case 2: // user is headed backwords
					//trace("direction 2");
					cutoff=where+2;
					if(cutoff <= this.totalPages) {
						//trace("looking higher for pages");
						for(var i=this.totalPages;i>=cutoff;i--) {
							if(this.pageAdded[i]==2) {
								//trace("found page "+i+" to remove");
								this.removedata(i);
								return;
							}
						}
					}

					// if we made it this far, look the other direction
					if(this.dataprefetch<2) {
						cutoff=where-2;
					} else {
						cutoff=where-this.dataprefetch;
					}

					if(cutoff > 0) {
						//trace("looking lower for pages");
						for(var i=1;i<=cutoff;i++) {
							if(this.pageAdded[i]==2) {
								//trace("found page "+i+" to remove");
								this.removedata(i);
								return;
							}
						}
					}
					break;
			}
		/*	trace("no pages to unload but needed "+where);

			// page report
			var report:String="";
			for(var i=1;i<=this.totalPages;i++) {
				if(this.pageCount[i] != null && this.pageCount[i] != undefined) {
					report=report+" "+i+":"+this.pageCount[i];
				} else {
					report=report+" "+i+":EMPTY";
				}
			}
			trace("PAGE REPORT: "+report);			*/
		} else {
			//trace("this.pageLoaded "+this.pageLoaded);
		}
	}

	private function prefetch_load_check() {
		//// trace("prefetch load check");

		// skip if we're fully loaded
		if(this.pageLoaded == this.totalPages) return;

		// where are they
		var where=Math.floor(this.lastknown/this.pagePer+1);

		//// trace("cursor is on page "+where);

		// make sure the cursor is on is good
		this.prefetch_load(where);
		if(this.loading==true) return;

		// make sure the other visible pages are good
		for(var ll=this.visiblefirst;ll<=this.visiblelast;ll++) {
			// skip what's already checked or outside page boundries
			if(ll<1 || ll==where || ll>this.totalPages) continue;

			this.prefetch_load(ll);
			if(this.loading==true) return;
		}

		// normal around us logic if still room to load more
		if(this.loading==true) return;

		// make sure teh page after us is ok
		check=where+1;
		if(check<=this.totalPages) this.prefetch_load(check);
		if(this.loading==true) return;

		// make sure the page before us is good (after to be checked)
		var check=where-1;
		if(check>0) this.prefetch_load(check);
		if(this.loading==true) return;


		// CHECK THE PREFETCH SETTING PAGE
		if(this.dataprefetch==1) return;  // skip if we already checked this distance

		switch(this.lastdirection) {
			case 1:
				//// trace("..cursor moving forward");
				check=where+this.dataprefetch;
				break;
			case 2:
				//// trace("..cursor moving backwords");
				check=where-this.dataprefetch;
				break;
		}

		//// trace("next page checking page "+check);

		// are we already at the end in this direction
		if(check<1 || check>this.totalPages) {
			//// trace("near the end, prefetch not needed");
			return;
		}

		// load it up!
		this.prefetch_load(check);
	}

	private function prefetch_load(thisPage:Number) {
		if(this.loading==true) return;
		if(this.pageCount[thisPage] == null) {
			trace("page "+thisPage+" loading..");
			// mark it loading
			this.pageCount[thisPage]=-1;
			// load it
			this.loading=true;
			this.datasource.getData(null,thisPage,this.fn.add_page_data);
		}
	}

	public function imageonpage(onpage:Number) {
		this.pageAdded[onpage]=2;
	}

	public function enablePrefetch() {
		// enable prefetch
		this.prefetchInterval = setInterval(this.fn.prefetch,365);
	}

	public function enablePretchDelayed() {
		_global["setTimeout"](this.fn.enableprefetch, 825);
		trace("delayed prefetch");
	}

	public function disablePretch() {
		clearInterval(this.prefetchInterval);
	}

// ****************** data lookup **********************
	public function process_JBData(field:String,who:Array,howmany:Number):String {
		// trace("data lookup page "+who.page+" element "+who.element);

		return(this.datasource.process_data(field,this.pageData[who.page][who.element],howmany));
	}

	public function get_data(who:Array):XMLNode {
		trace("page "+who.page+" element "+who.element);
		trace("..  check: "+this.pageData[who.page][who.element]);

		return(this.pageData[who.page][who.element]);
	}

	public function get_episodedata() {
		return(this.episodedata);
	}

	public function get_remote_details(field:String):String {
		switch(field) {
			case 'testing':
				// remote data for some reason we can't get from direct var will go here
				return(null);
			default:
				return(this.datasource.state_data(field));
		}
	}
}