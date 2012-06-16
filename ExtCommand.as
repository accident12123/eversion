intrinsic dynamic class ExtCommand
{
    public static function exitFlash():Void;

    public static function requestWebBrowserOnExit(url:String):Boolean;
    public static function requestWebBrowserOnExitWithReturn(url:String):Boolean;
    public static function cancelWebBrowserOnExit():Void;

    public static function requestFilePlayerOnExit(url:String):Boolean;
    public static function requestFilePlayerOnExitWithReturn(url:String):Boolean;
    public static function cancelFilePlayerOnExit():Void;

    public static function requestPlaylistPlaybackOnExit(url:String):Boolean;
    public static function requestPlaylistPlaybackOnExitWithReturn(url:String):Boolean;
    public static function cancelPlaylistPlaybackOnExit():Void;

    public static function requestDVDPlayerOnExit(url:String):Boolean;
    public static function requestDVDPlayerOnExitWithReturn(url:String):Boolean;
    public static function cancelDVDPlayerOnExit():Void;

    public static function requestBlurayPlayerOnExit(url:String):Boolean;
    public static function requestBlurayPlayerOnExitWithReturn(url:String):Boolean;
    public static function cancelBlurayPlayerOnExit():Void;

    public static function getMainStoragePath():String;
    public static function getSerialNumber():String;
    public static function getProductId():String;
    public static function getFirmwareVersion():String;

    public static function sync():Void;
}
