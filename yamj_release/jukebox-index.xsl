<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="/">
<html>
   <head>
      <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></meta><script type="text/javascript">


function is200series ()
{
    if (navigator.userAgent.search(/4(0[89]|1[015])/)>0) 
    {return true;}
    else {return false;}
}
function checkinHD ()
{
    if (navigator.userAgent.search(/TV Res(1280|1920)/)>0) 
    {return true;}
    else {return false;}
}

function showerrormessage(errormessage) {
alert(errormessage); 
history.go(-1);
}

function redirect()
{
if (is200series()==true)
   {
   if (checkinHD()==true)
      {
var jukeboxname = '<xsl:value-of select="index/detailsDirName" />';
        var currentpath = location.href;
        var url = window.location.pathname;
        var filename = url.substring(url.lastIndexOf('/')+1);
        var targeturl=currentpath;
        var parts=targeturl.split('/');
        var exitpath = currentpath;
        parts[parts.length-1]=jukeboxname + '/eversion.phf';
        targeturl=parts.join('/');
        exitpath=exitpath.replace("file:///opt/sybhttpd/localhost.drives",'http://localhost.drives:8883');
        exitpath=exitpath.replace('/[0-9a-zA-Z]*.htm$','/?page=1');
       {location.replace(targeturl);
        location.replace(exitpath)}
      }
	  else{showerrormessage('Eversion can only be run on a High Definition TV');}
   }
   else {showerrormessage('Eversion can only be run on a Popcornhour 200 series or AsiaBox');} 
   
}
</script></head>
   <body bgcolor="transparent" onload="redirect();"></body>
</html> 
</xsl:template>
</xsl:stylesheet>
