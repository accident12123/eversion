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
import ev.Eskinload;
import ev.Loadimage;
import ev.Background;
import api.Popapi;
import tools.Data;
import tools.StringUtil;
import tools.Preloader;
import mx.xpath.XPathAPI;
import mx.utils.Delegate;
//import tools.RTLtex;

class ev.Eskinrun {
	private var eskinMC:MovieClip=null;
	private var callback:Function=null;
	private var fn:Object = null;

	private var eskinfile:String=null;

	private var efiles:Object=null;
	private var segments:Object=null;

	private var eskinload:Eskinload=null;
	private var tempgetdata:Function=null;
	private var jbgetdata:Function=null;
	private var eskinmaster:String=null;

	//private var rtltxt:RTLtex=null;

	// depth
	private var depthtrack:Array=null;
	private var nextdepth:Number=null;

	public function Eskinrun(eskinMC:MovieClip, callback:Function) {
		this.cleanup();

		this.fn = {	updatedepthtrack:Delegate.create(this, this.updatedepthtrack),
				    eskinloaded:Delegate.create(this, this.eskinloaded)
        	};

		this.eskinMC=eskinMC;
		this.callback=callback;

		this.depthtrack=new Array();

		this.eskinmaster=Common.evSettings.eskin;

		//this.rtltxt=new RTLtex();

		trace("eskinrun inited");
	}

	public function cleanup() {
		delete this.fn;
		this.fn=null;

		delete this.depthtrack;
		this.depthtrack=null;
		this.nextdepth=null;

		delete this.efiles;
		this.efiles=null;

		//delete this.rtltxt;
		//this.rtltxt=null;

		this.eskinload.cleanup();
		this.eskinload=null;

		this.eskinmaster=null;

		delete this.segments;
		this.segments=null;

		this.eskinMC=null;  // removed via the screen that create it

		this.callback=null;
		this.eskinfile=null;

		this.tempgetdata=null;
		this.jbgetdata=null;
	}

	public function updateMaster(newmaster:String) {
		this.eskinmaster=newmaster;
		trace("eskinrun: master changed to "+newmaster);
	}

// ************* CORE **********************

	private function show_elements(eskin:String, file:String, drawtype:Number, firstrun:Boolean,hyper,getdata) {
	    //trace("processing "+eskin+" "+file+" level "+drawtype);

		if(firstrun == true) {
			if(this.efiles==null) this.efiles=new Array();
			this.efiles.push({eskin:eskin,file:file});
		//	trace("added to files list");
		}

		// loop the eskin
		for(var tt=0;tt<Common.eskinmaster[eskin][file].code.length;tt++) {

			// process
			switch(Common.eskinmaster[eskin][file].code[tt].action) {
				case 'include':
					this.show_elements(eskin,Common.eskinmaster[eskin][file].code[tt].name,drawtype,firstrun,hyper,getdata);
					continue;
				case 'shared':
					this.show_elements("shared",Common.eskinmaster[eskin][file].code[tt].name,drawtype,firstrun,hyper,getdata);
					continue;
			}
/*
			// skip if we're not in that drawmode
			if(Common.eskinmaster[eskin][file].code[tt].hyper!=undefined || Common.eskinmaster[eskin][file].code[tt].segname!=undefined) {
				if(firstrun==false) continue;
				if(this.depthtrack[Common.eskinmaster[eskin][file].code[tt].name]!=undefined) continue;

				//trace('firstdraw seg/hyper: '+Common.eskinmaster[eskin][file].code[tt].name);
				switch(Common.eskinmaster[eskin][file].code[tt].action) {
					case 'image':
					case 'text':
					case 'setdepth':
						if(this.depthtrack[Common.eskinmaster[eskin][file].code[tt].name]==undefined) {
							this.depthtrack[Common.eskinmaster[eskin][file].code[tt].name]=this.nextdepth++;
							trace(" seg: "+Common.eskinmaster[eskin][file].code[tt].name+" depth "+this.depthtrack[Common.eskinmaster[eskin][file].code[tt].name]);
						}
						break;
					case 'if':
						for(var jj=0;jj<Common.eskinmaster[eskin][file].code[tt].code.length;jj++) {
							if(this.depthtrack[Common.eskinmaster[eskin][file].code[tt].code[jj].name]!=undefined) continue;
							switch(Common.eskinmaster[eskin][file].code[tt].code[jj].action) {
								case 'image':
								case 'text':
									this.depthtrack[Common.eskinmaster[eskin][file].code[tt].code[jj].name]=this.nextdepth++;
									trace("IF "+Common.eskinmaster[eskin][file].code[tt].code[jj].name+" depth "+this.depthtrack[Common.eskinmaster[eskin][file].code[tt].code[jj].name]);
									break;
								default:
							}
						}
						break;
					default:
				}
				continue;
			}
*/

			if(firstrun==true) {
				switch(Common.eskinmaster[eskin][file].code[tt].action) {
					case 'image':
					case 'text':
					case 'setdepth':
						if(this.depthtrack[Common.eskinmaster[eskin][file].code[tt].name]==undefined) {
							this.depthtrack[Common.eskinmaster[eskin][file].code[tt].name]=this.nextdepth++;
							trace(" non-seg: "+Common.eskinmaster[eskin][file].code[tt].name+" depth "+this.depthtrack[Common.eskinmaster[eskin][file].code[tt].name]);
						}
						break;
					case 'if':
						for(var jj=0;jj<Common.eskinmaster[eskin][file].code[tt].code.length;jj++) {
							if(this.depthtrack[Common.eskinmaster[eskin][file].code[tt].code[jj].name]!=undefined) continue;
							switch(Common.eskinmaster[eskin][file].code[tt].code[jj].action) {
								case 'image':
								case 'text':
									this.depthtrack[Common.eskinmaster[eskin][file].code[tt].code[jj].name]=this.nextdepth++;
									trace("NON-SEG IF "+Common.eskinmaster[eskin][file].code[tt].code[jj].name+" depth "+this.depthtrack[Common.eskinmaster[eskin][file].code[tt].code[jj].name]);
									break;
								default:
							}
						}
						break;
					default:
				}
				if(Common.eskinmaster[eskin][file].code[tt].segname!=undefined) continue;
			}

			if(Common.eskinmaster[eskin][file].code[tt].hyper==undefined && Common.eskinmaster[eskin][file].code[tt].segname==undefined) {
				switch(Common.eskinmaster[eskin][file].code[tt].action) {
					case 'image':
						draw_image(Common.eskinmaster[eskin][file].code[tt],null,getdata);
						break;
					case 'text':
						if(firstrun==false && Common.eskinmaster[eskin][file].code[tt].name != "clock"&& Common.eskinmaster[eskin][file].code[tt].name != "date") continue;
						draw_text(Common.eskinmaster[eskin][file].code[tt],this.eskinMC,null,getdata,undefined);
						break;
					case 'if':
						this.perform_if(Common.eskinmaster[eskin][file].code[tt],this.eskinMC,null,getdata);
						break;
					case 'setdepth':
						// ignore, this is just setting the depth of a segment or later processed block
						break;
					default:
						//trace("unknown action "+Common.eskinmaster[eskin][file].code[tt].action);
				}
			}
		}
	}

	private function hide_elements(eskin:String, file:String) {
	    //trace("hide processing "+eskin+" "+file);

		// loop the eskin
		for(var tt=0;tt<Common.eskinmaster[eskin][file].code.length;tt++) {
			// process
			switch(Common.eskinmaster[eskin][file].code[tt].action) {
				case 'include':
					this.hide_elements(eskin,Common.eskinmaster[eskin][file].code[tt].name);
					break;
				case 'shared':
					this.hide_elements("shared",Common.eskinmaster[eskin][file].code[tt].name);
					break;
				case 'image':
					this.eskinMC[Common.eskinmaster[eskin][file].code[tt].name].removeMovieClip();
					break;
				default:
					//trace("skipped action "+Common.eskinmaster[eskin][file].code[tt].action);
			}
		}
	}

	public function update_hyper(eskin:String, file:String, hyper:Number, segname:String,refresh:Boolean, getdata) {
		//trace("update_hyper for "+eskin+":"+file+" segment: "+segname);

		// loop the eskin
		for(var tt=0;tt<Common.eskinmaster[eskin][file].code.length;tt++) {
			// process
			switch(Common.eskinmaster[eskin][file].code[tt].action) {
				case 'include':
					this.update_hyper(eskin,Common.eskinmaster[eskin][file].code[tt].name, hyper, segname,refresh,getdata);
					continue;
				case 'shared':
					this.update_hyper("shared",Common.eskinmaster[eskin][file].code[tt].name, hyper, segname,refresh,getdata);
					continue;
			}

			// see if this is for us
			if(segname != Common.eskinmaster[eskin][file].code[tt].segname) continue;  // our segment
			if(Common.eskinmaster[eskin][file].code[tt].hyper==undefined) continue; // not hyper updated
			if(refresh==false && this.eskinMC[Common.eskinmaster[eskin][file].code[tt].name]._visible==true) continue;  // don't redraw unless refresh

			//trace("hyper: "+hyper+" block: "+Common.eskinmaster[eskin][file].code[tt].hyper);

			if(hyper<=Common.eskinmaster[eskin][file].code[tt].hyper) {
				//trace(".. drawing");
				switch(Common.eskinmaster[eskin][file].code[tt].action) {
					case 'image':
						draw_image(Common.eskinmaster[eskin][file].code[tt],null,getdata);
						break;
					case 'text':
						draw_text(Common.eskinmaster[eskin][file].code[tt],this.eskinMC,null,getdata,undefined);
						break;
					case 'if':
						this.perform_if(Common.eskinmaster[eskin][file].code[tt],this.eskinMC,null,getdata);
						break;
					default:
						//trace("unknown action "+Common.eskinmaster[eskin][file].code[tt].action);
				}
			} else {
				//trace(".. clearing out");
				if(Common.eskinmaster[eskin][file].code[tt].action=="if" && Common.eskinmaster[eskin][file].code[tt].swap!=true) {
					for(var jj=0;jj<Common.eskinmaster[eskin][file].code[tt].length;jj++) {
						this.eskinMC[Common.eskinmaster[eskin][file].code[tt].code[jj].name]._visible=false;
					}
				} else if(Common.eskinmaster[eskin][file].code[tt].swap!=true) {
					this.eskinMC[Common.eskinmaster[eskin][file].code[tt].name]._visible=false;
				}
			}
		}
	}

	private function perform_if(block:Object,thisMC:MovieClip, who,getdata, fortile) {
		//trace(".. if block "+block.condition);

		if(ifcheck(thisMC, 'FAKENAME12345', block.condition, who, getdata)) {  // draw
			for(var tt=0;tt<block.code.length;tt++) {
				/*if(this.depthtrack[block.code[tt].name]==undefined) {
					this.depthtrack[block.code[tt].name]=this.nextdepth++;
					//trace(" non-seg if: "+block.code[tt].name+" depth "+this.depthtrack[block.code[tt].name]);
				}*/
				switch(block.code[tt].action) {
					case 'image':
						if(fortile==true) {
		//					trace("if using tile image");
							draw_tile_image(thisMC, block.code[tt],who,getdata);
						} else {
							draw_image(block.code[tt],who,getdata);
						}
						break;
					case 'text':
						draw_text(block.code[tt],thisMC,who,getdata,undefined);
						break;
					default:
						//trace("unknown action "+block.code[tt].action);
				}
			}
		} else {  // clear
			for(var tt=0;tt<block.code.length;tt++) {
				/*if(this.depthtrack[block.code[tt].name]==undefined) {
					this.depthtrack[block.code[tt].name]=this.nextdepth++;
					//trace(" non-seg if: "+block.code[tt].name+" depth "+this.depthtrack[block.code[tt].name]);
				}*/
				//trace("swap 1"+block.code[tt].swap);
				if(block.code[tt].name != undefined && block.code[tt].swap!=true) {
					thisMC[block.code[tt].name]._visible=false;
					//trace(".... cleared "+block.code[tt].name);
				}
			}
		}
	}

	private function update_hyper_fanart(segnum, hyper, getdata, refresh, redraw) {
		if(this.segments[segnum].settings.fanart==undefined) return;
		//trace("FANART STARTED");

		if(refresh==false && this.eskinMC.evfn._visible==true && redraw!=true) {
			//trace(".. skipped");
			return;
		}

		//trace("visible status: "+this.eskinMC.evfn._visible);
		//trace("refresh: "+refresh);
		//trace("redraw: "+redraw);

		if(hyper<=this.segments[segnum].settings.fanart.hyper || redraw==true) {
			//trace(".. drawing");
			var showing:String=process_variable(this.segments[segnum].settings.fanart.file,null,getdata);
			//Loadimage.uiload("evfn", this.eskinMC, 0,0,1280,720,this.depthtrack.evfn, showing, this.fn.updatedepthtrack);
			Loadimage.bgload("evfn", this.eskinMC, this.depthtrack.evfn, showing);
		}
/*		else {
			trace("FANART HYPER: "+this.segments[segnum].settings.fanart.hyper);
			trace("USER HYPER: "+hyper);
			if(this.segments[segnum].settings.fanart.hyper <= hyper) {
			    trace(".. clearing fanart");
				this.eskinMC.evfn._visible=false;
			}
		} */
	}

	public function update_segname(eskin:String, file:String, segname:String, getdata) {
		//trace("update_segname for "+eskin+":"+file+" segment: "+segname);

		// loop the eskin
		for(var tt=0;tt<Common.eskinmaster[eskin][file].code.length;tt++) {
			// process
			switch(Common.eskinmaster[eskin][file].code[tt].action) {
				case 'include':
					this.update_segname(eskin,Common.eskinmaster[eskin][file].code[tt].name,segname,getdata);
					continue;
				case 'shared':
					this.update_segname("shared",Common.eskinmaster[eskin][file].code[tt].name, segname,getdata);
					continue;
			}

			// see if this is for us
			if(segname != Common.eskinmaster[eskin][file].code[tt].segname) continue;  // our segment
			//trace("name:"+Common.eskinmaster[eskin][file].code[tt].name+" hyper:"+Common.eskinmaster[eskin][file].code[tt].hyper);

			if(Common.eskinmaster[eskin][file].code[tt].hyper!=undefined) continue; // not hyper updated

			switch(Common.eskinmaster[eskin][file].code[tt].action) {
				case 'image':
					draw_image(Common.eskinmaster[eskin][file].code[tt],null,getdata);
					break;
				case 'text':
					draw_text(Common.eskinmaster[eskin][file].code[tt],this.eskinMC,null,getdata,undefined);
					break;
				case 'if':
					this.perform_if(Common.eskinmaster[eskin][file].code[tt],this.eskinMC,null,getdata);
					break;
				default:
					trace("unknown action "+Common.eskinmaster[eskin][file].code[tt].action);
			}
		}
	}

// ************* Overall+UI **************
	// meant to be called when we know what we're drawing
	public function skin_start(eskinfile:String,tempgetdata:Function, jbgetdata:Function) {
		trace("starting eskin "+eskinfile);

		// prep
		this.eskinfile=eskinfile.toLowerCase();
		if(tempgetdata!=undefined) this.tempgetdata=tempgetdata;
		if(jbgetdata!=undefined) this.jbgetdata=jbgetdata;

		if(Common.eskinmaster[this.eskinmaster][this.eskinfile]==undefined) {
			trace("need to load skin first");
			Preloader.update(Common.evPrompts.loading+" "+Common.evPrompts.eskin.toLowerCase());
			this.eskinload=new Eskinload(this.eskinMC,this.fn.eskinloaded);
			this.eskinload.eskin_loadfile(eskinfile, this.eskinmaster);
		} else {
			trace("skin loaded, ready to start");
			this.callback("LOADED");
			this.skin_firstdraw();
			this.eskinload.cleanup();
			this.eskinload=null;
			this.callback("ACTIVATE");
		}
	}

	private function eskinloaded(loaded:Boolean,message) {
		if(loaded) {
			trace("eskin loaded, starting");
			this.callback("LOADED");
			this.skin_firstdraw();
		} else {
			trace("eskin load failed");
			this.callback("ERROR",Common.evPrompts.enoload+message);
		}
	}

	private function skin_firstdraw() {
		if(Common.evRun.bghighres!=true) {
			Loadimage.bgclearall();
		}

		// draw the ui
		this.skin_draw();

		// start the segments
		this.segment_load();
	}

	// meant to be called for first draw
	public function skin_draw() {
		trace(". first ui draw for "+this.eskinfile);

		// placeholders
		if(this.nextdepth==null) {
			this.nextdepth=this.eskinMC.getNextHighestDepth();
			trace("!! starting depth="+this.nextdepth);
		}

		this.depthtrack.evbg=this.nextdepth++;
		//this.eskinMC.createEmptyMovieClip("evbg", this.depthtrack.evbg);
	//	trace("evbg "+this.depthtrack.evbg);

		this.depthtrack.evfn=this.nextdepth++;
		//this.eskinMC.createEmptyMovieClip("evfn", this.depthtrack.evfn);
	//	trace("evfn "+this.depthtrack.evfn);


		this.show_elements(this.eskinmaster,this.eskinfile,1,true,null,{get_data:this.jbgetdata}); // first run call
		this.draw_background({get_data:this.jbgetdata});
	}

	// meant to be called when we're hiding the ui
	public function skin_memory_clear() {
	//	trace("esrun: clearing ui");

		this.hide_elements(this.eskinmaster,this.eskinfile);
		this.eskinMC.evbg.removeMovieClip();
		this.eskinMC.evfn.removeMovieClip();
	}

	// meant to call when a screen returns into view
	public function skin_redraw(getdata) {
	//	trace("esrun: ui redraw called");

		//if(getdata.get_data==undefined) getdata={get_data:this.jbgetdata};

		this.show_elements(this.eskinmaster,this.eskinfile,1,false,undefined,getdata);
		this.draw_background(getdata);
	}

	public function skin_update(segnum, hyper, getdata, refresh, redraw) {
	//	trace("skin_update called "+hyper);

		this.update_hyper(this.eskinmaster,this.eskinfile,hyper,this.segments[segnum].name,refresh,getdata);
		this.update_hyper_fanart(segnum, hyper, getdata, refresh, redraw);
	}

	public function skin_segname_update(segnum, getdata) {
	//	trace("skin_segname_update called");
		this.update_segname(this.eskinmaster,this.eskinfile,this.segments[segnum].name,getdata);
	}

// ************** tile *******************
	private function draw_tile(segment:Number, who:Number, tileMC:MovieClip, getdata:Function,hl:Boolean) {
	//	trace("draw_tile for segment "+segment);

		tileMC.ev=true;

		for(var tt=0;tt<this.segments[segment].tile[0].code.length;tt++) {
			switch(this.segments[segment].tile[0].code[tt].action) {
				case 'text':
					this.draw_text(this.segments[segment].tile[0].code[tt],tileMC,who,getdata,hl);
					break;
				case 'image':
					this.draw_tile_image(tileMC, this.segments[segment].tile[0].code[tt],who,getdata,hl);
					break;
				default:
					//trace(".. "+this.segments[segment].tile[0].code[tt].action);
			}
		}
	}

	private function highlight_tile(hl:Boolean, segment:Number, who:Number, tileMC:MovieClip, getdata:Function) {
		//trace("highlight_tile: "+hl+" for segment "+segment);

		for(var tt=0;tt<this.segments[segment].tile[0].code.length;tt++) {
			switch(this.segments[segment].tile[0].code[tt].action) {
				case 'text':
					this.highlight_text(this.segments[segment].tile[0].code[tt],tileMC,hl,who,getdata);
					break;
				case 'image':
					this.highlight_image(this.segments[segment].tile[0].code[tt],tileMC,hl,who,getdata);
					break;
				default:
					//trace(".. "+this.segments[segment].tile[0].code[tt].action);
			}
		}
	}

// ************** HL *******************
	private function highlight_image(block:Object,thisMC:MovieClip,hl, who,getdata) {
		//trace(".. hl image "+hl+" "+block.name);
		//trace("+++ block.highlight: "+block.highlight);
		//trace("+++ hl: "+hl);


/*		trace("testing, whats in thisMC");
		for (var i in thisMC) {
			if (typeof (thisMC[i]) == "movieclip") {
				trace(".. found: "+thisMC[i]._name+" visible: "+thisMC[i]._visible);
				//if(thisMC[i]._name=="icon_ribbon") thisMC[i]._visible=false;
			}
		}		*/

		// if a highlight only text and not highlighting
		if(block.highlight==true && !hl) {
			thisMC[block.name]._visible=false;
			//trace("++++ hidden");
		} else if(block.highlight==false && hl) {
			thisMC[block.name]._visible=false;
			//trace("++++ hidden");
		} else {
			thisMC[block.name]._visible=true;
			//trace("++++ default show");
		}
	}

	private function highlight_text(block:Object,thisMC:MovieClip,hl, who,getdata) {
	 	//trace(".. hl text "+hl+" "+block.name);

		// if a highlight only text and not highlighting
		if(block.highlight==true && !hl) {
			thisMC[block.name]._visible=false;
			return;
		} else if(block.highlight==false && hl) {
			thisMC[block.name]._visible=false;
			return;
		}

		if(block.name=="clock" || block.name=="date") return;

		// adjust
		if(block.wordwrap) {
			thisMC[block.name].multiline=true;
			thisMC[block.name].wordWrap=block.wordwrap;
		}

		var txtfmt = new TextFormat();
		if(block.font != undefined) {
			txtfmt.font=block.font;
		}
		txtfmt.align=block.align;
		txtfmt.size=block.size;
		if(hl) {
			txtfmt.color=block.hlcolor;
		} else {
			txtfmt.color=block.color;
		}
		txtfmt.bold=block.bold;
		txtfmt.italic=block.italic;
		txtfmt.underline=block.underline;
		txtfmt.leading=block.leading;

		// fill
		thisMC[block.name].setTextFormat(txtfmt);
		thisMC[block.name]._visible=true;

		delete txtfmt;
	}


// ************** DRAW *******************
	public function draw_text(block:Object,thisMC:MovieClip, who,getdata, hl:Boolean) {
	//	trace(".. text "+block.name);

		// if check
		if(!ifcheck(thisMC, block.name, block.condition, who, getdata)) return;

		// draw
		if(thisMC[block.name]._visible==undefined) {
	//		trace("creating text MC");
			if(this.depthtrack[block.name]==undefined) {
				this.depthtrack[block.name]=this.nextdepth++;
				//trace(" non-seg if: "+block.code[tt].name+" depth "+this.depthtrack[block.name]);
			}
			thisMC.createTextField(block.name, this.depthtrack[block.name], block.posx, block.posy, block.width, block.height);
			if(thisMC!=this.eskinMC) thisMC._visible=true;
		}

		// adjust
		if(block.wordwrap) {
			thisMC[block.name].multiline=true;
			thisMC[block.name].wordWrap=block.wordwrap;
		}

		var txtfmt = new TextFormat();
		if(block.font != undefined) {
			txtfmt.font=block.font;
		}
		txtfmt.align=block.align;
		txtfmt.size=block.size;
		txtfmt.color=block.color;
		txtfmt.bold=block.bold;
		txtfmt.italic=block.italic;
		txtfmt.underline=block.underline;
		txtfmt.leading=block.leading;

		// fill
		switch(block.name) {
			case 'clock':
				thisMC.clock.text=" ";
				thisMC.clock.setTextFormat(txtfmt);
				Background.update_clock(thisMC);
				break;
			case 'date':
				thisMC.date.text=" ";
				thisMC.date.setTextFormat(txtfmt);
				Background.update_date(thisMC);
				break;
			default:
				if(block.html==true) {
					thisMC[block.name].htmlText=process_variable(block.display,who,getdata);
				} else {
					thisMC[block.name].text=process_variable(block.display,who,getdata);
				}
				thisMC[block.name].setTextFormat(txtfmt);
				break;
		}

		if(block.highlight==true && !hl) {
			thisMC[block.name]._visible=false;
			//trace("++++ hidden");
		} else if(block.highlight==false && hl) {
			thisMC[block.name]._visible=false;
			//trace("++++ hidden");
		} else {
			thisMC[block.name]._visible=true;
			//trace("++++ default show");
		}

		delete txtfmt;
	}

	private function ifcheck(thisMC, blockname, condition, who, getdata) {
		// if check
		if(condition != undefined) {

			if(!this.process_condition(condition, who, getdata)) {
			//	trace("condition failed, hiding");
				if(thisMC[blockname]._visible==true) thisMC[blockname]._visible=false;
				return(false);
			}
		}

		return(true);
	}

	private function draw_image(block:Object,hyper,getdata) {
		//trace(".. ui image "+block.name);

		if(!ifcheck(this.eskinMC, block.name, block.condition, null, getdata)) return;

		//trace("..... file: "+block.file);
		var showing:String=process_variable(block.file,null,getdata);
		//trace("..... processed url: "+showing);
		Loadimage.uiload(block.name, this.eskinMC, block.posx,block.posy,block.width,block.height,this.depthtrack[block.name], showing, this.fn.updatedepthtrack,true, block.keepaspect,block.valigned,block.haligned);
	}

	private function draw_tile_image(thisMC:MovieClip, block:Object, who,getdata,hl:Boolean) {
		//trace(".. tile image "+block.name);

		if(!ifcheck(thisMC, block.name, block.condition, who, getdata)) return;

		if(block.highlight==false && hl==true) {
			hl=false;
		} else if(block.highlight==false && hl==false) {
			hl=true;
		} else if(block.highlight==undefined) {
			hl=true;
		}

		thisMC._visible=true;
		var showing:String=process_variable(block.file, who,getdata);
		Loadimage.load(block.name, thisMC, block.posx,block.posy,block.width,block.height,showing,block.keepaspect,block.valigned,block.haligned,hl);

		//trace("tile block: "+block.name+" highlight: "+block.highlight);
/*		if(block.highlight==true) {
			trace(".. set to hidden");
			thisMC[block.name]._visible=false;
		} else {
			thisMC[block.name]._visible=true;
			trace(".. set to visible");
		}*/
	}

	private function draw_background(getdata) {
		if(Common.eskinmaster[this.eskinmaster][this.eskinfile].control.background != undefined) {
			//trace(".. background");
			// variables
			var showing:String=process_variable(Common.eskinmaster[this.eskinmaster][this.eskinfile].control.background,null,getdata);

			Loadimage.bgclearpart();

			// show it
			//if(Common.eskinmaster[this.eskinmaster][this.eskinfile].control.backgroundhighres==false || Common.evRun.bghighres!=true) {
				/*if( Common.evRun.bghighres==true && Common.eskinmaster[this.eskinmaster][this.eskinfile].control.fullscreen==true && Common.eskinmaster[this.eskinmaster][this.eskinfile].control.clearhighresbg==false) {
					var showit:Boolean=false;
				} else */

				var showit:Boolean=true;

				trace("background image loading with flash");
				if(Common.evSettings.overscanbg=="true" && Common.evSettings.overscan=="true") {
					var x:Number=0+Common.evSettings.overscanxshift;
					var y:Number=0+Common.evSettings.overscanyshift;
					var w:Number=1280*Common.evSettings.overscanx;
					var h:Number=720*Common.evSettings.overscany;
				} else {
					var x:Number=0;
					var y:Number=0;
					var w:Number=1280;
					var h:Number=720;
				}
				Loadimage.uiload("evbg", this.eskinMC, x, y, w, h,this.depthtrack.evbg, showing, this.fn.updatedepthtrack, showit);
			//} else {
			//	trace("background image loading highres");
			//	Loadimage.bgload("evbg", this.eskinMC, this.depthtrack.evbg, showing);
			//}
		} else {
			trace(".. no background to show");
		}
	}

    private function draw_cursor(segment, thisMC) {
		trace("drawing cursor");
		var url:String=process_variable(this.segments[segment].cursor.file);
		//Loadimage.load("cursor", thisMC, this.segments[segment].cursor.posx,this.segments[segment].cursor.posy,this.segments[segment].cursor.width,this.segments[segment].cursor.height,url);
		Loadimage.load("cursor", thisMC,0,0,this.segments[segment].cursor.width,this.segments[segment].cursor.height,url);
	}

// ************* SEGMENT ******************
	private function segment_load() {
		trace("starting segment start");

		this.segments=new Object();

		// find the segments
		//trace(". "+this.efiles.length+" files to check");
		for(var tt=0;tt<this.efiles.length;tt++) {
			this.segment_find(this.efiles[tt].eskin,this.efiles[tt].file);
		}

		// turn off temp segment data
		this.tempgetdata=undefined;

		trace("done adding segments");
	}

	private function segment_find(eskin:String, file:String) {
		//trace("erun: .. looking in "+eskin+":"+file);
		//trace("erun: ... total: "+Common.eskinmaster[eskin][file].segments.length);

		for(var tt=0;tt<Common.eskinmaster[eskin][file].segments.length;tt++) {
			trace("%%%%%%%%%%%% .... "+Common.eskinmaster[eskin][file].segments[tt].name);
			// add segment to quick list
			//this.segments.push(Common.eskinmaster[eskin][file].segments[tt]);

			// check condition
			if(Common.eskinmaster[eskin][file].segments[tt].settings.condition != undefined) {
				trace("!!!! THERES A CONDITION ON THIS SEGMENT");
				trace("!!!!!!! "+Common.eskinmaster[eskin][file].segments[tt].settings.condition);
				if(!this.process_condition(Common.eskinmaster[eskin][file].segments[tt].settings.condition, null,{get_data:this.jbgetdata})) {
					trace("!!! IF FAILED");
					continue;
				}
			}

			// depth  (just in case, sort of mini-legacy)
			if(this.depthtrack["SEG"+Common.eskinmaster[eskin][file].segments[tt].name]==undefined) {
				this.depthtrack["SEG"+Common.eskinmaster[eskin][file].segments[tt].name]=this.nextdepth++;
				//trace(" non-seg if: "+block.code[tt].name+" depth "+this.depthtrack[block.name]);
			}

			// add segment to screen
			var segnum=this.callback("ADDSEG",null,{eskin:eskin,file:file,member:tt,mcname:Common.eskinmaster[eskin][file].segments[tt].name,mcdepth:this.depthtrack[Common.eskinmaster[eskin][file].segments[tt].name]});
			//trace("erun segment is "+segnum);
			if(segnum!=-1) {
				this.segments[segnum]=Common.eskinmaster[eskin][file].segments[tt];
				this.callback("SEGLAUNCH",null,{segnum:segnum,mcname:"SEG"+Common.eskinmaster[eskin][file].segments[tt].name,mcdepth:this.depthtrack["SEG"+Common.eskinmaster[eskin][file].segments[tt].name]});
			}
		}
	}


// ************** VARIABLES ****************

	public function process_variable(original:String,who,getdata):String {
		//trace("! scrubing: "+original);

		var cleaned:String=original;
		var vartag:String=null;

		while(vartag=find_variable(cleaned)) {
			// process
			var data:String=do_variable(vartag,who,getdata);

			// replace
			if(data==vartag) {
				cleaned=StringUtil.remove(cleaned,vartag);
			} else {
				cleaned=StringUtil.replace(cleaned,vartag,data);
			}
		}

		//trace("! final: "+cleaned);
		return(cleaned);
	}

	private function find_variable(hay:String) {
		var start:Number=hay.indexOf("[:");
		if(start==-1) return(null);

		var end:Number=hay.indexOf(":]");
		if(end==-1) return(null);

		var vartag=hay.substr(start,end-start+2);
		//trace("var tag: "+vartag);

		return(vartag);
	}

	private function do_variable(vartag:String,who,getdata):String {
		// pull out the var
		var stripped:String=vartag.substr(2,vartag.length-4);
		//trace("stripped: "+stripped);

		// split by ,
		var modcheck:Array=stripped.split(",");  // checks at end if any
		var howmany:Number=undefined;

		// if length isn't 1
		if(modcheck.length>1) {
			// process modifiers
			//trace("var modifiers found");

			for(var tt=1;tt<modcheck.length;tt++) {
				if(Data.is_numeric(modcheck[tt]) == true) {
					howmany=int(modcheck[tt]);
				}
			}
        }

        // re adjust for processing
		// put stripped back to single
		stripped=modcheck[0];
		//trace("post mod stripped: "+stripped);

		if(stripped.length<2) {
			trace("var missing");
			return("");
		}

		var pulled:String=StringUtil.remove(stripped.substr(1)," ");
		//trace("pulled: "+pulled);

		// process
		var newdata:String=null;

		// convert
		switch(stripped.charAt(0)) {
			case '@':
				//trace("ev int");
				newdata=do_var_evint(pulled,getdata);
				break;
			case '&':
				//trace("ev setting");
				newdata=Common.evSettings[pulled];
				break;
			case '#':
				//trace("eskin setting");
				newdata=Common.esSettings[pulled];
				break;
			case '$':
				//trace("eskin lang");
				newdata=Common.esPrompts[pulled];
				break;
			case '%':
				//trace("ev lang");
				newdata=Common.evPrompts[pulled];
				break;
			default:
				//trace("jukebox");
				newdata=do_var_jukebox(stripped,who,getdata,howmany);
				break;
		}

		//trace("newdata now "+newdata);

		if(newdata!=null && newdata!=undefined) {
			// if length isn't 1
			if(modcheck.length>1) {
				// process modifiers
				//trace("var modifiers found");

				for(var tt=1;tt<modcheck.length;tt++) {
					//trace("... checking modifier: "+modcheck[tt]);
					switch(modcheck[tt]) {
						case 'upper':
							newdata=newdata.toUpperCase();
							break;
						case 'lower':
							newdata=newdata.toLowerCase();
							break;
						case 'unescape':
							newdata=unescape(newdata);
							break;
						case 'escape':
							newdata=escape(newdata);
							break;
						case 'blank':
							if(newdata=="UNKNOWN" || newdata=="unknown") newdata="";
							break;
						case 'unknown':
							if(newdata=="UNKNOWN" || newdata=="unknown") newdata=Common.evPrompts.unknown;
							break;
						case 'unknownupper':
							if(newdata=="UNKNOWN" || newdata=="unknown") newdata=Common.evPrompts.unknown.toUpperCase();
							break;
						case 'unknownlower':
							if(newdata=="UNKNOWN" || newdata=="unknown") newdata=Common.evPrompts.unknown.toLowerCase();
							break;
						case 'evtrans':
							newdata=Common.evPrompts[newdata.toLowerCase()];
							break;
						case 'estrans':
							newdata=Common.esPrompts[newdata.toLowerCase()];
							break;
						case 'round':
							newdata=Math.round(Number(newdata)).toString();
							break;
						case 'abs':
							newdata=Math.abs(Number(newdata)).toString();
							break;
						case 'ceil':
							newdata=Math.ceil(Number(newdata)).toString();
							break;
						case 'floor':
							newdata=Math.floor(Number(newdata)).toString();
							break;
						case 'sqrt':
							newdata=Math.sqrt(Number(newdata)).toString();
							break;
						case 'length':
							newdata=newdata.length.toString();
							break;
						case 'nospaces':
							newdata=StringUtil.replace(newdata," ","");
							break;
						case 'filesafe':
							newdata=StringUtil.replace(newdata,"/",".");
							newdata=StringUtil.replace(newdata,"\\",".");
							newdata=StringUtil.replace(newdata,"?",".");
							newdata=StringUtil.replace(newdata,"*",".");
							newdata=StringUtil.replace(newdata,":",".");
							newdata=StringUtil.replace(newdata,"<",".");
							newdata=StringUtil.replace(newdata,">",".");
							newdata=StringUtil.replace(newdata,'"',".");
							newdata=StringUtil.replace(newdata,"|",".");
							break;
						case 'yamjfilesafe':
							newdata=StringUtil.replace(newdata,"/","-");
							newdata=StringUtil.replace(newdata,"\\","-");
							newdata=StringUtil.replace(newdata,"?","-");
							newdata=StringUtil.replace(newdata,"*","-");
							newdata=StringUtil.replace(newdata,":","-");
							newdata=StringUtil.replace(newdata,"<","-");
							newdata=StringUtil.replace(newdata,">","-");
							newdata=StringUtil.replace(newdata,'"',"-");
							newdata=StringUtil.replace(newdata,"|","-");
							break;
						default:
							//trace("unknown modifier");
							if(StringUtil.beginsWith(modcheck[tt], "slice")) {
								// slice
								var howmany:Number=int(modcheck[tt].slice(5));
								//trace("sliced at "+howmany);
								if(newdata.length>howmany) {
									newdata=newdata.slice(howmany);
								} else newdata="";
							} else if(StringUtil.beginsWith(modcheck[tt], "trun")) {
								// truncate
								var howmany:Number=int(modcheck[tt].slice(4))+3;
								//trace("truncated by "+howmany);
								if(newdata.length>howmany) {
									newdata=newdata.substring(0,howmany)+"...";
								}
							} else if(StringUtil.beginsWith(modcheck[tt], "cut")) {
								// cut
								var howmany:Number=int(modcheck[tt].slice(3));
								//trace("cut by "+howmany);
								if(newdata.length>howmany) {
									newdata=newdata.substring(0,howmany);
								}
							}
							break;
					}
					//trace("modified new data: "+newdata);
				}
			}
			//trace("modified new data: "+newdata);
			return(newdata);
		}

		return(vartag);
	}

	private function do_var_jukebox(data:String,who,getdata,howmany):String {
		var newdata:String=null;

		newdata=getdata.get_data(data,who,howmany);

		return(newdata);
	}

	private function do_var_evint(data:String,getdata:Object):String {
		var newdata:String=null;

		switch(data) {
			case 'sharedmedia':  	// path to shared eskin media folder
				newdata=Common.evSettings.eskinrootpath+"shared/media/";
				break;
			case 'media':  			// path to eskin media folder
				newdata=Common.evSettings.eskinrootpath+this.eskinmaster+"/media/";
				break;
			case 'jukebox':      	// path to jukebox folder
				newdata=Common.evSettings.yamjdatapath;
				break;
			case 'eskin':      		// path to eskin folder
				newdata=Common.evSettings.eskinrootpath+this.eskinmaster+"/";
				break;
			case 'evversion':
			case 'evrversion':
			case 'yamjversion':
			case 'yamjrversion':
				newdata=Common.evRun[data];
				break;
			case 'totalvideos':
				newdata=Common.evRun.ystatstotal;
				break;
			case 'totalmovies':
				newdata=Common.evRun.ystatsmovies;
				break;
			case 'totaltv':
				newdata=Common.evRun.ystatstv;
				break;
			case 'model':
				newdata=Common.evRun.hardware.modelname;
				break;
			case 'firmware':
				newdata=Common.evRun.hardware.firmware;
				break;
			case 'hardwareid':
			case 'macaddress':
				newdata=Common.evRun.hardware.id;
				break;
			case 'eskinname':
				newdata=Common.eskinmaster[Common.evSettings.eskin].settings.info.name;
				break;
			case 'eskinversion':
				newdata=Common.eskinmaster[Common.evSettings.eskin].settings.info.version;
				break;
			case 'eskinhomepage':
				newdata=Common.eskinmaster[Common.evSettings.eskin].settings.info.homepage;
				break;
			case 'jbtimestamp':
				newdata=Background.verlasttime;
				break;
			case 'artworkscanner':
				newdata="NO";
				if(Background.artworkscanner==true) newdata="YES";
				break;
			default:
				if(this.tempgetdata != undefined && this.tempgetdata !=null) {  // check the temp data for answer
					//trace("trying tempgetdata");
					newdata=this.tempgetdata(data);
				}

				if(getdata!= undefined && (newdata==null || newdata==undefined)) {     // check the segment data for answer
					newdata=getdata.get_ev_data(data);
				}

				if(newdata==null || newdata==undefined) {
					trace("unknown evint "+data);
				}
		}

		return(newdata);
	}

// ************* process condition *****************
	public function process_condition(statement:String, who, getdata) {
		//trace("condition check for "+statement);

		if(statement.indexOf(" ++ ") != -1) {
			// split the multiples
			var testing:Array=statement.split(" ++ ");
			//trace(".. "+testing.length+" statements to check");

			// loop them
			for(var tt=0;tt<testing.length;tt++) {
				var current:String=StringUtil.trim(testing[tt]);
				//trace(".. checking: "+current);

				// if do fails return false
				if(!do_condition(current, who, getdata)) return(false);
			}
		} else if(statement.indexOf(" || ") != -1) {
			// split the multiples
			var testing:Array=statement.split(" || ");
			//trace(".. "+testing.length+" statements to check");

			// loop them
			for(var tt=0;tt<testing.length;tt++) {
				var current:String=StringUtil.trim(testing[tt]);
				//trace(".. checking: "+current);

				// if do works return true
				if(do_condition(current, who, getdata)) return(true);
			}
			// otherwise it failed.
			return(false);
		} else {
			if(!do_condition(statement, who, getdata)) {
				//trace("condition didn't pass");
				return(false);
			}
		}

		// we passed
		//trace("condition passed");
		return(true);
	}

	private function do_condition(statement:String, who, getdata) {
		//trace("do_condition check for "+statement);

		var parts:Array=statement.split(":] ");
		var data=parts[0]+":]";

		// split by space
		var parts:Array=parts[1].split(" ");

		if(parts.length<2) {
			trace("incomplete condition statement");
			return
		}

		var opera=parts.shift().toString();
		//trace(".... opera: "+opera);
		var value:String=parts.join(" ");
		//trace(".... value: "+value);

		// get variable
		data=process_variable(data,who,getdata);
		value=process_variable(value,who,getdata);

		//trace("PRE CONDITION: "+data+" "+opera+" "+value);

		if(value == "unknown") value="UNKNOWN";
		if(data == "unknown") data="UNKNOWN";
		//if(value == "undefined") value=undefined;
		//if(value == "null") value=null;
		if(value == "blank") value="";
		if(data == undefined || data == "undefined" || data==null || data=="") data=undefined;
		if(value == undefined || value == "undefined" || value==null || value=="") value=undefined;

		// switch compare
		trace("CONDITION: "+data+" "+opera+" "+value);
		switch(opera) {
			case '===':
				if(data === value) return(true);
				break;
			case '==':
			case '=':
				if(data == value) return(true);
				break;
			case '!=':
				if(data != value) return(true);
				break;
			case '!==':
				if(data !== value) return(true);
				break;
			case '>':
			case '&gt':
				if(data==undefined) return(false);
				if(Number(data) > Number(value)) return(true);
				break;
			case '<':
			case '&lt':
				if(data==undefined) return(false);
				if(Number(data) < Number(value)) return(true);
				break;
			case '&gt=':
			case '=&gt':
			case '>=':
			case '=>':
				if(data==undefined) return(false);
				if(Number(data) >= Number(value)) return(true);
				break;
			case '&lt=':
			case '=&lt':
			case '<=':
			case '=<':
				if(data==undefined) return(false);
				if(Number(data) <= Number(value)) return(true);
				break;
			case 'contains':
				if(data.indexOf(value) != -1) return(true);
				break;
			case 'startswith':
				return(StringUtil.beginsWith(data, value));
				break;
			case 'endswith':
				return(StringUtil.endsWith(data, value));
				break;
			default:
				trace("unknown opera "+opera);
				return(false);
		}

		return(false);
	}

// ************** DEPTH CONTROL *********************
	private function updatedepthtrack(who:String, depth:Number) {
		//trace("update depth "+depth+" for "+who);

		if(who==null && depth==null) return;

		this.depthtrack[who]=depth;
	}
}