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
import tools.Data;
import tools.StringUtil;
import api.RemoteControl;
import mx.xpath.XPathAPI;
import mx.utils.Delegate;

class ev.Eskinload {
	private var fn:Object = null;
	private var activeMC:MovieClip = null;
	private var callBack:Function = null;

	private var currentfile:String=null;
	private var arrayname:String=null;
	private var arraysave:String=null;
	private var mastername:String=null;
	private var equeue:Array=null;
	private var squeue:Array=null;
	private var segment:Object=null;

	private var missingname:Number=null;
	private var firstload:Boolean=false;


	// cleanup, called to clear everything in the class
	public function cleanup():Void {
		delete this.fn;
		this.fn=null;

		delete this.equeue;
		delete this.squeue;
		this.equeue=null;
		this.squeue=null;
		delete this.segment;
		this.segment=null;

		this.currentfile=null;
		this.arrayname=null;
		this.arraysave=null;
		this.mastername=null;

		this.activeMC=null;
		this.callBack=null;

		this.missingname=0;
	}

	function Eskinload(activeMC:MovieClip,callBack:Function) {
		this.cleanup();

		this.activeMC=activeMC;
		this.callBack=callBack;

		this.fn = {	onloadskin:Delegate.create(this, this.onloadskin)
			};

		// prep the arrays
		this.equeue=new Array();
		this.squeue=new Array();
		this.arraysave=Common.evSettings.eskin;
	}

	public function first_load() {
		this.firstload=true;

		this.activeMC.message_txt.text="Loading "+Common.evSettings.eskin.toUpperCase()+"..";
		trace("eskin load "+Common.evSettings.eskin);

		Common.eskinmaster[this.arraysave]=new Object();
		Common.eskinmaster.shared=new Object();
		Common.eskinmaster[this.arraysave].settings=new Array();

		// get the master control file
		this.eskin_loadfile("load");
	}

	function eskin_loadfile(filename:String, masterskin:String) {
		trace("loadfile started "+filename+" master "+masterskin);

		// see if we're queue processing
		if(filename==undefined) {
			////trace(".. queue load");

			filename=null;
			if(this.equeue.length != 0) {
				filename=this.equeue.pop().toString();
				if(masterskin==undefined) {
					this.arraysave=Common.evSettings.eskin;
				} else {
					this.arraysave=masterskin;
				}
				trace("arraysave is "+this.arraysave);
			} else if(this.squeue.length != 0) {
				filename=this.squeue.pop().toString();
				this.arraysave="shared";
			} else {
				trace("nothing in queue");
			}
		}

		// see if we need this file
		if(filename!=null) {
			if(masterskin!=undefined) this.arraysave=masterskin;
			this.arrayname=filename.toLowerCase();
			if(Common.eskinmaster[this.arraysave][this.arrayname] == undefined) {
				////trace(".. next file is "+filename);
				this.currentfile=filename;

				// prep the load objects
				Common.eskinmaster[this.arraysave][this.arrayname]=new Object();
				Common.eskinmaster[this.arraysave][this.arrayname].control=new Object();
				Common.eskinmaster[this.arraysave][this.arrayname].code=new Array();
				Common.eskinmaster[this.arraysave][this.arrayname].segments=new Array();
				Common.eskinmaster[this.arraysave][this.arrayname].remote=new Array();
				Common.eskinmaster[this.arraysave][this.arrayname].settings=new Array();

				if(this.mastername==null) {
					this.mastername=this.arrayname;
					Common.eskinmaster[this.arraysave][this.mastername].remote=new Array();
				}

				// load it up
				this.activeMC.message_txt.text=this.arraysave.toUpperCase()+": Loading "+this.currentfile;
				Data.loadXML(Common.evSettings.eskinrootpath+this.arraysave+"/"+"code/"+this.currentfile+".eskin", this.fn.onloadskin);
			} else {
				trace("didn't need "+this.arraysave+":"+this.arrayname);
				////trace("... skipped "+filename+", already loaded");
				this.eskin_loadfile();
			}
		} else {
			trace("done with eskin loading");
			this.callBack(true);
		}
	}

	private function onloadskin(success:Boolean, xml:XML, errorcode) {
		if(success) {
			trace("ready to process "+this.currentfile);
			this.process_eskinfile(xml);
		} else {
			trace("problem loading eskin file.  Error "+errorcode);

			var atxt:String=Common.evSettings.eskin.toUpperCase()+": Error "+errorcode+" in "+this.currentfile+".eskin";
			this.activeMC.message_txt.text=atxt;
			delete Common.eskinmaster[this.arraysave][this.arrayname];
			this.callBack(false, atxt);
		}
	}

	private function process_eskinfile(xml:XML) {
		// allocate array
		this.arrayname=this.currentfile.toLowerCase();

		// process
		trace("processing eskin file");

		// loop the blocks
		var myXML = xml.firstChild.childNodes;
		////trace(".. "+myXML.length+" blocks in the file");
		for (var i=0; i<myXML.length; i++) {
			var blockName=myXML[i].nodeName.toString().toLowerCase();
			////trace(".. block: "+blockName);

			switch(blockName) {
				case 'include':
					if(this.equeue==null) this.equeue=new Array();
					var dataValue=myXML[i].firstChild.nodeValue.toString();
					this.equeue.push(dataValue);
					Common.eskinmaster[this.arraysave][this.arrayname].code.push({action:"include",name:dataValue});
					////trace("... added "+dataValue+" to eskin load queue");
					break;
				case 'shared':
					if(this.squeue==null) this.squeue=new Array();
					var dataValue=myXML[i].firstChild.nodeValue.toString();
					this.squeue.push(dataValue);
					Common.eskinmaster[this.arraysave][this.arrayname].code.push({action:"shared",name:dataValue});
					////trace("... added "+dataValue+" to shared load queue");
					break;
				case 'settings':
					process_block_settings(myXML[i]);
					break;
				case 'control':
					process_block_control(myXML[i]);
					break;
				case 'info':
					process_block_info(myXML[i]);
					break;
				case 'background':
					process_block_background(myXML[i]);
					break;
				case 'image':
					var save=process_block_image(myXML[i]);
					if(save!=null) {
						Common.eskinmaster[this.arraysave][this.arrayname].code.push(save);
					}
					break;
				case 'text':
					var save=process_block_text(myXML[i]);
					if(save!=null) {
						Common.eskinmaster[this.arraysave][this.arrayname].code.push(save);
					}
					break;
				case 'segment':
					process_segment(myXML[i]);
					break;
				case 'if':
					var save=process_block_if(myXML[i]);
					if(save!=null) {
						Common.eskinmaster[this.arraysave][this.arrayname].code.push(save);
					}
					break;
				case 'remote':
					var remote:Object=this.process_remote(myXML[i]);
					if(remote!=null) {
						if(remote.all!=null) {
							Common.eskinmaster[this.arraysave][this.mastername].settings.remoteall=remote;
							////trace(".. added all key");
						} else if(remote.keypad!=null) {
							Common.eskinmaster[this.arraysave][this.mastername].settings.remotekeypad=remote;
							////trace(".. added keypad");
						} else {
							Common.eskinmaster[this.arraysave][this.mastername].remote[remote.keycode]=this.add_to_array(Common.eskinmaster[this.arraysave][this.mastername].remote[remote.keycode],remote);
							//Common.eskinmaster[this.arraysave][this.mastername].remote[remote.keycode]=remote;
							////trace(".. added remote for keycode "+remote.keycode);
						}
					}
					break;
				default:
					////trace("...  UNKNOWN BLOCK!!");
			}
		}

		trace("finished with file");
		this.eskin_loadfile();
	}

	private function process_block_if(xml:XML,fortile:Boolean) {
		//trace(".. processing if");

		var saveData:Array=new Array();
		saveData.code=new Array();
		saveData.action="if";

		// condition
		saveData.condition=XPathAPI.selectSingleNode(xml, "/if/condition").firstChild.nodeValue.toString();
		trace("condition: "+saveData.condition);

		saveData.swap=fix_truefalse(XPathAPI.selectSingleNode(xml, "/if/swap").firstChild.nodeValue.toString(),false);
		trace("swap: "+saveData.swap);

		// hyper
		saveData.hyper=int(XPathAPI.selectSingleNode(xml, "/if/hyper").firstChild.nodeValue.toString());
		if(saveData.hyper<1 || saveData.hyper>4) saveData.hyper=undefined;
		trace("hyper: "+saveData.hyper);

		saveData.segname=XPathAPI.selectSingleNode(xml, "/if/segname").firstChild.nodeValue.toString();
		trace("segname: "+saveData.segname);

		// loop the rest
		var myXML = xml.childNodes;

		for (var i=0; i<myXML.length; i++) {
			var block=myXML[i].nodeName.toString();

			//trace("... blockname "+block);
			switch(block) {
				case 'text':
					var save=process_block_text(myXML[i],fortile);
					if(save!=null) {
						saveData.code.push(save);
					}
					break;
				case 'image':
					var save=process_block_image(myXML[i],fortile);
					if(save!=null) {
						saveData.code.push(save);
					}
					break;
			/*	case 'include':
					if(this.equeue==null) this.equeue=new Array();
					var dataValue=myXML[i].firstChild.nodeValue.toString();
					this.equeue.push(dataValue);
					saveData.code.push({action:"include",name:dataValue});
					////trace("... added "+dataValue+" to eskin load queue");
					break;
				case 'shared':
					if(this.squeue==null) this.squeue=new Array();
					var dataValue=myXML[i].firstChild.nodeValue.toString();
					this.squeue.push(dataValue);
					saveData.code.push({action:"shared",name:dataValue});
					////trace("... added "+dataValue+" to shared load queue");
					break;						*/
				default:
					//trace(".... not a subblock");
			}
		}

		if(saveData.condition != undefined && saveData.condition != null && saveData.code.length > 0) return(saveData);
		return(null);
	}

	private function process_segment(xml:XML) {
		//trace(".. processing segment");

		// extract important stuff

		// name
		var name:String=XPathAPI.selectSingleNode(xml, "/segment/name").firstChild.nodeValue.toString();
		name=check_missingname(name);
		trace("name: "+name);

		// condition
		var condition:String=XPathAPI.selectSingleNode(xml, "/segment/condition").firstChild.nodeValue.toString();
		trace("condition: "+condition);

		// control
		var control:String=XPathAPI.selectSingleNode(xml, "/segment/control").firstChild.nodeValue.toString();
		trace("control: "+control);

		// hyperscroll
		var hyperscroll:Boolean=fix_truefalse(XPathAPI.selectSingleNode(xml, "/segment/hyperscroll").firstChild.nodeValue.toString(),true);
		trace("hyperscroll: "+hyperscroll);


		// datasource
		var datasource:String=XPathAPI.selectSingleNode(xml, "/segment/datasource").firstChild.nodeValue.toString();
		trace("datasource: "+datasource);

		// x,y
		var startx:Number=Number(XPathAPI.selectSingleNode(xml, "/segment/startx").firstChild.nodeValue.toString())*Common.evSettings.overscanx+Common.evSettings.overscanxshift;
		var starty:Number=Number(XPathAPI.selectSingleNode(xml, "/segment/starty").firstChild.nodeValue.toString())*Common.evSettings.overscany+Common.evSettings.overscanyshift;
		trace("start: "+startx+"x"+starty);

		var tilesize:String=XPathAPI.selectSingleNode(xml, "/segment/tilesize").firstChild.nodeValue.toString();
		tilesize=fix_truefalse(tilesize,true);

		// scroll
		var scroll:Number=int(XPathAPI.selectSingleNode(xml, "/segment/scroll").firstChild.nodeValue.toString());

		// ex,y
		var endx:Number=Number(XPathAPI.selectSingleNode(xml, "/segment/endx").firstChild.nodeValue.toString())*Common.evSettings.overscanx+Common.evSettings.overscanxshift;
		var endy:Number=Number(XPathAPI.selectSingleNode(xml, "/segment/endy").firstChild.nodeValue.toString())*Common.evSettings.overscany+Common.evSettings.overscanyshift;
		//trace("end: "+endx+"x"+endy);

		this.segment=new Array();
		this.segment.tile=new Array();
		this.segment.cursor=new Object();
		this.segment.remote=new Array();

		this.segment.name=name;
		this.segment.settings={name:name,tilesize:tilesize,condition:condition,hyperscroll:hyperscroll,control:control,startx:startx,starty:starty,endx:endx,endy:endy,scroll:scroll,datasource:datasource};
		// mctracking entry
		Common.eskinmaster[this.arraysave][this.arrayname].code.push({name:"SEG"+name,action:"setdepth"});

		// loop the rest
		var myXML = xml.childNodes;

		for (var i=0; i<myXML.length; i++) {
			var block=myXML[i].nodeName.toString();

			//trace("... blockname "+block);
			switch(block) {
				case 'tile':
					var tile:Object=this.process_block_tile(myXML[i]);
					this.segment.tile.push(tile);
					break;
				case 'fanart':
					var fanart:Object=this.process_block_segfanart(myXML[i]);
					if(fanart!=null) {
						this.segment.settings.fanart=fanart;
						trace("added fanart to segment");
					}
					break;
				case 'remote':
					var remote:Object=this.process_remote(myXML[i]);
					if(remote!=null) {
						if(remote.all!=null) {
							this.segment.settings.remoteall=remote;
							//trace(".. added all key");
						} else if(remote.keypad!=null) {
							this.segment.settings.remotekeypad=remote;
							//trace(".. added keypad");
						} else {
							this.segment.remote[remote.keycode]=this.add_to_array(this.segment.remote[remote.keycode],remote);
							//trace(".. added remote for keycode "+remote.keycode);
						}
					}
					break;
				case 'exit':
					break;
				case 'cursor':
					this.segment.cursor=this.process_block_cursor(myXML[i]);
					break;
				default:
					//trace(".... not a subblock");
			}
		}

		// wrap it up.
		Common.eskinmaster[this.arraysave][this.arrayname].segments.push(this.segment);
		delete this.segment;
		this.segment=null;

		trace("finished with segment");
	}

	private function add_to_array(original, newelement) {
		// not defined yet
		if(original == undefined || original == null) {
			trace(".. new remote key");
			return(Array(newelement));
		} else {
			trace(".. multiple remote key");
			return(original.concat(newelement));
		}
	}

	private function process_remote(xml:XML) {
		trace("processing remote block");

		var button:String=XPathAPI.selectSingleNode(xml, "/remote/button").firstChild.nodeValue.toString().toUpperCase();
		trace(". button: "+button);

		var remoteall:Boolean=null;
		var keypad:Boolean=null;
		switch(button) {
			case "ALL":
				remoteall=true;
				break;
			case 'KEYPAD':
			case 'NUMPAD':
				keypad=true;
				break;
			default:
				if(RemoteControl.remotemapname[button]==undefined) {
					trace(".. invalid button "+button);
					return(null);
				}
				var keycode=RemoteControl.remotemapname[button];
		}

		var action:String=XPathAPI.selectSingleNode(xml, "/remote/action").firstChild.nodeValue.toString().toUpperCase();
		if(action==undefined || action==null) {
			//trace(".. invalid action: "+action);
			return(null);
		}

		trace(".. action: "+action);

		var file:String=XPathAPI.selectSingleNode(xml, "/remote/file").firstChild.nodeValue.toString();
		var control:String=XPathAPI.selectSingleNode(xml, "/remote/control").firstChild.nodeValue.toString();
		var data:String=XPathAPI.selectSingleNode(xml, "/remote/data").firstChild.nodeValue.toString();
		var target:String=XPathAPI.selectSingleNode(xml, "/remote/target").firstChild.nodeValue.toString();
		var condition:String=XPathAPI.selectSingleNode(xml, "/remote/condition").firstChild.nodeValue.toString();
		trace(".. file: "+file);
		trace(".. control: "+control);
		trace(".. condition: "+condition);
		trace(".. data: "+data);

		return({keycode:keycode, condition:condition, file:file, action:action, target:target, data:data, control:control, all:remoteall, keypad:keypad});
	}

	private function process_block_segfanart(xml:XML) {
		//trace("... processing segfanart block");

		var bg:String=XPathAPI.selectSingleNode(xml, "/fanart/file").firstChild.nodeValue.toString();
		//trace(".... bg: "+bg);
		if(bg==null || bg==undefined) return(null);

		var hyper:Number=int(XPathAPI.selectSingleNode(xml, "/fanart/hyper").firstChild.nodeValue.toString());
		if(hyper<1 || hyper>4 || hyper==null || hyper==undefined) hyper=1;
		//trace(".... hyper: "+hyper);

		// condition
		var condition:String=XPathAPI.selectSingleNode(xml, "/fanart/condition").firstChild.nodeValue.toString();
		trace("condition: "+condition);

		return({file:bg,hyper:hyper,condition:condition});
	}

	private function process_block_tile(xml:XML) {
		//trace("... processing tile block");

		var tilecode:Array=new Array;

		var cols:Number=int(XPathAPI.selectSingleNode(xml, "/tile/cols").firstChild.nodeValue.toString());
		var rows:Number=int(XPathAPI.selectSingleNode(xml, "/tile/rows").firstChild.nodeValue.toString());
		if(cols<0) cols=1;
		if(rows<0) rows=1;

		var offset:Number=int(XPathAPI.selectSingleNode(xml, "/tile/offset").firstChild.nodeValue.toString());
		if(offset<0 || offset==null || offset==undefined) {
			offset=0;
		}
		var first:Number=int(XPathAPI.selectSingleNode(xml, "/tile/first").firstChild.nodeValue.toString());
		if(first<1 || first==null || first==undefined) {
			first=0;
		} else first--;

		var stat:Boolean=fix_truefalse(XPathAPI.selectSingleNode(xml, "/tile/static").firstChild.nodeValue.toString(),false);

		var width:Number=Number(XPathAPI.selectSingleNode(xml, "/tile/width").firstChild.nodeValue.toString())*Common.evSettings.overscanx;
		var height:Number=Number(XPathAPI.selectSingleNode(xml, "/tile/height").firstChild.nodeValue.toString())*Common.evSettings.overscany;

		//trace(". cols: "+cols);
		//trace(". rows: "+rows);
		//trace(". width: "+width);
		//trace(". height: "+height);

		// condition
		var condition:String=XPathAPI.selectSingleNode(xml, "/tile/condition").firstChild.nodeValue.toString();
		trace("condition: "+condition);

		// loop the rest
		var myXML = xml.childNodes;

		for (var i=0; i<myXML.length; i++) {
			var block=myXML[i].nodeName.toString();

			//trace("... blockname "+block);
			switch(block) {
				case 'text':
					var save=process_block_text(myXML[i],true);
					if(save!=null) {
						tilecode.push(save);
					}
					break;
				case 'image':
					var save=process_block_image(myXML[i],true);
					if(save!=null) {
						tilecode.push(save);
					}
					break;
				case 'if':
					var save=process_block_if(myXML[i],true);
					if(save!=null) {
						tilecode.push(save);
					}
					break;
				default:
					//trace(".... not a tile subblock");
			}
		}

		return({cols:cols,first:first, rows:rows,offset:offset,stat:stat,width:width,height:height,condition:condition,code:tilecode});
	}

	private function process_block_text(xml:XML, fortile:Boolean) {
		//trace("... processing text block");

		var saveData:Object=new Object;

		// loop through the xml
		var myXML = xml.childNodes;

		for (var i=0; i<myXML.length; i++) {
			var dataName=myXML[i].nodeName.toString();
			var dataValue=myXML[i].firstChild.nodeValue.toString();
			//trace(dataName+" value "+dataValue);
			saveData[dataName]=dataValue;
		}

		// adjust defaults and ints
		saveData.name=check_missingname(saveData.name);
		if(saveData.hyper<1 || saveData.hyper>4) saveData.hyper=undefined;

		saveData.highlight=fix_truefalse(saveData.highlight,undefined);

		saveData.posx=Number(saveData.posx)*Common.evSettings.overscanx;
		saveData.posy=Number(saveData.posy)*Common.evSettings.overscany;
		saveData.width=Number(saveData.width)*Common.evSettings.overscanx;
		saveData.height=Number(saveData.height)*Common.evSettings.overscany;

		if(fortile != true) {
			saveData.posx=saveData.posx+Common.evSettings.overscanxshift;
			saveData.posy=saveData.posy+Common.evSettings.overscanyshift;
		}

		if(saveData.leading==undefined) {
		   saveData.leading=0;
		} else saveData.leading=Number(saveData.leading);
		saveData.leading=saveData.leading*Common.evSettings.overscanx;

		if(saveData.size==undefined) {
			saveData.size=20;
		} else saveData.size=Number(saveData.size);
		saveData.size=saveData.size*Common.evSettings.overscany;

		if(saveData.color==undefined) saveData.color="FFFFFF";
		if(saveData.hlcolor==undefined) saveData.hlcolor="FF0000";
		if(saveData.color.length!=6) saveData.color=Common.esSettings[saveData.color];
		if(saveData.hlcolor.length!=6) saveData.hlcolor=Common.esSettings[saveData.hlcolor];
		saveData.color=parseInt(saveData.color, 16);
		saveData.hlcolor=parseInt(saveData.hlcolor, 16);

		saveData.html=fix_truefalse(saveData.html,false);
		saveData.wordwrap=fix_truefalse(saveData.wordwrap,false);
		saveData.underline=fix_truefalse(saveData.underline,false);
		saveData.bold=fix_truefalse(saveData.bold,false);
		saveData.italic=fix_truefalse(saveData.italic,false);

		saveData.align=saveData.align.toLowerCase();
		if(saveData.align != "left" && saveData.align != "center" && saveData.align != "right") {
			saveData.align="left";
		}

		if(saveData.display==undefined) saveData.display=" ";

		// finish up
		//trace(".. name: "+saveData.name);
		//trace(".. display: "+saveData.display);
		//trace(".. posx: "+saveData.posx);
		//trace(".. posy: "+saveData.posy);
		//trace(".. width: "+saveData.width);
		//trace(".. height: "+saveData.height);
		//trace(".. html: "+saveData.html);
		//trace(".. wordwrap: "+saveData.wordwrap);
		//trace(".. font: "+saveData.font);
		//trace(".. align: "+saveData.align);
		//trace(".. size: "+saveData.size);
		//trace(".. color: "+saveData.color);
		//trace(".. hlcolor: "+saveData.hlcolor);
		//trace(".. underline: "+saveData.underline);
		//trace(".. bold: "+saveData.bold);
		//trace(".. italic: "+saveData.italic);
		//trace(".. leading: "+saveData.leading);
		//trace(".. hyper: "+saveData.hyper);
		//trace(".. condition: "+saveData.condition);

		saveData.action="text";
		return(saveData);
		delete saveData;
	}

	private function fix_truefalse(orig:String, norm:Boolean) {
		var check:String=orig.toLowerCase();
		if(check=="false" || check=="0" || check=="off") {
			return(false);
		} else if(check=="true" || check=="1" || check=="on") {
			return(true);
		} else return(norm);
	}

	private function process_block_cursor(xml:XML) {
		//trace("... processing cursor");

		// file
		var filename:String=XPathAPI.selectSingleNode(xml, "/cursor/file").firstChild.nodeValue.toString();

		// x,y
		var posx:Number=Number(XPathAPI.selectSingleNode(xml, "/cursor/posx").firstChild.nodeValue.toString())*Common.evSettings.overscanx;
		var posy:Number=Number(XPathAPI.selectSingleNode(xml, "/cursor/posy").firstChild.nodeValue.toString())*Common.evSettings.overscany;

		// wxh
		var width:Number=Number(XPathAPI.selectSingleNode(xml, "/cursor/width").firstChild.nodeValue.toString())*Common.evSettings.overscanx;
		var height:Number=Number(XPathAPI.selectSingleNode(xml, "/cursor/height").firstChild.nodeValue.toString())*Common.evSettings.overscany;

		// above
		var above:String=XPathAPI.selectSingleNode(xml, "/cursor/above").firstChild.nodeValue.toString();
		above=fix_truefalse(above,false);

		var animate:String=XPathAPI.selectSingleNode(xml, "/cursor/animate").firstChild.nodeValue.toString();
		animate=fix_truefalse(animate,true);

		//trace(".. file: "+filename);
		//trace(".. above: "+above);
		//trace(".. posx: "+posx);
		//trace(".. posy: "+posy);
		//trace(".. width: "+width);
		//trace(".. height: "+height);

		return({above:above,animate:animate,file:filename,posx:posx,posy:posy,width:width,height:height});
	}

	private function process_block_image(xml:XML,fortile:Boolean) {
		//trace("... processing image block");

		// name
		var name:String=XPathAPI.selectSingleNode(xml, "/image/name").firstChild.nodeValue.toString();
		name=check_missingname(name);

		var segname:String=XPathAPI.selectSingleNode(xml, "/image/segname").firstChild.nodeValue.toString();
		var highlight:String=XPathAPI.selectSingleNode(xml, "/image/highlight").firstChild.nodeValue.toString();
		highlight=fix_truefalse(highlight,undefined);

		var swap=XPathAPI.selectSingleNode(xml, "/image/swap").firstChild.nodeValue.toString();
		swap=fix_truefalse(swap,false);

		var keepaspect=XPathAPI.selectSingleNode(xml, "/image/keepaspect").firstChild.nodeValue.toString();
		keepaspect=fix_truefalse(keepaspect,false);

		// file
		var filename:String=XPathAPI.selectSingleNode(xml, "/image/file").firstChild.nodeValue.toString();

		// alt
		var altfilename:String=XPathAPI.selectSingleNode(xml, "/image/altfile").firstChild.nodeValue.toString();

		// x,y
		var posx:Number=Number(XPathAPI.selectSingleNode(xml, "/image/posx").firstChild.nodeValue.toString())*Common.evSettings.overscanx;
		var posy:Number=Number(XPathAPI.selectSingleNode(xml, "/image/posy").firstChild.nodeValue.toString())*Common.evSettings.overscany;

		if(fortile != true) {
			posx=posx+Common.evSettings.overscanxshift;
			posy=posy+Common.evSettings.overscanyshift;
		}

		// wxh
		var width:Number=Number(XPathAPI.selectSingleNode(xml, "/image/width").firstChild.nodeValue.toString())*Common.evSettings.overscanx;
		var height:Number=Number(XPathAPI.selectSingleNode(xml, "/image/height").firstChild.nodeValue.toString())*Common.evSettings.overscany;

		// hyper
		var hyper:Number=int(XPathAPI.selectSingleNode(xml, "/image/hyper").firstChild.nodeValue.toString());
		if(hyper<1 || hyper>4) hyper=undefined;

		// condition
		var condition:String=XPathAPI.selectSingleNode(xml, "/image/condition").firstChild.nodeValue.toString();

		var valigned:String=XPathAPI.selectSingleNode(xml, "/image/valigned").firstChild.nodeValue.toString();
		var haligned:String=XPathAPI.selectSingleNode(xml, "/image/haligned").firstChild.nodeValue.toString();

		//trace(".. name: "+name);
		//trace(".. file: "+filename);
		//trace(".. posx: "+posx);
		//trace(".. posy: "+posy);
		//trace(".. width: "+width);
		//trace(".. height: "+height);
		//trace(".. hyper: "+hyper);
		//trace(".. condition: "+condition);
		//trace(".. keepaspect: "+keepaspect);

		return({action:"image",name:name,swap:swap, keepaspect:keepaspect,valigned:valigned,haligned:haligned, condition:condition, file:filename,altfile:altfilename,posx:posx,posy:posy,width:width,height:height,segname:segname,highlight:highlight,hyper:hyper});
	}

	private function process_block_background(xml:XML) {
		//trace("... processing background block");
		// extract filename
		var temp:String=XPathAPI.selectSingleNode(xml, "/background/file").firstChild.nodeValue.toString();
		if(temp!=undefined) {
			Common.eskinmaster[this.arraysave][this.arrayname].control.background=temp;
			var highres:String=XPathAPI.selectSingleNode(xml, "/background/highres").firstChild.nodeValue.toString();
			Common.eskinmaster[this.arraysave][this.arrayname].control.backgroundhighres=fix_truefalse(highres,false);
		}
	}

	private function process_block_control(xml:XML) {
		//trace("... processing control block");

		var temp:String=XPathAPI.selectSingleNode(xml, "/control/fullscreen").firstChild.nodeValue.toString().toLowerCase();
		Common.eskinmaster[this.arraysave][this.arrayname].control.fullscreen=fix_truefalse(temp,true);
		//trace(".. fullscreen: "+Common.eskinmaster[this.arraysave][this.arrayname].control.fullscreen);

		var temp:String=XPathAPI.selectSingleNode(xml, "/control/clearhighresbg").firstChild.nodeValue.toString().toLowerCase();
		Common.eskinmaster[this.arraysave][this.arrayname].control.clearhighresbg=fix_truefalse(temp,true);

		var temp:String=XPathAPI.selectSingleNode(xml, "/control/passthrough").firstChild.nodeValue.toString();
		if(temp!=undefined && temp!=null) {
			Common.eskinmaster[this.arraysave][this.arrayname].control.passthrough=temp;
		}
		//trace(".. passthrough: "+Common.eskinmaster[this.arraysave][this.arrayname].control.passthrough);
	}

	private function process_block_info(xml:XML) {
		//trace("... processing info block");

		if(Common.eskinmaster[this.arraysave].settings.info==undefined) Common.eskinmaster[this.arraysave].settings.info=new Array();

		Common.eskinmaster[this.arraysave].settings.info.name=XPathAPI.selectSingleNode(xml, "/info/name").firstChild.nodeValue.toString();
		Common.eskinmaster[this.arraysave].settings.info.version=XPathAPI.selectSingleNode(xml, "/info/version").firstChild.nodeValue.toString();
		Common.eskinmaster[this.arraysave].settings.info.homepage=XPathAPI.selectSingleNode(xml, "/info/homepage").firstChild.nodeValue.toString();
		Common.eskinmaster[this.arraysave].settings.info.lang=XPathAPI.selectSingleNode(xml, "/info/language").firstChild.nodeValue.toString();

		if(Common.eskinmaster[this.arraysave].settings.info.lang==undefined) Common.eskinmaster[this.arraysave].settings.info.lang="en.xml";
		if(Common.eskinmaster[this.arraysave].settings.info.name==undefined) Common.eskinmaster[this.arraysave].settings.info.name=Common.evSettings.eskin;
		if(Common.eskinmaster[this.arraysave].settings.info.homepage==undefined) Common.eskinmaster[this.arraysave].settings.info.homepage="unknown";
		if(Common.eskinmaster[this.arraysave].settings.info.version==undefined) Common.eskinmaster[this.arraysave].settings.info.version="unknown";

		//trace(".... name: "+Common.eskinmaster[this.arraysave].settings.info.name);
		//trace(".... version: "+Common.eskinmaster[this.arraysave].settings.info.version);
		//trace(".... homepage: "+Common.eskinmaster[this.arraysave].settings.info.homepage);
		//trace(".... lang: "+Common.eskinmaster[this.arraysave].settings.info.lang);
	}

	private function process_block_settings(xml:XML) {
		//trace("... processing settings block");

		// pages
		this.process_block_settings_sub(xml,"home");
		this.process_block_settings_sub(xml,"menu");
		this.process_block_settings_sub(xml,"index");
		this.process_block_settings_sub(xml,"tv");
		this.process_block_settings_sub(xml,"movie");
		this.process_block_settings_sub(xml,"error");
		this.process_block_settings_sub(xml,"info");
		this.process_block_settings_sub(xml,"multiinfo");
		this.process_block_settings_sub(xml,"mpart");

		// settings
		Common.eskinmaster[this.arraysave].settings.starttype=XPathAPI.selectSingleNode(xml, "/settings/starttype").firstChild.nodeValue.toString().toLowerCase();
		if(Common.eskinmaster[this.arraysave].settings.starttype==null || Common.eskinmaster[this.arraysave].settings.starttype==undefined) Common.eskinmaster[this.arraysave].settings.starttype="home";
		trace("starttype: "+Common.eskinmaster[this.arraysave].settings.starttype);

	}

	private function process_block_settings_sub(xml:XML, who:String) {
		//trace(".... looking for "+who);

		var where=XPathAPI.selectSingleNode(xml, "/settings/"+who).firstChild.nodeValue.toString();
		if(where!=undefined) {
			if(Common.eskinmaster[this.arraysave].settings.screensvalid==undefined) Common.eskinmaster[this.arraysave].settings.screensvalid=new Array();
			if(Common.eskinmaster[this.arraysave].settings.screensvalid[who]==undefined) Common.eskinmaster[this.arraysave].settings.screensvalid[who]=new Array();
			if(Common.eskinmaster[this.arraysave].settings.screens==undefined) Common.eskinmaster[this.arraysave].settings.screens=new Array();

			//trace(".... found: "+where);
			var spl:Array=new Array();
			spl=where.split(",");
			//trace("..... "+spl.length+" items");
			for(var i=0;i<spl.length;i++) {
				spl[i]=StringUtil.trim(spl[i]);
				//this.equeue.push(spl[i]);
				Common.eskinmaster[this.arraysave].settings.screensvalid[who].push(spl[i]);
				//trace("..... "+spl[i]+" added to load queue");
			}

			// look for default
			var def=XPathAPI.selectSingleNode(xml, "/settings/"+who).attributes["default"].toString();
			if(def==undefined) {
				//trace("..... default not found, using first "+spl[0]);
				def=spl[0];
			} else {
				//trace("..... default "+def);
			}
			Common.eskinmaster[this.arraysave].settings.screens[who]=def;
		} //else trace(".... not found");
	}

	private function check_missingname(name:String):String {

		if(name==undefined || name==null) {
			this.missingname++;
			//trace("assigning name: MISSING"+this.missingname);

			return("MISSING"+this.missingname);
		}

		return(name);
	}
}