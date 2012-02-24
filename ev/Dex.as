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
import api.Remotedata;
import api.RemoteControl;
import tools.Preloader;
import mx.utils.Delegate;
import mx.xpath.XPathAPI;

class ev.Dex {
	// screen stuff
	private var parentMC:MovieClip = null;
	private var mainMC:MovieClip = null;

	// global stuff
	private var fn:Object = null;
	private var callback:Function = null;
	private var mysegment:Number=null;
	private var segdetails:Object=null;
	private var indexActive:Boolean=null;
	public var delaystart:Boolean=null;

	// data
	private var remotedata:Remotedata=null;

	// menu
	private var menuSettings:Object = null;
	private var indexRefer:Array=null;
	private var menuData:Array = null;
	private var menuCursor:Number=null;
	private var menuTotal:Number=null;
	private var menuFirst:Number=null;
	private var menuDirection:Number=null;
	private var menuTileDepth:Number=null;
	private var menuLastPos:Object=null;
	private var menuActiveMore:Boolean=null;
	private var activedrawing:Boolean=false;

	// hyperscroll stuff
	private var hyperscroll:Number = null;     // the hyperscroll counter
	private var hyperscrolllast:Number = null; // the hyperscroll last counter
	private var hyperInterval=null;			    // the hyperscroll interval
	private var hyperScreen:Boolean=null;
	private var skinBusy:Boolean=null;
	private var lastdrawn:Number=null;
	private var hyperidle:Number=null;
	private var hypercycle:Number=null;

	private var hypersetting:Object=null;

// ******************** INIT **********************

	public function create(parentMC:MovieClip, mySegment:Number, segDetails:Object,callback:Function):Void {
		// reset our variables
		this.cleanup();

		this.fn = {onremotedata:Delegate.create(this, this.onremotedata),
				   hyperCheck:Delegate.create(this,this.hyperCheck),
				   onKeyDown:Delegate.create(this, this.onKeyDown),
				   get_ev_data:Delegate.create(this,this.get_ev_data),
				   get_data:Delegate.create(this,this.get_data),
				   get_current_data:Delegate.create(this,this.get_current_data),
				   dexdelaystart:Delegate.create(this,this.dexdelaystart)
		          };

		this.parentMC=parentMC;
		this.callback=callback;
		this.mysegment=mySegment;
		this.segdetails=segDetails;

		this.menuDirection=1;

		// hyperscroll
		this.hyperStop();   													 // make sure hyper is off
		this.hyperInterval = setInterval(this.fn.hyperCheck,Common.evSettings.hyperscrolltimer); // enable the watchdog

		trace("DEX inited");

		// init remote data
		this.remotedata=new Remotedata();
		this.remotedata.init(this.segdetails,this.fn.onremotedata);
	}

	public function cleanup():Void {
		// turn off hyperscroll
		clearInterval(this.hyperInterval);
		this.hyperscroll = null;
		this.hyperscrolllast = null;
		this.hyperInterval=null;
		this.hyperScreen=null;

		this.indexActive=null;

		delete this.fn;
		this.fn = null;

		this.parentMC = null;

		this.mainMC.menuMC.removeMovieClip();
		this.mainMC.removeMovieClip();
		this.mainMC = null;

		this.callback = null;
		this.mysegment=null;

		delete this.segdetails;
		this.segdetails=null;

		this.remotedata.cleanup();
		this.remotedata=null;

		delete this.indexRefer;
		this.indexRefer=null;

		delete this.menuSettings;
		this.menuSettings=null;

		this.menuDirection=null;
		this.menuTileDepth=null;

		// hypersettings
		delete this.hypersetting;
		this.hypersetting=null;
		this.hypersetting=new Object();

		this.hypersetting.use=this.tffix(Common.evSettings.hyperscroll,true);
	}

	private function tffix(setting, defval) {
		switch(setting.toUpperCase()) {
			case 'TRUE':
				return(true);
			case 'FALSE':
				return(false);
			default:
				if(defval!=undefined) return(defval);
		}

		return(false);
	}

	public function reset_dex() {
		this.hyperStop();

		this.menuSettings=new Object();

		delete this.indexRefer;
		this.indexRefer=null;
		this.indexRefer=new Array();

		// nav
		this.menuCursor=0;
		this.menuTotal=0;
		this.menuFirst=0;
		this.lastdrawn=-1;
		this.menuActiveMore=false;
		this.activedrawing=false;
		this.menuLastPos={x:1,y:1};

		this.indexActive=false;
		this.hyperidle=0;
		this.hypercycle=0;

	}


// ********************** COMMUNICATION *******************
    // info from screen
	public function alert(request:String, message:String, newparent:MovieClip, data:Object) {
		// trace("alert request "+request);

		if(newparent!=null && newparent!=undefined) {
			this.parentMC=newparent;
			// trace("..new parent");
		}

		switch(request) {
			case 'IDLE':
				// trace("index deactivated");
				this.indexActive=false;
				break;
			case 'ERRORHALT':
				this.indexActive=false;
				clearInterval(this.hyperInterval);
				this.remotedata.cleanup();
				break;
			case 'UNLOAD': // clear out for memory, user left screen
				this.indexActive=false;
				for(var i=0;i<this.remotedata.totalTitles;i++) {
					if(this.mainMC.menuMC.listMC[i]._visible !=undefined) {
						// remove the spot
						this.mainMC.menuMC.listMC[i].removeMovieClip();
						this.indexRefer[i].hl=false;
					}
				}
				break;
			case 'WAKE':  // we're back in control!
				this.indexActive=true;
				this.hyperReset();
				this.hyperDraw(true);
				this.segdetails.erun.skin_segname_update(this.mysegment,{get_data:this.fn.get_current_data,get_ev_data:this.fn.get_ev_data});
				//this.menuActiveMore=true;
				break;
			case 'UPDATE':  // called after preload when eskin is ready to go
				this.segdetails=data;
				this.mysegment=data.segnum;
				// trace("new segment number "+data.segnum);
				// BREAK MISSING ON PURPOSE
			case 'START':
				this.mainMC=this.parentMC.createEmptyMovieClip(this.segdetails.mcname, this.segdetails.mcdepth);
				this.dex_create();
				break;
			case 'CONTROL':
				this.indexActive=true;
				RemoteControl.startRemote("segment",this.fn.onKeyDown);
				Preloader.clear();
				break;
			default:
				// trace("unknown alert");
				break;
		}
	}

    // info from remotedata
	private function onremotedata(request:String, message:String, data:Array, details:Array) {
		// trace("onremotedata request "+request+" : "+message);

		switch(request) {
			case 'ERROR':    // problem
				this.mainMC.message_txt.text=message;
				clearInterval(this.hyperInterval);
				this.callback("ERROR", message);
				break;
			case 'PRELOAD':  // preload ready
				if(data==undefined) data=new Array();
				data.get_data=this.fn.get_ev_data;
				this.callback(request, message, data, details);
				break;
			case 'DATAWAIT': // remotedata ready to draw
				_global["setTimeout"](this.fn.dexdelaystart, 100);
				break;
			case 'add':      // add data to dex
				// trace("... add");
				menu_field_draw(data, details.page, details.offset);
				//if(this.hyperscroll==0 && this.menuActiveMore==true) this.menu_draw_active();
				this.menuActiveMore=true;
				break;
			case 'remove':   // remove data from dex
				// trace("... remove");
				menu_field_remove(details.page, details.offset, details.length, details.keepdata);
				break;
			case 'reloaded': // reload finished
				break;
			case 'fatal':    // cannot continue error
				clearInterval(this.hyperInterval);
				this.callback("FATAL", message);			// non-recoverable error
				break;
			default:
				trace('unknown RD request');
				clearInterval(this.hyperInterval);  		// turn off hyperscroll
				this.callback("ERROR", "Unknown rd: "+request);
		}
	}

	private function dexdelaystart() {
		if(this.fn==null) return;  // dex no longer needed
		this.mainMC=this.parentMC.createEmptyMovieClip(this.segdetails.mcname, this.segdetails.mcdepth);
		this.dex_create();
	}



// *********************** DEX creation ****************************
	private function dex_create() {
		trace("dex_create");

		// setup parameters
		this.reset_dex();

		// startpos
		this.menuSettings.posx=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.startx;
		this.menuSettings.posy=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.starty;

		// hyper
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.hyperscroll==false) this.hypersetting.use=false;

		// tile (limited to first tile for now).
		this.menuSettings.cols=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].tile[0].cols;
		this.menuSettings.rows=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].tile[0].rows;
		this.menuSettings.scroll=this.fix_scroll(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.scroll);

		this.menuSettings.tilewidth=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].tile[0].width;
		this.menuSettings.tileheight=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].tile[0].height;
		this.menuSettings.offset=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].tile[0].offset;
		this.menuSettings.stat=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].tile[0].stat;
		this.menuSettings.first=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].tile[0].first;

		// end pos
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.tilesize == true) {
			this.menuSettings.endx=this.menuSettings.posx+(this.menuSettings.cols*this.menuSettings.tilewidth);
			this.menuSettings.endy=this.menuSettings.posy+(this.menuSettings.rows*this.menuSettings.tileheight);
		} else {
			this.menuSettings.endx=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.endx;
			this.menuSettings.endy=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.endy;
		}

		// offsets
		this.menuSettings.addx=0;
		this.menuSettings.addy=0;
		if(this.menuSettings.offset!=0 && (this.menuSettings.cols==1 || this.menuSettings.rows==1)) {
			if(this.menuSettings.scroll==1) {
				this.menuSettings.addx=this.menuSettings.tilewidth*this.menuSettings.offset;
			} else {
				this.menuSettings.addy=this.menuSettings.tileheight*this.menuSettings.offset;
			}
		} else {
			this.menuSettings.stat=false;
			this.menuSettings.offset=0;
		}

		// cursor info
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].cursor != undefined) {
			this.menuSettings.cursorshiftx=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].cursor.posx;
			this.menuSettings.cursorshifty=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].cursor.posy;
		} else {
			this.menuSettings.cursorshiftx=0;
			this.menuSettings.cursorshifty=0;
		}

		// init the screen area
		this.mainMC.createEmptyMovieClip("menuMC", this.mainMC.getNextHighestDepth());

		// top left corner
		this.mainMC.menuMC._x=this.menuSettings.posx;
		this.mainMC.menuMC._y=this.menuSettings.posy;

		// cursor below
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].cursor.above==false) {
			trace("cursor is below segment");
			create_cursor(this.mainMC.menuMC);
		}

		// the slide rule for the tiles to live on
		this.mainMC.menuMC.createEmptyMovieClip("listMC", this.mainMC.menuMC.getNextHighestDepth());

		// mask the screen to hide out of box items
		var wide=this.menuSettings.endx-this.menuSettings.posx;
		var high=this.menuSettings.endy-this.menuSettings.posy;
		// trace("wide "+wide+" high "+high);

		var maskMC=this.mainMC.menuMC.createEmptyMovieClip("maskMC", this.mainMC.menuMC.getNextHighestDepth());
		maskMC.beginFill(0x000000,100);
		maskMC.lineTo(wide,0);
		maskMC.lineTo(wide,high);
		maskMC.lineTo(0,high);
		maskMC.lineTo(0,0);
		maskMC.endFill();
		this.mainMC.menuMC.listMC.setMask(maskMC);

		// cursor above
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].cursor.above==true) {
			trace("cursor is above segment");
			create_cursor(this.mainMC.menuMC);
		}

		// prep the xy
		this.menu_add_xy(this.remotedata.totalTitles);

	    // activate prefetch/send in data
		this.remotedata.adddata();

		// activate the dex and place the cursor
		if(this.menuSettings.first>=this.remotedata.totalTitles) this.menuSettings.first=this.remotedata.totalTitles-1;
		this.indexActive=true;
		this.hyperReset();
		this.menuCursor=this.menuSettings.first;
		this.menuDirection=1;
		if(this.menuSettings.stack==1 || this.menuSettings.scrollTotal==1) {
			this.menu_cursor_single(this.menuSettings.first);
		} else {
			menu_cursor_multi(this.menuSettings.first,1);
		}

		this.segdetails.erun.skin_segname_update(this.mysegment,{get_data:this.fn.get_current_data,get_ev_data:this.fn.get_ev_data});
		this.callback("ONLINE");
	}

	private function create_cursor(thisMC:MovieClip) {
		// if there is even a cursor to add
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].cursor!=undefined) {
			this.menuSettings.cursoranimate=Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].cursor.animate;

			// create the slide rule to mimic list
			var cursorslide:MovieClip=thisMC.createEmptyMovieClip("cursorSLIDE", thisMC.getNextHighestDepth());
			var cursorMC:MovieClip=cursorslide.createEmptyMovieClip("cursorMC", cursorslide.getNextHighestDepth());
			this.menu_draw_cursor(cursorMC);
		}
	}

	private function fix_scroll(scroll:Number) {
		switch(scroll) {
			case 1:
				this.menuSettings.scrollTotal=this.menuSettings.cols;
				this.menuSettings.stack=this.menuSettings.rows;
				return(1);
			case 2:
				this.menuSettings.scrollTotal=this.menuSettings.rows;
				this.menuSettings.stack=this.menuSettings.cols;
				return(2);
			default:
				if(this.menuSettings.cols>this.menuSettings.rows) {
					return(fix_scroll(1));
				} else {
					return(fix_scroll(2));
				}
		}
	}


	private function menu_field_draw(menuData:Array, fromPage:Number, offSet:Number) {
		var ending=offSet+menuData.length;

		for(var i=offSet;i<ending;i++) {
			// trace("adding tile "+i);
			this.indexRefer[i].page=fromPage;
			this.indexRefer[i].element=i-offSet;
			this.indexRefer[i].loaded=1;
			//this.indexRefer[i].visible=0;
		}
	}

	private function menu_add_xy(total:Number) {
		if(this.menuSettings.stack==1) {
			for(var i=0;i<total;i++) {
				// add the spot
				if(this.menuSettings.scroll==1) {		 	// hscroll, x changes.
					this.menu_add_single(i,i,0);
				} else {									// vscroll, y changes.
					this.menu_add_single(i,0,i);
				}
			}
		} else {
			var i=0;
			for(var u=0;u<total;u++) {
				for(var t=0;t<this.menuSettings.stack;t++) {  // columns
					if(this.menuSettings.scroll==1) {	// hscroll
						this.menu_add_single(i,u,t);
					} else {										// vscroll
						this.menu_add_single(i,t,u);
					}
					i++; // increment who
					if(i>=total) break;
				}
				if(i>=total) break;
			}
		}
	}

	private function menu_add_single(who:Number, dx:Number,dy:Number):Void {
		//// trace("prepping tile "+who);
		if(this.indexRefer[who]==undefined) this.indexRefer[who]=new Object();
		this.indexRefer[who].tilex=0+(this.menuSettings.tilewidth*dx);
		this.indexRefer[who].tiley=0+(this.menuSettings.tileheight*dy);
		//this.indexRefer[who].visible=0;
		//this.indexRefer[who].loaded=0;
	}

// ************************************* tile add/remove ************************************
	// fill in the scroll field for the visible
	private function menu_draw_active() {
		// make sure we are active
		if(this.indexActive!=true) return

		// get the poster up if needed
		this.menu_draw_tile(this.menuCursor);

		//make sure nobody else is doing this already.
		if(this.activedrawing==true) return;

		// lets begin.
		this.activedrawing=true;

		if(this.menuSettings.pagesize==undefined) this.menuSettings.pagesize=this.menuSettings.scrollTotal*this.menuSettings.stack;

		// first tile to draw
		var drawFirst=this.menuFirst;
		if(this.menuSettings.offset!=0) {
			drawFirst=this.menuFirst-this.menuSettings.offset;
		}

		var firsttile=drawFirst*this.menuSettings.stack;   // first tile to load
		var lasttile=firsttile+this.menuSettings.pagesize;      // last tile to load

		if(Common.evSettings.hyperscrolldrawmode=="nice") {  // predraw 1 screen mode
			if(this.menuDirection==1) { // user is traveling up in the count
				lasttile=lasttile+this.menuSettings.pagesize;    // move the last tile 1 more screen worth
			} else {					// user is traveling down in the count
				firsttile=firsttile-this.menuSettings.pagesize;  // move the first tile 1 more screen worth
			}
		}

		// adjust for over the edge of drawing
		if(firsttile<0) firsttile=0;
		if(lasttile>=this.remotedata.totalTitles) lasttile=this.remotedata.totalTitles-1;


		if(this.hyperscroll<=0 && this.hyperscrolllast<=0) {
			var stopat:Number=this.menuSettings.pagesize;
		} else if(this.hyperscroll>0) {
			var scale=this.hyperscroll-Common.evSettings.hyperscrolldraw+Common.evRun.hyperdraw;
			if(scale<3) scale=2;
			var stopat:Number=Common.evSettings.hyperactivedraw/scale;
		} else {
			var stopat:Number=Common.evSettings.hyperactivedraw;
		}

		var drew:Number=0;

		this.menuActiveMore=false;
		if(this.hyperscroll<=0 && this.hyperscrolllast<=0) stopat=99;
		// loop them in order of what should be on the screen
		if(this.menuDirection==1) {
			for(var i=firsttile;i<=lasttile;i++) {
				//// trace(".. checking tile "+i);
				if(this.menu_draw_tile(i)) {
					drew++;
					if(drew>=stopat) {
						this.menuActiveMore=true;
						break;
					}
				}
			}
		} else {
			for(var i=lasttile;i>=firsttile;i--) {
				//// trace(".. checking tile "+i);
				if(this.menu_draw_tile(i)) {
					drew++;
					if(drew>=stopat) {
						this.menuActiveMore=true;
						break;
					}
				}
			}
		}

		// spot check the curcor (faster to just move), tile draw takes care of highlights.
		//this.mainMC.menuMC.cursorSLIDE.cursorMC._x=this.indexRefer[this.menuCursor].tilex;
		//this.mainMC.menuMC.cursorSLIDE.cursorMC._y=this.indexRefer[this.menuCursor].tiley;
		this.menu_highlight(this.menuCursor,true);

		this.activedrawing=false;
	}

	private function menu_draw_tile(who:Number) {
		//// trace("TILE: draw "+who);

		if(this.indexRefer[who].loaded!=1) {
			// trace("TILE: data not loaded, skipped tile "+who);
			return(false);
		}

		if(this.mainMC.menuMC.listMC[who]._visible==true) {
			//// trace("tile exists, skipped " +who);
			return(false);
		}

		// trace("TILE: draw "+who);

		// create mc
        this.mainMC.menuMC.listMC.createEmptyMovieClip(who, who+1);
		this.mainMC.menuMC.listMC[who]._visible=false;
		this.mainMC.menuMC.listMC[who]._x=this.indexRefer[who].tilex;
		this.mainMC.menuMC.listMC[who]._y=this.indexRefer[who].tiley;
		//this.indexRefer[who].visible=1;
		this.remotedata.imageonpage(this.indexRefer[who].page);

		// draw it
		var hl:Boolean=false
		if(who==this.menuCursor) hl=true;
		this.segdetails.erun.draw_tile(this.mysegment, who, this.mainMC.menuMC.listMC[who], {get_data:this.fn.get_data,get_ev_data:this.fn.get_ev_data},hl);


		return(true);
	}

	private function menu_draw_cursor(cursorMC:MovieClip) {
		this.segdetails.erun.draw_cursor(this.mysegment, cursorMC);
	}

	private function menu_highlight(who:Number, highlight:Boolean) {
		if(this.indexRefer[who].hl==highlight) return;

		// make sure the cursor slide is in the right place
		this.mainMC.menuMC.cursorSLIDE._x=this.mainMC.menuMC.listMC._x+this.menuSettings.cursorshiftx;
		this.mainMC.menuMC.cursorSLIDE._y=this.mainMC.menuMC.listMC._y+this.menuSettings.cursorshifty;

		// position the cursor
		this.mainMC.menuMC.cursorSLIDE.cursorMC._x=this.indexRefer[who].tilex;
		this.mainMC.menuMC.cursorSLIDE.cursorMC._y=this.indexRefer[who].tiley;

		if(this.mainMC.menuMC.listMC[who]._visible!=true) {
			// trace("hl tile doesn't exist, skipped");
			return;
		}

		if(this.menuSettings.cursoranimate) {
			//trace("animating cursor");
			this.mainMC.menuMC.cursorSLIDE.cursorMC.cursor.cursor_img.gotoAndPlay(1);
		}

		this.indexRefer[who].hl=highlight;
		this.segdetails.erun.highlight_tile(highlight, this.mysegment, who, this.mainMC.menuMC.listMC[who], {get_data:this.fn.get_data,get_ev_data:this.fn.get_ev_data});
	}

	private function menu_field_remove(fromPage:Number, offSet:Number, length:Number, keepdata:Boolean) {
		var ending=offSet+length;
		for(var i=offSet;i<ending;i++) {
			this.mainMC.menuMC.listMC[i].removeMovieClip();
			if(keepdata != true) this.indexRefer[i].loaded=0;
			this.indexRefer[i].hl=false;
		}
	}

// *********************** ev int data *****************************
	private function get_ev_data(what:String) {
		// trace("dex get_ev_data for "+what);

		switch(what) {
			case 'peoplexml':
				//trace("dex: "+this.remotedata.peopleXML);
				return(this.remotedata.peopleXML);
				break;
			case 'indexname':
				//trace("call for indexname "+this.remotedata.indexName);
				return(this.remotedata.indexName);
				break;
			case 'indextype':
				return(this.remotedata.indexType);
				break;
			case 'indexurl':
				return(this.remotedata.indexURL);
				break;
			case 'originaltitle':
				return(this.remotedata.indexOriginalName);
				break;
			case 'indexkind':
				switch(this.remotedata.indexType) {
					case 'TV':
						return(Common.evPrompts["shows"]);
					case 'TVSET':
						return(Common.evPrompts["seasons"]);
					case 'MOVIE':
					case 'MOVIESET':
						return(Common.evPrompts["movies"]);
					case 'EP':
						return(Common.evPrompts["episodes"]);
					case 'TRAILER':
					case 'TRAILERS':
						return(Common.evPrompts["trailers"]);
					case 'PEOPLE':
						return(Common.evPrompts["people"]);
					default:
						return(Common.evPrompts["titles"]);
				}
				break;
			case 'totaltiles':
				return(this.remotedata.totalTitles);
			case 'pagecurrent':
				var tt=Math.floor(this.menuCursor/(this.menuSettings.stack*this.menuSettings.scrollTotal))+1;
				return(tt.toString());
				break;
			case 'pagetotal':
				var tt=Math.ceil(this.remotedata.totalTitles/(this.menuSettings.stack*this.menuSettings.scrollTotal));
				return(tt.toString());
				break;
			case 'curpos':
				var tt=this.menuCursor+1;
				return(tt.toString());
				break;
			default:
				// trace(".. unknown");
		}
	}

	public function get_data(what:String, who:Number,howmany:Number) {
		//trace("!!!!!!!!!!!!!!!!!!!! get_data for "+what);
		if(who==undefined) who=this.menuCursor;
		return(this.remotedata.process_JBData(what,this.indexRefer[who],howmany));
	}

	public function get_current_data(what:String,who:Number,howmany:Number) {
		//trace("$($*(@#$*@!($*@!(#$*@(!*@!#$*!@(#$*@#($ get_current_data for "+what);
	    // used by hyperdraw
		switch(what) {     // loading alternative
			case 'title':
			case 'fulltitle':
			case 'smarttitle':
				var good:String=this.remotedata.process_JBData(what,this.indexRefer[this.menuCursor],howmany);
				if(good==undefined) {
					this.hyperScreen=true;
					return("LOADING...");
					this.hyperscroll=5;
					this.hyperscrolllast=5;
				} else {
					this.hyperScreen=false;
					return(good);
				}
			default:
				return(this.remotedata.process_JBData(what,this.indexRefer[this.menuCursor],howmany));
		}
	}

// ************************************* Nav movement ***************************************
	private function menu_nav_jump(keyhit) {
		var who=Math.floor((this.remotedata.totalTitles-1)*((keyhit-48)/10));
		//// trace("******** jump to "+who);

		// reset hyperscoll to give a fast reload if possible
		this.hyperscrolllast=-1;
		this.hyperscroll=0;

		if(who>=this.menuCursor) {
			this.menuDirection=1;
		} else {
			this.menuDirection=2;
		}

		if(this.menuSettings.stack==1 || this.menuSettings.scrollTotal==1) { // single
			menu_cursor_single(who,this.menuDirection);
		} else { // multi
			menu_cursor_multi(who,this.menuDirection);
		}
	}

	private function menu_nav_multi(keyhit) {
		var who=this.menuCursor;
		this.menuDirection=1;  // forward

		if(this.menuSettings.scroll==1) { // horizontal
			switch(keyhit) {
				case Key.LEFT:
					who=who-this.menuSettings.stack;
					this.menuDirection=2;
					break;
				case Key.RIGHT:
					who=who+this.menuSettings.stack;
					break;
				case Key.UP:
					who--;
					this.menuDirection=2;
					break;
				case Key.DOWN:
					who++;
					break;
				case Key.PGUP:
				case Key.VOLUME_UP:
					who=who-(this.menuSettings.scrollTotal*this.menuSettings.stack);
					this.menuDirection=2;
					break;
				case Key.PGDN:
				case Key.VOLUME_DOWN:
					who=who+(this.menuSettings.scrollTotal*this.menuSettings.stack);
					break;
				default:
					// bad key
					return;
			}
		} else { // vertical
			switch(keyhit) {
				case Key.UP:
					who=who-this.menuSettings.stack;
					this.menuDirection=2;
					break;
				case Key.DOWN:
					who=who+this.menuSettings.stack;
					break;
				case Key.LEFT:
					who--;
					this.menuDirection=2;
					break;
				case Key.RIGHT:
					who++;
					break;
				case Key.PGUP:
				case Key.VOLUME_UP:
					who=who-(this.menuSettings.scrollTotal*this.menuSettings.stack);
					this.menuDirection=2;
					break;
				case Key.PGDN:
				case Key.VOLUME_DOWN:
					who=who+(this.menuSettings.scrollTotal*this.menuSettings.stack);
					break;
				default:
					// bad key
					return;
			}
		}

		// see if we're on the edge already.
		if(who<0) {
			if(this.menuCursor>=this.menuSettings.stack) {  // compensate for pging
				who=0;
			} else return;
		} else if(who>=this.remotedata.totalTitles) {
			who=this.remotedata.totalTitles-1;
		}

		// we didn't really move
		if(who==this.menuCursor) return;

		this.menu_cursor_multi(who,this.menuDirection);
	}

	private function menu_cursor_multi(who,direction) {
		this.menu_highlight(this.menuCursor,false);

		// move the cursor
		//this.mainMC.menuMC.cursorSLIDE.cursorMC._x=this.indexRefer[who].tilex;
		//this.mainMC.menuMC.cursorSLIDE.cursorMC._y=this.indexRefer[who].tiley;

		//this.mainMC.menuMC.cursorSLIDE.cursorMC._x=this.indexRefer[who].tilex;
		//this.mainMC.menuMC.cursorSLIDE.cursorMC._y=this.indexRefer[who].tiley;

		// figure out who is first on the screen
		var stackedwho=Math.floor(who/this.menuSettings.stack);
		if (stackedwho < this.menuFirst)
			this.menuFirst = stackedwho;
		else if (stackedwho >= this.menuFirst + this.menuSettings.scrollTotal)
			this.menuFirst=stackedwho - this.menuSettings.scrollTotal + 1;

		// shift the menu
		if(this.menuSettings.scroll==1) { // horizontal
			this.mainMC.menuMC.listMC._x=(-1 * this.menuFirst * this.menuSettings.tilewidth);
		} else { // vertical
			this.mainMC.menuMC.listMC._y=(-1 * this.menuFirst * this.menuSettings.tileheight);
		}

		// adjust the cursor to match
		this.mainMC.menuMC.cursorSLIDE._x=this.mainMC.menuMC.listMC._x;
		this.mainMC.menuMC.cursorSLIDE._y=this.mainMC.menuMC.listMC._y;

		// mark who is the new cursor
		this.menuCursor=who;
		this.menu_draw_tile(who);
		this.menu_highlight(who,true);

		// add the data to the screen
		this.hyperDraw(true);

		// see if its safe to draw the screen
		if(this.hyperscroll <= Common.evSettings.hyperscrolldraw) {
			if(this.menuLastPos.x!= this.mainMC.menuMC.listMC._x || this.menuLastPos.y!= this.mainMC.menuMC.listMC._y) {
				this.menu_draw_active();
				this.menuLastPos.x=this.mainMC.menuMC.listMC._x;
				this.menuLastPos.y=this.mainMC.menuMC.listMC._y;
			}
		}

		// tell prefetch we moved.
		if(direction!=undefined) {
			this.remotedata.cursormoved(who,direction,this.menuFirst*this.menuSettings.stack,(this.menuFirst*this.menuSettings.stack)+(this.menuSettings.scrollTotal*this.menuSettings.stack));
		}

		this.alwaysupdate();
	}

	private function menu_nav_single(keyhit) {
		var who=this.menuCursor;
		this.menuDirection=1; // forward

		if(this.menuSettings.scroll==1) { // horizontal
			switch(keyhit) {
				case Key.LEFT:
					who--;
					if(Common.evSettings.hyperscrolljump == "true" && this.hyperscroll==6) who=who-2;
					this.menuDirection=2;
					break;
				case Key.RIGHT:
					who++;
					if(Common.evSettings.hyperscrolljump == "true" && this.hyperscroll==6) who=who+2;
					break;
				case Key.UP:
				case Key.DOWN:
					// don't have u/d
					return;
				case Key.PGUP:
				case Key.VOLUME_UP:
					who=who-this.menuSettings.scrollTotal;
					this.menuDirection=2;
					break;
				case Key.PGDN:
				case Key.VOLUME_DOWN:
					who=who+this.menuSettings.scrollTotal;
					break;
				default:
					// bad key
					return;
			}
		} else { // vertical
			switch(keyhit) {
				case Key.UP:
					who--;
					if(Common.evSettings.hyperscrolljump == "true" && this.hyperscroll==6) who=who-2;
					this.menuDirection=2;
					break;
				case Key.DOWN:
					who++;
					if(Common.evSettings.hyperscrolljump == "true" && this.hyperscroll==6) who=who+2;
					break;
				case Key.LEFT:
				case Key.RIGHT:
					// don't have left/right yet
					return;
				case Key.PGUP:
				case Key.VOLUME_UP:
					who=who-this.menuSettings.scrollTotal;
					this.menuDirection=2;
					break;
				case Key.PGDN:
				case Key.VOLUME_DOWN:
					who=who+this.menuSettings.scrollTotal;
					break;
				default:
					// bad key
					return;
			}
		}

		// see if we're on the edge already.
		if(who<0) {
			who=0;
		} else if(who>=this.remotedata.totalTitles) {
			who=this.remotedata.totalTitles-1;
		}

		// we didn't move, abort
		if(who==this.menuCursor) return;

		this.menu_cursor_single(who,this.menuDirection);
	}

	private function menu_cursor_single(who,direction) {
		this.menu_highlight(this.menuCursor,false);

		if(this.menuSettings.stat==false) {
			// figure out who is first on the screen
			if (who < this.menuFirst)
				this.menuFirst = who;
			else if (who >= this.menuFirst + this.menuSettings.scrollTotal)
				this.menuFirst=who - this.menuSettings.scrollTotal + 1;
		} else this.menuFirst = who;

		// shift the menu
		if(this.menuSettings.scroll==1) { // horizontal
			this.mainMC.menuMC.listMC._x=(-1 * this.menuFirst * this.menuSettings.tilewidth)+this.menuSettings.addx;
		} else { // vertical
			this.mainMC.menuMC.listMC._y=(-1 * this.menuFirst * this.menuSettings.tileheight)+this.menuSettings.addy;
		}

		// adjust the cursor to match
		//this.mainMC.menuMC.cursorSLIDE._x=this.mainMC.menuMC.listMC._x;
		//this.mainMC.menuMC.cursorSLIDE._y=this.mainMC.menuMC.listMC._y;

		// mark who is the new cursor
		this.menuCursor=who;
		this.menu_draw_tile(who);
		this.menu_highlight(who,true);

		// see if its safe to draw the screen
		if(this.hyperscroll <= Common.evSettings.hyperscrolldraw) {
			if(this.menuLastPos.x!= this.mainMC.menuMC.listMC._x || this.menuLastPos.y!= this.mainMC.menuMC.listMC._y) {
				this.menu_draw_active();
				this.menuLastPos.x=this.mainMC.menuMC.listMC._x;
				this.menuLastPos.y=this.mainMC.menuMC.listMC._y;
			}
		}

		// turn on the new one.
		//this.mainMC.menuMC.cursorSLIDE.cursorMC._x=this.indexRefer[this.menuCursor].tilex;
		//this.mainMC.menuMC.cursorSLIDE.cursorMC._y=this.indexRefer[this.menuCursor].tiley;

		// add the data to the screen
		this.hyperDraw(true);

		// tell prefetch we moved.
		if(direction!=undefined) {
			this.remotedata.cursormoved(who,direction,(this.menuFirst-this.menuSettings.offset)*this.menuSettings.stack,((this.menuFirst-this.menuSettings.offset)*this.menuSettings.stack)+(this.menuSettings.scrollTotal*this.menuSettings.stack));
		}
		this.alwaysupdate();
	}

	private function alwaysupdate() {
		var txtfmt=this.parentMC.cursorloc.getTextFormat();
		this.parentMC.cursorloc.text=this.menuCursor+1;
		this.parentMC.cursorloc._visible=true;
		this.parentMC.cursorloc.setTextFormat(txtfmt);

		txtfmt=this.parentMC.pagenavfull.getTextFormat();
		var pagecurrent=Math.floor(this.menuCursor/(this.menuSettings.stack*this.menuSettings.scrollTotal))+1;
		var pagelast=Math.ceil(this.remotedata.totalTitles/(this.menuSettings.stack*this.menuSettings.scrollTotal));
		this.parentMC.pagenavfull.text=pagecurrent.toString()+" / "+pagelast.toString();
		this.parentMC.pagenavfull._visible=true;
		this.parentMC.pagenavfull.setTextFormat(txtfmt);
	}

// ************************************* HYPERSCROLL ****************************************
	// this is the function that controls what to draw depending on hyperscoll level
	private function hyperDraw(redraw:Boolean, dontclimb:Boolean):Void {
		// trace("hyperdraw called");

		var hyperd:Number=1;
		switch(this.hyperscroll) {
			case 0:
				break;
			case 1:	  // everything draws (except fast who skips over)
				if(Common.evSettings.hyperscrollstart == "slow") {
					break;
				} else {
					if(Common.evSettings.hyperscrollstart == "fast") this.hyperscroll=2;  // move to the next level now
					hyperd=2;
				}
				// break missing on purpose
			case 2:     // no fanart
				hyperd=2;
				break;
			case 3:		// no poster
				if(redraw) hyperd=3;
				   else hyperd=4;
				break;
			case 4:		// the rest are all 4
				if(redraw) {
					hyperd=4;
					break;
				}
				return;
			default:
				return;
		}


		if((this.hyperscroll < 5 || dontclimb) && (this.lastdrawn!=this.menuCursor||this.hyperscrolllast!=this.hyperscroll||this.hyperScreen==true)) {
			if(this.skinBusy!=true) {
				this.skinBusy=true;
				this.segdetails.erun.skin_update(this.mysegment, hyperd, {get_data:this.fn.get_current_data,get_ev_data:this.fn.get_ev_data}, redraw, dontclimb);  // fanart redraw triggered by dontclimb
				this.lastdrawn=this.menuCursor;
				this.skinBusy=false;
			}
		}

		// increment the hyperlevel if not a redraw
		if(redraw==true && this.hypersetting.use) {
			// hyperscroll
			if(this.hyperscroll < 5 && dontclimb != true) {
				this.hyperscrolllast=this.hyperscroll;
				this.hyperscroll++;  // increase the counter
			}
		}
	}

	// this function is the watchdog to redraw the screen when ready
	private function hyperCheck() {

		// make sure we're active
		if(this.indexActive!=true || this.hyperscroll==-1) return;

		if(this.hyperScreen!=true && this.hypercycle < Common.evSettings.hypercycles) {
			if(this.hyperscroll <= Common.evSettings.hyperscrollredraw && this.hyperscrolllast>this.hyperscroll) {
				this.menu_draw_active();
			} else if(this.hyperscroll < Common.evSettings.hyperscrolldraw && this.hyperscrolllast<this.hyperscroll) {
				this.menu_draw_active();
			} else if(this.menuActiveMore) {
				this.menu_draw_active();
				this.hyperDraw(true,true);
			}
			this.hypercycle++;
		} else {
			// see if we're loading
			if(this.hyperScreen==true && this.indexRefer[this.menuCursor].loaded != 1) {  // loading with loading showing
				// trace("hyper skipped, not loaded");
				return;
			} else if(this.hyperScreen==true && this.indexRefer[this.menuCursor].loaded == 1) {  // loaded but loading still showing
				trace("returning from loading....");
				this.menu_draw_tile(this.menuCursor);
				this.hyperDraw(true,true);
				if(this.hyperscroll==0) this.menu_draw_active();
				this.hyperScreen=false;
				return;
			} else if(this.hyperScreen==true) {
				trace("hyperscreen still true");
				//this.hyperDraw(true,true);
				this.hyperScreen=false;
			}

			// we only care about when its time to redraw
			if(this.hyperscrolllast>=this.hyperscroll) {
				// fast drop (user choice in settings).  this causes the screen to reappear faster
				//if(Common.evSettings.hyperscrollspeed != "slow") {
					this.hyperscroll=this.hyperscroll-1; // speed drop

					if(Common.evSettings.hyperscrollspeed == "medium") this.hyperscroll=this.hyperscroll-1;
					if(Common.evSettings.hyperscrollspeed == "fast") this.hyperscroll=this.hyperscroll-2;

					if(this.hyperscroll < 0) this.hyperscroll=0;
				//}
				this.hyperDraw(true,true);
			}


			// check the menu is on screen

			// use redraw setting when scroll is falling
			if(drawactive == undefined && this.hyperscroll <= Common.evSettings.hyperscrollredraw && this.hyperscrolllast>this.hyperscroll) {
				this.menu_draw_active();
				var drawactive:Boolean=true;
			}

			// use draw when scroll is climing
			if(drawactive == undefined && this.hyperscroll < Common.evSettings.hyperscrolldraw && this.hyperscrolllast<this.hyperscroll) {
				this.menu_draw_active();
				var drawactive:Boolean=true;
			}

			// additional check when we hit 0 the first time
			if(this.hyperscroll == 0 && this.hyperscrolllast != 0 && drawactive==undefined) {
				this.menu_draw_active();
				var drawactive:Boolean=true;
			}

			// if we're idling 0 and there's more waiting for active
			if(this.hyperscroll == 0 && this.hyperscrolllast == 0 && drawactive==undefined && this.menuActiveMore) {
				this.menu_draw_active();
			}

			// reset the last
			this.hyperScreen=false;
			this.hyperscrolllast=this.hyperscroll;
			this.hypercycle=0;
		}
	}

	private function hyperReset() {
		this.hyperscroll=0;
		this.hyperscrolllast=-1;
		this.hyperidle=0;
		this.hypercycle=0;
	}

	private function hyperStop() {
		this.hyperscroll=-1;
		this.hyperscrolllast=-1;
		this.hyperidle=0;
		this.hypercycle=0;
	}

// *********************************** REMOTE *****************************
	private function onKeyDown(keyhit) {
		// FORCED KEYS
		switch(keyhit)
		{
			case (Key.UP):
			case (Key.DOWN):
			case (Key.LEFT):
			case (Key.RIGHT):
				if(this.menuSettings.stack==1 || this.menuSettings.scrollTotal==1) {
					this.menu_nav_single(keyhit);
				} else {
					this.menu_nav_multi(keyhit);
				}
				return(true);
		}

		// SEGMENT KEYS:
		// buttons
		var handler=segment_remote_check(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].remote[keyhit]);
		if(handler != undefined) {
			if (handler.action=="PASS") {
				return(false);
			}

			// trace("** SEGMENT1 KEY HIT! "+keyhit);
			this.handle_remote(handler,keyhit);
			return(true);
		}


/*
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].remote[keyhit] != undefined) {
			// trace("** SEGMENT2 KEY HIT! "+keyhit);
			this.handle_remote(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].remote[keyhit],keyhit);
			return(true);
		}
	*/
		// keypad
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.remotekeypad != undefined) {
			if(keyhit>47 && keyhit<58) {
				// trace("** KEYPAD HIT! "+keyhit);
				this.handle_remote(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.remotekeypad,keyhit);
				return(true);
			}
		}

		// all
		if(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.remoteall != undefined) {
			// trace("** ALL HIT! "+keyhit);
			this.handle_remote(Common.eskinmaster[this.segdetails.eskin][this.segdetails.file].segments[this.segdetails.member].settings.remoteall,keyhit);
			return(true);
		}

		// Keys that weren't overridden
		switch(keyhit)
		{
			case (Key.PGUP):
			case (Key.PGDN):
				if(Common.evSettings.remotepgupdown!='true') return(false);  // can be disabled in settings
				if(this.menuSettings.stack==1 || this.menuSettings.scrollTotal==1) {
					this.menu_nav_single(keyhit);
				} else {
					this.menu_nav_multi(keyhit);
				}
				return(true);
			case (Key.ENTER):
				trace("default select");
				this.remote_select(keyhit);  // keyhit is for episode play usage
				return(true);
			default:
				// number keys (0-9)
				if(keyhit>47 && keyhit<58) {
					this.menu_nav_jump(keyhit);
					return(true);
				}
		}
		return(false);
	}

	private function segment_remote_check(against) {
		if(against == undefined) return(undefined);

		for(var i=0;i<against.length;i++) {
			if(against[i].condition==undefined) {
				trace(".. no remote condition");
				return(against[i]);
			} else {
				trace(".. remote condition "+against[i].condition);
				if(this.segdetails.erun.process_condition(against[i].condition, this.menuCursor, {get_data:this.fn.get_current_data,get_ev_data:this.fn.get_ev_data})) {
					return(against[i]);
				} else trace("condition failed");
			}
		}

		return(undefined);
	}

	private function handle_remote(data:Object, keyhit) {
		trace("SEG HANDLE_REMOTE");
		if(data.action=="PRELOAD" && data.target!=undefined) {
			trace("targeted preload for "+data.target);

			switch(data.target) {
				case 'indextypelist':
					trace(".. indextypelist");
					var doing=this.remotedata.get_remote_details(data.target);
					if(doing==null || doing==undefined) return;
					trace(".. doing: "+doing);
					var raw=new Object({action:data.file, file:data.file, data:"index", info:"menulist", arraydata:doing.toLowerCase(), title:Common.evPrompts[doing.toLowerCase()]});
					data.action="PRELOAD";
					this.callback("REMOTEKEY",data.action,{keyinfo:raw, who:this.menuCursor, epraw:epraw, raw:raw, xml:this.segdetails.xml, get_data:this.fn.get_data, get_ev_data:this.fn.get_ev_data});
					break;
				default:
					trace("not sure what to do here, skipped");
					//this.callback("ERROR","Unknown target:"+data.target);
					break;
			}
		} else {
			var raw=this.remotedata.get_data(this.indexRefer[this.menuCursor]);
			var epraw=this.remotedata.get_episodedata();

			// trace("raw: "+raw);
			// trace("raw episode: "+raw.episode);

			if(data==undefined) {
				trace("no data");
				if(raw.action!=undefined) {
					trace("no data, raw is good to use");
					data=raw;
				} else {
					trace("no data or raw, aborting");
					return;
				}
			}

			this.callback("REMOTEKEY",data.action,{keyinfo:data, file:data.file, who:this.menuCursor, epraw:epraw, raw:raw, xml:this.segdetails.xml, get_data:this.fn.get_data, get_ev_data:this.fn.get_ev_data});
		}
	}

	private function remote_select(keyhit) {
		if(this.indexRefer[this.menuCursor].loaded != 1) return;

		// get the action
		var action:String=this.remotedata.process_JBData("action",this.indexRefer[this.menuCursor]);
		trace("select action "+action);

		//Common.keyListener.onKeyDown = null;

		// switch it
		switch(action) {
			//case 'apps':  // switch to syabas's apps center
			//case 'exit':  // exit eversion
			//	this.callback(action);
			//	break;
			case 'index':  // switch to a new index
				this.remote_change_index();
				break;
			case 'detail':  // switch to details
				this.remote_change_detail();
				break;
			default:
				// trace(".. unknown action, trying remote action processor");
				this.handle_remote();
		}
	}

	private function remote_change_detail() {
		trace("details change");
		var ddata=this.remotedata.get_data(this.indexRefer[this.menuCursor]);
		this.callback("change",null,{kind:"DETAIL",xml:ddata});
	}

	private function remote_change_index() {
		trace("index change");

		// figure out who is next
		var filename:String=this.remotedata.process_JBData("file",this.indexRefer[this.menuCursor]);
		if(this.remotedata.process_JBData("mtype",this.indexRefer[this.menuCursor])=="TVSET") {
			trace("next index is a tv set");
			var ddata=this.remotedata.get_data(this.indexRefer[this.menuCursor]);
		} else var ddata=undefined;

		if(filename!=undefined) {
			trace(filename+" is next");
			this.callback("change",null,{kind:"INDEX",file:filename,tvset:ddata});
		} else {
			// trace("unknown filename to change too");
		}
	}
}